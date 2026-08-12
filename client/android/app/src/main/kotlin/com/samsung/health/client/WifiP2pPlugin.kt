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

class WifiP2pPlugin(private val context: Context) {

    companion object {
        private const val TAG = "HP_WifiPlugin"
        private const val METHOD_CHANNEL = "com.samsung.health.client/wifi_p2p"
        private const val EVENT_CHANNEL  = "com.samsung.health.client/wifi_p2p_events"
        private const val TCP_PORT       = 8888
        private const val UDP_PORT       = 8889

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

    // ────────────────────────────────────────────────────────────────
    // REGISTRATION
    // ────────────────────────────────────────────────────────────────

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer"         -> {
                    val mode = call.argument<String>("mode") ?: "AP"
                    startServer(mode)
                    result.success(true)
                }
                "stopServer"          -> { stopServer();  result.success(true) }
                "requestFileList"     -> { sendSocketLine("GET_FILE_LIST"); result.success(true) }
                "requestFileDownload" -> {
                    val fn = call.argument<String>("filename")
                    if (fn != null) { sendSocketLine("DOWNLOAD_FILE:$fn"); result.success(true) }
                    else result.error("BAD_ARGS", "filename required", null)
                }
                "deleteWatchFiles"    -> { sendSocketLine("DELETE_WATCH_FILES"); result.success(true) }
                else -> result.notImplemented()
            }
        }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
            override fun onCancel(args: Any?) { eventSink = null }
        })
    }

    // ────────────────────────────────────────────────────────────────
    // SERVER START
    // ────────────────────────────────────────────────────────────────

    private fun startServer(mode: String) {
        if (isServerRunning) return
        isServerRunning = true

        val ip = getActiveIpAddress()
        Log.d(TAG, "Starting server in mode: $mode. Active IP: $ip")

        // 1. Start TCP ServerSocket
        startTcpServerThread()

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

    // ────────────────────────────────────────────────────────────────
    // MULTI-SUBNET UDP BEACON (FOR MOBILE HOTSPOT, AP, & BT TETHERING)
    // ────────────────────────────────────────────────────────────────

    private fun startMultiSubnetUdpBeacon(primaryIp: String, mode: String) {
        if (udpBeaconThread?.isAlive == true) return
        udpBeaconThread = Thread {
            try {
                val socket = DatagramSocket()
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
                        // 2. Hotspot Subnet (192.168.43.255)
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

                    Log.d(TAG, "UDP Beacon ($mode) sent: $msg")
                    Thread.sleep(1000)
                }
                socket.close()
            } catch (e: Exception) { Log.e(TAG, "UDP Beacon error: ${e.message}") }
        }.apply { isDaemon = true; start() }
    }

    // ────────────────────────────────────────────────────────────────
    // TCP SERVER
    // ────────────────────────────────────────────────────────────────

    private fun startTcpServerThread() {
        Thread {
            try {
                serverSocket = ServerSocket(TCP_PORT).apply {
                    // Set receive buffer size to 1MB
                    receiveBufferSize = BUFFER_SIZE
                }
                Log.d(TAG, "TCP Server listening on port $TCP_PORT with 1MB Buffer")
                while (isServerRunning) {
                    val socket = serverSocket?.accept() ?: break
                    Log.d(TAG, "Watch connected from ${socket.inetAddress.hostAddress}")
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

    // ────────────────────────────────────────────────────────────────
    // STOP SERVER
    // ────────────────────────────────────────────────────────────────

    private fun stopServer() {
        isServerRunning = false
        closeClientSocket()
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        udpBeaconThread = null
        hotspotReservation?.close()
        hotspotReservation = null
        sendEvent("connectionStateChanged", mapOf("connected" to false))
    }

    // ────────────────────────────────────────────────────────────────
    // SOCKET COMMUNICATION
    // ────────────────────────────────────────────────────────────────

    private fun closeClientSocket() {
        try { socketWriter?.close() } catch (_: Exception) {}
        try { clientSocket?.close() } catch (_: Exception) {}
        socketWriter = null; clientSocket = null
    }

    private fun sendSocketLine(text: String) {
        Thread {
            try { socketWriter?.run { write(text + "\n"); flush() } }
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
                    Log.d(TAG, "Socket: $line")
                    when {
                        line == "HELLO_FROM_WATCH" -> {
                            sendEvent("connectionStateChanged", mapOf(
                                "connected" to true,
                                "deviceName" to (socket.inetAddress.hostAddress ?: "Watch")
                            ))
                        }
                        line == "COMPRESSING" ->
                            sendEvent("compressing", null)
                        line.startsWith("FILE_LIST:") ->
                            sendEvent("fileListReceived", line.substring("FILE_LIST:".length))
                        line.startsWith("FILE_START:") -> {
                            val p = line.split(":")
                            if (p.size >= 4) receiveFilePayload(inStream, p[1], p[2].toLong(), p[3])
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
        }
    }

    // ────────────────────────────────────────────────────────────────
    // UTILITIES
    // ────────────────────────────────────────────────────────────────

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
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val inetAddress = addresses.nextElement()
                    if (!inetAddress.isLoopbackAddress && inetAddress.hostAddress.indexOf(':') < 0) {
                        val host = inetAddress.hostAddress
                        // Prefer Bluetooth PAN (192.168.44.x or 192.168.45.x) or Mobile Hotspot (192.168.43.x)
                        if (host.startsWith("192.168.44.") || host.startsWith("192.168.45.") || host.startsWith("192.168.43.")) {
                            return host
                        }
                    }
                }
            }
            // Fallback: Check general IPv4
            val interfaces2 = NetworkInterface.getNetworkInterfaces()
            while (interfaces2.hasMoreElements()) {
                val networkInterface = interfaces2.nextElement()
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val inetAddress = addresses.nextElement()
                    if (!inetAddress.isLoopbackAddress && inetAddress.hostAddress.indexOf(':') < 0) {
                        return inetAddress.hostAddress
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting active IP: ${e.message}")
        }
        return "192.168.43.1"
    }
}
