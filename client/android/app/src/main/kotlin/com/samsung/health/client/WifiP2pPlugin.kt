package com.samsung.health.client

import android.annotation.SuppressLint
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.math.BigInteger
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.Locale
import java.net.InetSocketAddress

class WifiP2pPlugin(private val context: Context) {

    companion object {
        private const val TAG = "HP_WifiPlugin"
        private const val METHOD_CHANNEL = "com.samsung.health.client/wifi_p2p"
        private const val EVENT_CHANNEL  = "com.samsung.health.client/wifi_p2p_events"
        private const val TCP_PORT       = 34567
        private const val UDP_PORT       = 34567

        const val FIXED_SSID = "healthport"
        const val PRIMARY_PASS = "00000000"

        // 1MB Buffer for high speed TCP transfer
        private const val BUFFER_SIZE = 1024 * 1024 
    }

    private val uiHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    // LocalOnlyHotspot
    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null

    // TCP
    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var socketWriter: BufferedWriter? = null
    private var isServerRunning = false

    // UDP beacon
    private var udpBeaconThread: Thread? = null

    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // REGISTRATION
    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer"         -> {
                    val mode = call.argument<String>("mode") ?: "AP"
                    startServer(mode)
                    result.success(true)
                }
                "stopServer"          -> { stopServer();  result.success(true) }
                "updateNotification"  -> { 
                    val message = call.argument<String>("message") ?: ""
                    val progress = call.argument<Int>("progress") ?: -1
                    val isComplete = call.argument<Boolean>("isComplete") ?: false
                    val isResumed = call.argument<Boolean>("isResumed") ?: false
                    updateNotification(message, progress, isComplete, isResumed)
                    result.success(true) 
                }
                "requestFileList"     -> { sendSocketLine("GET_FILE_LIST"); result.success(true) }
                "requestFileDownload" -> {
                    val fn = call.argument<String>("filename")
                    if (fn != null) { sendSocketLine("DOWNLOAD_FILE:$fn"); result.success(true) }
                    else result.error("BAD_ARGS", "filename required", null)
                }
                "deleteWatchFiles"    -> { sendSocketLine("DELETE_WATCH_FILES"); result.success(true) }
                "clearSyncCache"      -> {
                    val dest = File(context.cacheDir, "sh_sync")
                    if (dest.exists()) dest.deleteRecursively()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
            override fun onCancel(args: Any?) { eventSink = null }
        })
    }

    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // SERVER START
    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

    private fun startServer(mode: String) {
        if (isServerRunning) return
        isServerRunning = true

        val ip = getActiveIpAddress()
        Log.i(TAG, "Starting server in mode: $mode. Active IP: $ip")

        // Start Foreground Service to keep app alive
        try {
            val intent = android.content.Intent(context, SyncForegroundService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Foreground Service start failed: ${e.message}")
        }

        // 1. Start TCP ServerSocket
        startTcpServerThread(ip)

        // 2. Broadcast UDP Beacon on targeted subnet
        startMultiSubnetUdpBeacon(ip, mode)

        if (mode == "HOTSPOT") {
            sendEvent("hotspotStarted", mapOf(
                "ssid"     to FIXED_SSID,
                "password" to PRIMARY_PASS,
                "ip"       to ip
            ))
        }
    }

    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // MULTI-SUBNET UDP BEACON (FOR MOBILE HOTSPOT, AP, & BT TETHERING)
    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

    private fun startMultiSubnetUdpBeacon(primaryIp: String, mode: String) {
        if (udpBeaconThread?.isAlive == true) return
        udpBeaconThread = Thread {
            try {
                val socket = DatagramSocket(null)
                socket.reuseAddress = true
                socket.bind(InetSocketAddress(primaryIp, 0))
                socket.broadcast = true

                while (isServerRunning) {
                    val activeIp = getActiveIpAddress()
                    val msg = "HEALTHPORT_SERVER:$activeIp:$TCP_PORT"
                    val bytes = msg.toByteArray(Charsets.UTF_8)

                    // 1. Universal Subnet Broadcast
                    try {
                        val universalBcast = InetAddress.getByName("255.255.255.255")
                        socket.send(DatagramPacket(bytes, bytes.size, universalBcast, UDP_PORT))
                    } catch (_: Exception) {}

                    if (mode == "HOTSPOT") {
                        // 2. Hotspot Subnet Dynamic (x.y.z.255)
                        try {
                            val parts = activeIp.split(".")
                            if (parts.size == 4) {
                                val dynamicBcast = InetAddress.getByName("${parts[0]}.${parts[1]}.${parts[2]}.255")
                                socket.send(DatagramPacket(bytes, bytes.size, dynamicBcast, UDP_PORT))
                            }
                        } catch (_: Exception) {}
                        
                        // Fallback Hotspot Subnet (192.168.43.255)
                        try {
                            val hotspotBcast = InetAddress.getByName("192.168.43.255")
                            socket.send(DatagramPacket(bytes, bytes.size, hotspotBcast, UDP_PORT))
                        } catch (_: Exception) {}
                    } else if (mode == "BT") {
                        // 3. Bluetooth PAN Subnet (192.168.44.255 & 192.168.45.255)
                        try {
                            val btBcast1 = InetAddress.getByName("192.168.44.255")
                            socket.send(DatagramPacket(bytes, bytes.size, btBcast1, UDP_PORT))
                        } catch (_: Exception) {}
                        try {
                            val btBcast2 = InetAddress.getByName("192.168.45.255")
                            socket.send(DatagramPacket(bytes, bytes.size, btBcast2, UDP_PORT))
                        } catch (_: Exception) {}
                    } else {
                        // 4. Wi-Fi Direct/AP Subnets (192.168.49.255)
                        try {
                            val p2pBcast = InetAddress.getByName("192.168.49.255")
                            socket.send(DatagramPacket(bytes, bytes.size, p2pBcast, UDP_PORT))
                        } catch (_: Exception) {}
                    }

                    Log.i(TAG, "UDP Beacon ($mode) sent: $msg")
                    Thread.sleep(1000)
                }
                socket.close()
            } catch (e: Exception) { Log.e(TAG, "UDP Beacon error: ${e.message}") }
        }.apply { isDaemon = true; start() }
    }

    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // TCP SERVER
    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

    private fun startTcpServerThread(activeIp: String) {
        Thread {
            try {
                serverSocket = ServerSocket().apply {
                    reuseAddress = true
                    receiveBufferSize = BUFFER_SIZE
                    bind(InetSocketAddress(TCP_PORT))
                }
                Log.i(TAG, "TCP Server listening on $activeIp:$TCP_PORT with 1MB Buffer")
                while (isServerRunning) {
                    val socket = serverSocket?.accept() ?: break
                    Log.i(TAG, "Watch connected from ${socket.inetAddress.hostAddress}")
                    socket.receiveBufferSize = BUFFER_SIZE
                    socket.sendBufferSize = BUFFER_SIZE
                    clientSocket = socket
                    socketWriter = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                    readSocketStream(socket)
                }
            } catch (e: Exception) {
                Log.e(TAG, "TCP Server error: ${e.message}")
            }
        }.apply { isDaemon = true; start() }
    }

    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // STOP SERVER
    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

    fun stopServer() {
        isServerRunning = false
        
        // Stop Foreground Service
        val intent = android.content.Intent(context, SyncForegroundService::class.java)
        context.stopService(intent)

        closeClientSocket()
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        udpBeaconThread = null
        hotspotReservation?.close()
        hotspotReservation = null
        sendEvent("connectionStateChanged", mapOf("connected" to false))
    }

    private fun updateNotification(message: String, progress: Int, isComplete: Boolean, isResumed: Boolean) {
        val intent = android.content.Intent(context, SyncForegroundService::class.java).apply {
            action = if (isComplete) SyncForegroundService.ACTION_COMPLETE_SYNC else SyncForegroundService.ACTION_UPDATE_PROGRESS
            putExtra("message", message)
            putExtra("progress", progress)
            putExtra("isResumed", isResumed)
        }
        context.startService(intent)
    }

    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // SOCKET COMMUNICATION
    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

    private fun closeClientSocket() {
        try { socketWriter?.close() } catch (_: Exception) {}
        try { clientSocket?.close() } catch (_: Exception) {}
        socketWriter = null; clientSocket = null
    }

    private fun sendSocketLine(text: String) {
        Thread {
            try {
                if (socketWriter != null) {
                    socketWriter?.run { write(text + "\n"); flush() }
                    Log.i(TAG, "[SOCKET] Sent: $text")
                } else {
                    Log.e(TAG, "[SOCKET] socketWriter is NULL - cannot send: $text")
                }
            }
            catch (e: Exception) { Log.e(TAG, "sendSocketLine: ${e.message}") }
        }.start()
    }

    private fun readLineFromStream(inStream: InputStream): String? {
        val baos = ByteArrayOutputStream()
        var b: Int
        while (true) {
            b = inStream.read()
            if (b == -1) {
                if (baos.size() == 0) return null
                break
            }
            if (b == '\n'.code) break
            if (b != '\r'.code) baos.write(b)
        }
        return baos.toString("UTF-8")
    }

    private fun readSocketStream(socket: Socket) {
        Thread {
            try {
                val inStream = BufferedInputStream(socket.getInputStream(), BUFFER_SIZE)
                while (isServerRunning) {
                    val line = readLineFromStream(inStream) ?: break
                    Log.i(TAG, "Socket: $line")
                    when {
                        line == "HELLO_FROM_WATCH" -> {
                            Log.i(TAG, "[HANDSHAKE] HELLO_FROM_WATCH received. eventSink=${if (eventSink != null) "SET" else "NULL"}")
                            if (eventSink != null) {
                                sendEvent("connectionStateChanged", mapOf(
                                    "connected" to true,
                                    "deviceName" to (socket.inetAddress.hostAddress ?: "Watch")
                                ))
                                Log.i(TAG, "[HANDSHAKE] connectionStateChanged event fired.")
                            } else {
                                Log.e(TAG, "[HANDSHAKE] eventSink is NULL - event DROPPED. Flutter is not listening!")
                            }
                        }
                        line == "COMPRESSING" ->
                            sendEvent("compressing", null)
                        line.startsWith("COMPRESSING_PROGRESS:") -> {
                            val parts = line.substring("COMPRESSING_PROGRESS:".length).split(":")
                            if (parts.size >= 2) {
                                val current = parts[0].toLongOrNull() ?: 0L
                                val total = parts[1].toLongOrNull() ?: 0L
                                val progress = if (total > 0) current.toDouble() / total else 0.0
                                sendEvent("compressingProgress", mapOf(
                                    "progress" to progress,
                                    "transferred" to current,
                                    "total" to total
                                ))
                            }
                        }
                        line.startsWith("FILE_LIST:") ->
                            sendEvent("fileListReceived", line.substring("FILE_LIST:".length))
                        line.startsWith("FILE_START:") -> {
                            val p = line.split(":")
                            if (p.size >= 4) receiveFilePayload(inStream, p[1], p[2].toLong(), p[3])
                        }
                        line.startsWith("FILE_START_CHUNKED:") -> {
                            val p = line.split(":")
                            if (p.size >= 2) receiveChunkedFilePayload(inStream, p[1])
                        }
                        line.startsWith("ERROR:") ->
                            sendEvent("downloadFailure", mapOf("error" to line.substring("ERROR:".length)))
                        line == "DELETE_WATCH_FILES_OK" ->
                            sendEvent("deleteWatchFilesOk", null)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "readSocketStream: ${e.message}")
            } finally { closeClientSocket() }
        }.apply { isDaemon = true; start() }
    }

    private fun receiveFilePayload(inStream: InputStream, filename: String, totalBytes: Long, expectedMd5: String) {
        val dest = File(context.cacheDir, "sh_sync").apply { mkdirs() }
        val tmp  = File(dest, filename)
        try {
            // Write payload with BufferedOutputStream and 1MB buffer
            BufferedOutputStream(FileOutputStream(tmp), BUFFER_SIZE).use { fos ->
                val buf = ByteArray(65536) // 64KB chunk reads
                var r: Int
                var got = 0L
                while (got < totalBytes) {
                    r = inStream.read(buf, 0, minOf(buf.size.toLong(), totalBytes - got).toInt())
                    if (r == -1) throw EOFException("Premature stream close")
                    fos.write(buf, 0, r)
                    got += r
                    sendEvent("downloadProgress", mapOf("filename" to filename,
                        "progress" to got.toDouble() / totalBytes, "transferred" to got, "total" to totalBytes))
                }
                fos.flush()
            }
            val md5 = calcMd5(tmp)
            if (md5.equals(expectedMd5, true))
                sendEvent("downloadComplete", mapOf("filename" to filename, "path" to tmp.absolutePath))
            else
                sendEvent("downloadFailure", mapOf("filename" to filename, "error" to "MD5 mismatch"))
        } catch (e: Exception) {
            sendEvent("downloadFailure", mapOf("filename" to filename, "error" to (e.message ?: "unknown")))
            tmp.delete()
        }
    }

    private fun receiveChunkedFilePayload(inStream: InputStream, filename: String) {
        val dest = File(context.cacheDir, "sh_sync").apply { mkdirs() }
        val tmp  = File(dest, filename)
        try {
            BufferedOutputStream(FileOutputStream(tmp), BUFFER_SIZE).use { fos ->
                val buf = ByteArray(65536)
                var got = 0L
                var currentStreamProgress = -1.0
                while (true) {
                    val headerLine = readLineFromStream(inStream) ?: throw java.io.EOFException("Premature stream close")
                    if (headerLine.startsWith("CHUNK:")) {
                        val chunkSize = headerLine.substring("CHUNK:".length).toInt()
                        if (chunkSize == 0) break // End of file
                        
                        var chunkRead = 0
                        while (chunkRead < chunkSize) {
                            val r = inStream.read(buf, 0, minOf(buf.size, chunkSize - chunkRead))
                            if (r == -1) throw java.io.EOFException("Premature stream close inside chunk")
                            fos.write(buf, 0, r)
                            chunkRead += r
                            got += r
                        }
                        // Report progress with total = -1, but pass currentStreamProgress if available
                        sendEvent("downloadProgress", mapOf("filename" to filename,
                            "progress" to currentStreamProgress, "transferred" to got, "total" to -1))
                    } else if (headerLine.startsWith("PROGRESS:")) {
                        val parts = headerLine.split(":")
                        if (parts.size >= 3) {
                            val cur = parts[1].toLongOrNull() ?: 0L
                            val tot = parts[2].toLongOrNull() ?: 0L
                            currentStreamProgress = if (tot > 0) cur.toDouble() / tot else -1.0
                            sendEvent("downloadProgress", mapOf("filename" to filename,
                                "progress" to currentStreamProgress, "transferred" to got, "total" to -1))
                        }
                    } else {
                        throw Exception("Unexpected chunk header: $headerLine")
                    }
                }
                fos.flush()
            }
            sendEvent("downloadComplete", mapOf("filename" to filename, "path" to tmp.absolutePath))
        } catch (e: Exception) {
            sendEvent("downloadFailure", mapOf("filename" to filename, "error" to (e.message ?: "unknown")))
            tmp.delete()
        }
    }

    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // UTILITIES
    // ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

    private fun sendEvent(type: String, data: Any?) {
        uiHandler.post { eventSink?.success(mapOf("type" to type, "data" to data)) }
    }

    private fun calcMd5(file: File): String {
        val d = MessageDigest.getInstance("MD5")
        FileInputStream(file).use { fis ->
            val b = ByteArray(32768) // 32KB buffer for faster hashing
            var r: Int
            while (fis.read(b).also { r = it } > 0) d.update(b, 0, r)
        }
        return BigInteger(1, d.digest()).toString(16).padStart(32, '0')
    }

    private fun getActiveIpAddress(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            val allIps = mutableListOf<String>()
            var bestIp: String? = null
            var fallbackIp: String? = null
            
            val sb = java.lang.StringBuilder("Network Interfaces: ")
            
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val name = networkInterface.name.lowercase(java.util.Locale.ROOT)
                val addresses = networkInterface.inetAddresses
                
                while (addresses.hasMoreElements()) {
                    val inetAddress = addresses.nextElement()
                    if (!inetAddress.isLoopbackAddress && inetAddress.hostAddress.indexOf(':') < 0) {
                        val host = inetAddress.hostAddress ?: continue
                        allIps.add(host)
                        sb.append("[$name=$host] ")
                        
                        // Ignore clat/v4 interfaces which often get 192.0.0.x
                        if (host.startsWith("192.0.0.")) {
                            continue
                        }
                        
                        if (name.contains("wlan1") || name.contains("swlan") || name.contains("ap") || name.contains("bt-pan") || name.contains("rndis")) {
                            bestIp = host
                        } else if (name.contains("wlan") && bestIp == null) {
                            fallbackIp = host
                        } else if (host.startsWith("192.168.") && bestIp == null && fallbackIp == null) {
                            fallbackIp = host
                        }
                    }
                }
            }
            
            Log.d(TAG, sb.toString())
            
            if (bestIp != null) return bestIp
            if (fallbackIp != null) return fallbackIp
            
            val nonCellular = allIps.firstOrNull { !it.startsWith("192.0.0.") && (!it.startsWith("10.") || it.startsWith("10.10") || it.startsWith("10.3")) }
            return nonCellular ?: allIps.firstOrNull() ?: "192.168.43.1"
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting active IP: ${e.message}")
        }
        return "192.168.43.1"
    }
}
