package com.samsung.health.client

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets

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

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer"         -> { startAdvertising(); result.success(true) }
                "stopServer"          -> { stopServer();  result.success(true) }
                "updateNotification"  -> { result.success(true) }
                "requestFileList"     -> { sendCommand("GET_FILE_LIST"); result.success(true) }
                "requestFileDownload" -> {
                    val fn = call.argument<String>("filename")
                    if (fn != null) { sendCommand("DOWNLOAD_FILE:$fn"); result.success(true) }
                    else result.error("BAD_ARGS", "filename required", null)
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
                sendEvent("hotspotStarted", mapOf("ssid" to "Nearby", "password" to "Connections", "ip" to "P2P"))
            }
            .addOnFailureListener { e -> sendEvent("serverError", e.message) }
    }

    fun stopServer() {
        Nearby.getConnectionsClient(context).stopAdvertising()
        Nearby.getConnectionsClient(context).stopAllEndpoints()
        connectedEndpointId = null
        sendEvent("connectionStateChanged", mapOf("connected" to false))
    }

    private fun sendCommand(cmd: String) {
        val ep = connectedEndpointId ?: return
        Nearby.getConnectionsClient(context).sendPayload(ep, Payload.fromBytes(cmd.toByteArray(StandardCharsets.UTF_8)))
    }

    private val connCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(ep: String, info: ConnectionInfo) {
            Nearby.getConnectionsClient(context).acceptConnection(ep, payloadCb)
        }
        override fun onConnectionResult(ep: String, res: ConnectionResolution) {
            if (res.status.isSuccess) {
                connectedEndpointId = ep
                sendEvent("connectionStateChanged", mapOf("connected" to true, "deviceName" to "Watch"))
                sendCommand("HELLO_FROM_PHONE")
            } else {
                sendEvent("serverError", "Connection failed")
            }
        }
        override fun onDisconnected(ep: String) {
            if (connectedEndpointId == ep) connectedEndpointId = null
            sendEvent("connectionStateChanged", mapOf("connected" to false))
        }
    }

    private val incomingFilePayloads = mutableMapOf<Long, Payload>()
    private var currentDownloadFilename: String? = null

    private val payloadCb = object : PayloadCallback() {
        override fun onPayloadReceived(ep: String, p: Payload) {
            if (p.type == Payload.Type.BYTES) {
                val msg = String(p.asBytes()!!, StandardCharsets.UTF_8)
                if (msg == "HELLO_FROM_WATCH") {
                    sendEvent("connectionStateChanged", mapOf("connected" to true, "deviceName" to "Watch"))
                } else if (msg.startsWith("FILE_LIST:")) {
                    sendEvent("fileListReceived", msg.substring(10))
                } else if (msg.startsWith("FILE_START:")) {
                    currentDownloadFilename = msg.substring(11)
                }
            } else if (p.type == Payload.Type.FILE) {
                incomingFilePayloads[p.id] = p
            }
        }

        override fun onPayloadTransferUpdate(ep: String, upd: PayloadTransferUpdate) {
            val fn = currentDownloadFilename ?: "unknown.zip"
            if (upd.status == PayloadTransferUpdate.Status.IN_PROGRESS) {
                val progress = if (upd.totalBytes > 0) upd.bytesTransferred.toDouble() / upd.totalBytes else -1.0
                sendEvent("downloadProgress", mapOf("filename" to fn, "progress" to progress, "transferred" to upd.bytesTransferred, "total" to upd.totalBytes))
            } else if (upd.status == PayloadTransferUpdate.Status.SUCCESS) {
                val p = incomingFilePayloads.remove(upd.payloadId)
                if (p != null && p.type == Payload.Type.FILE) {
                    val dest = File(context.cacheDir, "sh_sync").apply { mkdirs() }
                    val tmp = File(dest, fn)
                    val javaFile = p.asFile()?.asJavaFile()
                    if (javaFile != null && javaFile.exists()) {
                        javaFile.renameTo(tmp)
                    } else {
                        val uri = p.asFile()?.asUri()
                        if (uri != null) {
                            try {
                                context.contentResolver.openInputStream(uri)?.use { input ->
                                    FileOutputStream(tmp).use { output -> input.copyTo(output) }
                                }
                            } catch (e: Exception) {}
                        }
                    }
                    sendEvent("downloadComplete", mapOf("filename" to fn, "path" to tmp.absolutePath))
                }
            } else if (upd.status == PayloadTransferUpdate.Status.FAILURE || upd.status == PayloadTransferUpdate.Status.CANCELED) {
                incomingFilePayloads.remove(upd.payloadId)
                sendEvent("downloadFailure", mapOf("filename" to fn, "error" to "Transfer failed"))
            }
        }
    }

    private fun sendEvent(type: String, data: Any?) {
        uiHandler.post { eventSink?.success(mapOf("type" to type, "data" to data)) }
    }
}
