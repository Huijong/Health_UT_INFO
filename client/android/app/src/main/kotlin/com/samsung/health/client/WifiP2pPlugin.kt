package com.samsung.health.client

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.InetAddress
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors

class WifiP2pPlugin(private val context: Context) {
    companion object {
        private const val TAG = "HP_WifiPlugin"
        private const val METHOD_CHANNEL = "com.samsung.health.client/wifi_p2p"
        private const val EVENT_CHANNEL  = "com.samsung.health.client/wifi_p2p_events"
        private const val SERVICE_ID = "com.samsung.health.sync"
    }

    private val uiHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var connectedEndpointId: String? = null
    
    private var serverSocket: ServerSocket? = null
    private var isTcpServerRunning = false

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer"         -> { startAdvertising(); result.success(true) }
                "stopServer"          -> { stopServer();  result.success(true) }
                "updateNotification"  -> { result.success(true) }
                "requestFileList"     -> { sendCommand("GET_FILE_LIST"); result.success(true) }
                "requestFileDownload" -> {
                    val fn = call.argument<String>("filename")
                    if (fn != null) { 
                        startTcpServerAndNotifyWatch(fn)
                        result.success(true) 
                    }
                    else result.error("BAD_ARGS", "filename required", null)
                }
                "checkManageStorage"  -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        result.success(true)
                    }
                }
                "requestManageStorage"-> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                            intent.addCategory("android.intent.category.DEFAULT")
                            intent.data = Uri.parse(String.format("package:%s", context.packageName))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                "deleteWatchFiles"    -> { sendCommand("DELETE_WATCH_FILES"); result.success(true) }
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

    private fun startAdvertising() {
        val options = AdvertisingOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build()
        Nearby.getConnectionsClient(context).startAdvertising("Phone", SERVICE_ID, connCallback, options)
            .addOnSuccessListener { 
                Log.i(TAG, "Advertising started") 
                // Send dummy hotspotStarted event so Dart UI triggers requestWatchWifiJoin
                sendEvent("hotspotStarted", mapOf(
                    "ssid" to "healthport",
                    "password" to "12345678",
                    "ip" to getActiveIpAddress()
                ))
            }
            .addOnFailureListener { e -> Log.e(TAG, "Advertising failed: ${e.message}") }
    }

    fun stopServer() {
        Nearby.getConnectionsClient(context).stopAdvertising()
        Nearby.getConnectionsClient(context).stopAllEndpoints()
        stopTcpServer()
        connectedEndpointId = null
        sendEvent("connectionStateChanged", mapOf("connected" to false))
    }

    // -----------------------------------------------------------------------------------------
    // HYBRID TCP SERVER LOGIC
    // -----------------------------------------------------------------------------------------
    private fun getActiveIpAddress(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            var fallbackIp = "192.168.43.1"
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                val addresses = iface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val addr = addresses.nextElement()
                    if (!addr.isLoopbackAddress && addr.hostAddress.contains(".")) {
                        val ip = addr.hostAddress
                        // Look for typical Android hotspot subnets
                        if (ip.startsWith("192.168.") || ip.startsWith("172.") || ip.startsWith("10.")) {
                            // If it's literally the hotspot gateway, prefer it
                            if (ip == "192.168.43.1") return ip
                            fallbackIp = ip
                        }
                    }
                }
            }
            return fallbackIp
        } catch (e: Exception) {
            Log.e(TAG, "Error getting IP: ${e.message}")
        }
        return "192.168.43.1" // Fallback default Android hotspot IP
    }

    private fun startTcpServerAndNotifyWatch(filename: String) {
        // Prevent double TCP server if already running
        if (isTcpServerRunning) {
            Log.w(TAG, "TCP server already running, skipping duplicate request")
            return
        }
        Executors.newSingleThreadExecutor().execute {
            try {
                val ip = getActiveIpAddress()
                serverSocket = ServerSocket(34567, 50, InetAddress.getByName(ip)).apply {
                    receiveBufferSize = 1048576 // 1MB
                    soTimeout = 120_000 // Wait max 2 minutes for watch to connect
                }
                isTcpServerRunning = true
                
                // Tell the Watch to connect via TCP
                sendCommand("TCP_READY:$ip:34567:$filename")
                
                Log.d(TAG, "TCP Server listening on $ip:34567 for $filename")
                val clientSocket = serverSocket?.accept()
                if (clientSocket != null) {
                    Log.d(TAG, "Watch connected via TCP from ${clientSocket.inetAddress.hostAddress}")
                    clientSocket.receiveBufferSize = 1048576
                    receiveFileViaTcp(clientSocket.getInputStream(), filename)
                    clientSocket.close()
                }
            } catch (e: Exception) {
                Log.e(TAG, "TCP Server error: ${e.message}")
                stopTcpServer()
            }
        }
    }


    private fun stopTcpServer() {
        isTcpServerRunning = false
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
    }

    private fun receiveFileViaTcp(inputStream: InputStream, filename: String) {
        val destDir = File(context.cacheDir, "sh_sync")
        if (!destDir.exists()) destDir.mkdirs()
        val destFile = File(destDir, filename)
        
        try {
            val dataIn = java.io.DataInputStream(inputStream)
            val expectedSize = dataIn.readLong()
            Log.d(TAG, "TCP expected file size: $expectedSize bytes for $filename")

            var receivedBytes = 0L
            val buffer = ByteArray(1048576) // 1MB chunks
            var bytesRead: Int
            
            val fos = FileOutputStream(destFile)
            var lastUpdate = System.currentTimeMillis()
            
            while (dataIn.read(buffer).also { bytesRead = it } != -1) {
                fos.write(buffer, 0, bytesRead)
                receivedBytes += bytesRead
                
                val now = System.currentTimeMillis()
                if (now - lastUpdate > 200) { // Update every 200ms
                    lastUpdate = now
                    val progress = if (expectedSize > 0) receivedBytes.toDouble() / expectedSize.toDouble() else -1.0
                    sendEvent("downloadProgress", mapOf(
                        "progress" to progress,
                        "transferred" to receivedBytes.toLong(),
                        "total" to expectedSize
                    ))
                }
            }
            fos.flush()
            fos.close()
            
            Log.d(TAG, "TCP File received completely: $receivedBytes bytes")
            sendEvent("downloadComplete", mapOf(
                "filename" to filename,
                "path" to destFile.absolutePath
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "TCP receive error: ${e.message}")
            destFile.delete()
        } finally {
            stopTcpServer()
        }
    }

    // -----------------------------------------------------------------------------------------
    // NEARBY CONNECTIONS LOGIC
    // -----------------------------------------------------------------------------------------
    private val connCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(epId: String, info: ConnectionInfo) {
            Log.i(TAG, "Connection initiated by ${info.endpointName}")
            Nearby.getConnectionsClient(context).acceptConnection(epId, payloadCallback)
        }
        override fun onConnectionResult(epId: String, res: ConnectionResolution) {
            if (res.status.isSuccess) {
                Log.i(TAG, "Connected to $epId")
                connectedEndpointId = epId
                sendEvent("connectionStateChanged", mapOf("connected" to true, "deviceName" to "Smartwatch"))
            } else {
                Log.e(TAG, "Connection failed: ${res.status.statusCode}")
            }
        }
        override fun onDisconnected(epId: String) {
            Log.i(TAG, "Disconnected from $epId")
            if (connectedEndpointId == epId) {
                connectedEndpointId = null
                sendEvent("connectionStateChanged", mapOf("connected" to false))
            }
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(epId: String, p: Payload) {
            if (p.type == Payload.Type.BYTES) {
                val msg = String(p.asBytes()!!, StandardCharsets.UTF_8)
                Log.i(TAG, "Received msg: $msg")
                if (msg == "HELLO_FROM_WATCH") {
                    // Start by requesting file list
                    uiHandler.postDelayed({ sendCommand("GET_FILE_LIST") }, 500)
                } else if (msg.startsWith("FILE_LIST:")) {
                    val jsonStr = msg.substring("FILE_LIST:".length)
                    try {
                        sendEvent("fileListReceived", jsonStr)
                    } catch (e: Exception) {
                        Log.e(TAG, "JSON Parse error: ${e.message}")
                    }
                } else if (msg == "PREPARING_FILE") {
                    sendEvent("compressing", "watch")
                }
            }
        }
        override fun onPayloadTransferUpdate(epId: String, upd: PayloadTransferUpdate) {}
    }

    private fun sendCommand(cmd: String) {
        val ep = connectedEndpointId ?: return
        Log.i(TAG, "Sending command: $cmd")
        Nearby.getConnectionsClient(context).sendPayload(ep, Payload.fromBytes(cmd.toByteArray(StandardCharsets.UTF_8)))
    }

    private fun sendEvent(method: String, arguments: Any) {
        uiHandler.post {
            eventSink?.success(mapOf("type" to method, "data" to arguments))
        }
    }
}
