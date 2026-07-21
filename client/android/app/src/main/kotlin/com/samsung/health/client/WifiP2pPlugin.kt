package com.samsung.health.client

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.Locale

class WifiP2pPlugin(private val context: Context) {

    companion object {
        private const val TAG = "HP_WifiPlugin"
        private const val METHOD_CHANNEL_NAME = "com.samsung.health.client/wifi_p2p"
        private const val EVENT_CHANNEL_NAME = "com.samsung.health.client/wifi_p2p_events"
        private const val TCP_PORT = 8888
        private const val UDP_BEACON_PORT = 8889
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val uiHandler = Handler(Looper.getMainLooper())

    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var socketWriter: BufferedWriter? = null
    private var socketReader: BufferedReader? = null
    private var isServerRunning = false
    private var udpBeaconThread: Thread? = null

    fun register(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startServer" -> {
                        startServer()
                        result.success(true)
                    }
                    "stopServer" -> {
                        stopServer()
                        result.success(true)
                    }
                    "requestFileList" -> {
                        sendSocketLine("GET_FILE_LIST")
                        result.success(true)
                    }
                    "requestFileDownload" -> {
                        val filename = call.argument<String>("filename")
                        if (filename != null) {
                            sendSocketLine("DOWNLOAD_FILE:$filename")
                            result.success(true)
                        } else {
                            result.error("BAD_ARGS", "Filename is required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        eventChannel = EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    Log.d(TAG, "Event channel listener registered.")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "Event channel listener cancelled.")
                }
            })
        }
    }

    private fun sendEvent(type: String, data: Any?) {
        uiHandler.post {
            val eventMap = mutableMapOf<String, Any?>()
            eventMap["type"] = type
            eventMap["data"] = data
            eventSink?.success(eventMap)
        }
    }

    private fun startServer() {
        if (isServerRunning) return
        isServerRunning = true

        val localIp = getLocalIpAddress()
        Log.d(TAG, "Starting Standard Wi-Fi Server at $localIp:$TCP_PORT...")

        // 1. Start TCP ServerSocket
        Thread {
            try {
                serverSocket = ServerSocket(TCP_PORT)
                Log.d(TAG, "TCP Server listening on port $TCP_PORT...")
                while (isServerRunning) {
                    val socket = serverSocket?.accept() ?: break
                    Log.d(TAG, "Watch connected to TCP server from ${socket.inetAddress.hostAddress}")
                    clientSocket = socket
                    
                    socketWriter = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                    socketReader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))

                    // Start socket reading thread
                    readSocketStream(socket)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Server socket exception: ${e.message}")
            }
        }.start()

        // 2. Start UDP Beacon broadcasting so the Watch can discover our IP
        startUdpBeacon(localIp)
    }

    private fun startUdpBeacon(ip: String) {
        udpBeaconThread = Thread {
            try {
                val socket = DatagramSocket()
                socket.broadcast = true
                val beaconMessage = "HEALTHPORT_SERVER:$ip:$TCP_PORT"
                val bytes = beaconMessage.toByteArray(Charsets.UTF_8)
                val broadcastAddr = InetAddress.getByName("255.255.255.255")

                Log.d(TAG, "Broadcasting UDP Beacon: $beaconMessage")
                while (isServerRunning) {
                    try {
                        val packet = DatagramPacket(bytes, bytes.size, broadcastAddr, UDP_BEACON_PORT)
                        socket.send(packet)
                    } catch (e: Exception) {
                        Log.e(TAG, "UDP broadcast send error: ${e.message}")
                    }
                    Thread.sleep(1000)
                }
                socket.close()
            } catch (e: Exception) {
                Log.e(TAG, "UDP Beacon thread error: ${e.message}")
            }
        }.apply { start() }
    }

    private fun stopServer() {
        isServerRunning = false
        closeClientSocket()
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            // ignore
        }
        serverSocket = null
        udpBeaconThread = null
        sendEvent("connectionStateChanged", mapOf("connected" to false))
    }

    private fun closeClientSocket() {
        try {
            socketWriter?.close()
            socketReader?.close()
            clientSocket?.close()
        } catch (e: Exception) {
            // ignore
        }
        socketWriter = null
        socketReader = null
        clientSocket = null
    }

    private fun sendSocketLine(text: String) {
        Thread {
            try {
                socketWriter?.write(text + "\n")
                socketWriter?.flush()
                Log.d(TAG, "Sent socket command: $text")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send socket line: ${e.message}")
            }
        }.start()
    }

    private fun readSocketStream(socket: Socket) {
        Thread {
            try {
                val inStream = socket.getInputStream()
                val reader = socketReader ?: BufferedReader(InputStreamReader(inStream, Charsets.UTF_8))

                while (isServerRunning) {
                    val line = reader.readLine() ?: break
                    Log.d(TAG, "Socket command read: $line")

                    when {
                        line == "HELLO_FROM_WATCH" -> {
                            Log.d(TAG, "Handshake complete with Watch.")
                            val deviceIp = socket.inetAddress.hostAddress ?: "Watch"
                            sendEvent("connectionStateChanged", mapOf("connected" to true, "deviceName" to deviceIp))
                        }
                        line.startsWith("FILE_LIST:") -> {
                            val json = line.substring("FILE_LIST:".length)
                            sendEvent("fileListReceived", json)
                        }
                        line.startsWith("FILE_START:") -> {
                            // Format: FILE_START:[filename]:[size]:[md5]
                            val parts = line.split(":")
                            if (parts.size >= 4) {
                                val filename = parts[1]
                                val size = parts[2].toLong()
                                val expectedMd5 = parts[3]
                                Log.d(TAG, "Starting download: $filename (Size: $size bytes)")
                                receiveFilePayload(inStream, filename, size, expectedMd5)
                            }
                        }
                        line.startsWith("ERROR:") -> {
                            val errMsg = line.substring("ERROR:".length)
                            sendEvent("downloadFailure", mapOf("error" to errMsg))
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exception reading socket: ${e.message}")
            } finally {
                closeClientSocket()
            }
        }.start()
    }

    private fun receiveFilePayload(inStream: InputStream, filename: String, totalBytes: Long, expectedMd5: String) {
        val destFolder = File(context.cacheDir, "sh_sync").apply { mkdirs() }
        val tempFile = File(destFolder, filename)
        
        try {
            val fileOut = FileOutputStream(tempFile)
            val buffer = ByteArray(16384)
            var bytesRead: Int
            var totalRead: Long = 0

            Log.d(TAG, "Reading raw file bytes for $filename...")
            while (totalRead < totalBytes) {
                val toRead = Math.min(buffer.size.toLong(), totalBytes - totalRead).toInt()
                bytesRead = inStream.read(buffer, 0, toRead)
                if (bytesRead == -1) {
                    throw EOFException("Socket closed prematurely during file stream.")
                }
                fileOut.write(buffer, 0, bytesRead)
                totalRead += bytesRead

                val progress = if (totalBytes > 0) totalRead.toDouble() / totalBytes else 0.0
                sendEvent("downloadProgress", mapOf(
                    "filename" to filename,
                    "progress" to progress,
                    "transferred" to totalRead,
                    "total" to totalBytes
                ))
            }
            fileOut.flush()
            fileOut.close()

            val calculatedMd5 = calculateMd5(tempFile)
            Log.d(TAG, "Download finished. MD5 Expected: $expectedMd5, Calculated: $calculatedMd5")
            if (expectedMd5.lowercase() == calculatedMd5.lowercase()) {
                sendEvent("downloadComplete", mapOf(
                    "filename" to filename,
                    "path" to tempFile.absolutePath
                ))
            } else {
                sendEvent("downloadFailure", mapOf(
                    "filename" to filename,
                    "error" to "MD5 verification failed"
                ))
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error receiving file over socket: ${e.message}")
            sendEvent("downloadFailure", mapOf(
                "filename" to filename,
                "error" to (e.message ?: "Unknown socket error")
            ))
        }
    }

    private fun calculateMd5(file: File): String {
        val digest = MessageDigest.getInstance("MD5")
        val fis = FileInputStream(file)
        val buffer = ByteArray(8192)
        var read: Int
        while (fis.read(buffer).also { read = it } > 0) {
            digest.update(buffer, 0, read)
        }
        fis.close()
        val md5sum = digest.digest()
        val bigInt = java.math.BigInteger(1, md5sum)
        var output = bigInt.toString(16)
        while (output.length < 32) {
            output = "0$output"
        }
        return output
    }

    private fun getLocalIpAddress(): String {
        try {
            val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val ip = wm.connectionInfo.ipAddress
            if (ip != 0) {
                return String.format(
                    Locale.getDefault(), "%d.%d.%d.%d",
                    ip and 0xff,
                    ip shr 8 and 0xff,
                    ip shr 16 and 0xff,
                    ip shr 24 and 0xff
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get local Wi-Fi IP: ${e.message}")
        }
        return "127.0.0.1"
    }
}
