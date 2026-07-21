package com.samsung.health.client.watch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsStatusCodes
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

class SyncService : Service() {

    companion object {
        private const val TAG = "HP_SyncService"
        private const val CHANNEL_ID = "WatchSyncServiceChannel"
        private const val SERVICE_ID = "com.samsung.health.client.sync"
    }

    private var connectedEndpointId: String? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        // Disabled startForeground for testing to prevent API 34 startup crashes
        // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        //     startForeground(1, createNotification(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        // } else {
        //     startForeground(1, createNotification())
        // }
        startAdvertising()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopAdvertising()
        super.onDestroy()
    }

    private fun startAdvertising() {
        val advertisingOptions = AdvertisingOptions.Builder()
            .setStrategy(Strategy.P2P_POINT_TO_POINT)
            .build()

        writeLog("Starting advertising with strategy P2P_POINT_TO_POINT...")
        Nearby.getConnectionsClient(this)
            .startAdvertising(
                Build.MODEL,
                SERVICE_ID,
                connectionLifecycleCallback,
                advertisingOptions
            )
            .addOnSuccessListener {
                writeLog("Advertising started successfully.")
            }
            .addOnFailureListener { e ->
                writeLog("Failed to start advertising: ${e.message}")
            }
    }

    private fun stopAdvertising() {
        writeLog("Stopping advertising...")
        Nearby.getConnectionsClient(this).stopAdvertising()
        connectedEndpointId?.let {
            Nearby.getConnectionsClient(this).disconnectFromEndpoint(it)
            writeLog("Disconnected from endpoint: $it")
        }
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            writeLog("Connection initiated with $endpointId (${info.endpointName}). Accepting...")
            Nearby.getConnectionsClient(this@SyncService)
                .acceptConnection(endpointId, payloadCallback)
                .addOnFailureListener { e ->
                    writeLog("Accept connection failed: ${e.message}")
                }
        }

        override fun onConnectionResult(endpointId: String, resolution: ConnectionResolution) {
            when (resolution.status.statusCode) {
                ConnectionsStatusCodes.STATUS_OK -> {
                    writeLog("Connected successfully to $endpointId")
                    connectedEndpointId = endpointId
                }
                ConnectionsStatusCodes.STATUS_CONNECTION_REJECTED -> {
                    writeLog("Connection rejected by $endpointId")
                }
                ConnectionsStatusCodes.STATUS_ERROR -> {
                    writeLog("Connection error with $endpointId")
                }
            }
        }

        override fun onDisconnected(endpointId: String) {
            writeLog("Disconnected from $endpointId")
            if (connectedEndpointId == endpointId) {
                connectedEndpointId = null
            }
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type == Payload.Type.BYTES) {
                val bytes = payload.asBytes() ?: return
                val command = String(bytes, Charsets.UTF_8)
                writeLog("Received command: $command")
                handleCommand(endpointId, command)
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            val statusString = when (update.status) {
                PayloadTransferUpdate.Status.IN_PROGRESS -> "IN_PROGRESS"
                PayloadTransferUpdate.Status.SUCCESS -> "SUCCESS"
                PayloadTransferUpdate.Status.FAILURE -> "FAILURE"
                PayloadTransferUpdate.Status.CANCELED -> "CANCELED"
                else -> "UNKNOWN"
            }
            writeLog("Payload transfer update - ID: ${update.getPayloadId()}, Status: $statusString, Bytes: ${update.bytesTransferred}/${update.totalBytes}")
        }
    }

    private fun handleCommand(endpointId: String, command: String) {
        when {
            command == "GET_FILE_LIST" -> {
                val fileListJson = getFileListJson()
                sendText(endpointId, fileListJson)
            }
            command.startsWith("DOWNLOAD_FILE:") -> {
                val filename = command.substring("DOWNLOAD_FILE:".length).trim()
                sendFile(endpointId, filename)
            }
            else -> {
                sendText(endpointId, "ERROR:Unknown command")
            }
        }
    }

    private fun getFileListJson(): String {
        val folder = File("/sdcard/Documents/COLA_FILE/")
        if (!folder.exists()) {
            folder.mkdirs()
        }
        val files = folder.listFiles { _, name -> name.endsWith(".zip", ignoreCase = true) }
        val jsonArray = JSONArray()
        files?.forEach { file ->
            val obj = JSONObject()
            obj.put("name", file.name)
            obj.put("size", file.length())
            obj.put("last_modified", file.lastModified())
            jsonArray.put(obj)
        }
        return jsonArray.toString()
    }

    private fun writeLog(message: String) {
        try {
            val logFile = File("/sdcard/Documents/COLA_FILE/sync_log.txt")
            logFile.appendText("[${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}] $message\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write log: ${e.message}")
        }
    }

    private fun sendFile(endpointId: String, filename: String) {
        val file = File("/sdcard/Documents/COLA_FILE/", filename)
        if (!file.exists()) {
            writeLog("Error: File not found - $filename")
            sendText(endpointId, "ERROR:File not found")
            return
        }

        try {
            writeLog("Computing MD5 for $filename...")
            val md5 = getMd5OfFile(file)

            writeLog("Opening ParcelFileDescriptor for $filename...")
            val pfd = android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY)
            val filePayload = Payload.fromFile(pfd)
            val payloadId = filePayload.getId()

            writeLog("Computed MD5: $md5. Sending FILE_MD5 metadata with payloadId: $payloadId...")
            sendText(endpointId, "FILE_MD5:$filename:$md5:$payloadId")
            
            writeLog("Sending file payload with ID: $payloadId...")
            Nearby.getConnectionsClient(this)
                .sendPayload(endpointId, filePayload)
                .addOnSuccessListener {
                    writeLog("File payload ($filename) successfully queued with ID: $payloadId")
                }
                .addOnFailureListener { e ->
                    writeLog("Failed to send file payload: ${e.message}")
                    sendText(endpointId, "ERROR:Failed to send file")
                }
        } catch (e: Exception) {
            writeLog("Exception sending file: ${e.message}")
            sendText(endpointId, "ERROR:Exception occurred")
        }
    }

    private fun sendText(endpointId: String, text: String) {
        val bytes = text.toByteArray(Charsets.UTF_8)
        Nearby.getConnectionsClient(this).sendPayload(endpointId, Payload.fromBytes(bytes))
    }

    private fun getMd5OfFile(file: File): String {
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Watch Sync Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HealthPort Sync")
            .setContentText("기기 연동 대기 중...")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .build()
    }
}
