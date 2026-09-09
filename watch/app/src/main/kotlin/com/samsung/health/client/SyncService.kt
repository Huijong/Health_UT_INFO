package com.samsung.health.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import java.util.concurrent.Executors

class SyncService : Service() {
    companion object {
        private const val TAG = "HP_SyncService"
        private const val CHANNEL_ID = "WatchSyncServiceChannel"
        private const val SERVICE_ID = "com.samsung.health.sync"
        @Volatile var isRunning = false
    }

    private var isServiceActive = false
    private var wakeLock: PowerManager.WakeLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connectedEndpointId: String? = null

    override fun onCreate() {
        super.onCreate()
        isServiceActive = true
        isRunning = true
        createNotificationChannel()
        startForeground(1, buildNotification("Ready", "Waiting for command"))
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "ACTION_TRIGGER_WIFI_JOIN") {
            writeLog("Received Intent command. Starting Nearby Discovery...")
            startDiscovery()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isServiceActive = false
        isRunning = false
        stopDiscovery()
        connectedEndpointId?.let { Nearby.getConnectionsClient(this).disconnectFromEndpoint(it) }
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // -----------------------------------------------------------------------------------------
    // NEARBY CONNECTIONS LOGIC
    // -----------------------------------------------------------------------------------------
    private fun startDiscovery() {
        val options = DiscoveryOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build()
        Nearby.getConnectionsClient(this)
            .startDiscovery(SERVICE_ID, endpointDiscoveryCallback, options)
            .addOnSuccessListener { writeLog("Discovery started") }
            .addOnFailureListener { e -> writeLog("Discovery failed: ${e.message}") }
    }

    private fun stopDiscovery() {
        Nearby.getConnectionsClient(this).stopDiscovery()
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(epId: String, info: DiscoveredEndpointInfo) {
            writeLog("Found endpoint: ${info.endpointName} ($epId). Requesting connection...")
            Nearby.getConnectionsClient(this@SyncService)
                .requestConnection("Watch", epId, connLifecycleCallback)
                .addOnFailureListener { e -> writeLog("Request connection failed: ${e.message}") }
        }
        override fun onEndpointLost(epId: String) {
            writeLog("Lost endpoint: $epId")
        }
    }

    private val connLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(epId: String, info: ConnectionInfo) {
            writeLog("Connection initiated by ${info.endpointName}. Accepting...")
            Nearby.getConnectionsClient(this@SyncService).acceptConnection(epId, payloadCallback)
        }
        override fun onConnectionResult(epId: String, res: ConnectionResolution) {
            if (res.status.isSuccess) {
                writeLog("Connected to $epId")
                connectedEndpointId = epId
                stopDiscovery()
                sendCommand("HELLO_FROM_WATCH")
            } else {
                writeLog("Connection failed: ${res.status.statusCode}")
            }
        }
        override fun onDisconnected(epId: String) {
            writeLog("Disconnected from $epId")
            if (connectedEndpointId == epId) connectedEndpointId = null
        }
    }

    private fun sendCommand(cmd: String) {
        val ep = connectedEndpointId ?: return
        writeLog("Sending command: $cmd")
        Nearby.getConnectionsClient(this).sendPayload(ep, Payload.fromBytes(cmd.toByteArray(StandardCharsets.UTF_8)))
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(epId: String, p: Payload) {
            if (p.type == Payload.Type.BYTES) {
                val cmd = String(p.asBytes()!!, StandardCharsets.UTF_8)
                writeLog("Received cmd: $cmd")
                handleCommand(cmd)
            }
        }
        override fun onPayloadTransferUpdate(epId: String, upd: PayloadTransferUpdate) {
            if (upd.status == PayloadTransferUpdate.Status.SUCCESS) {
                if (currentTransferZip != null) {
                    currentTransferZip?.delete()
                    currentTransferZip = null
                    writeLog("Transfer SUCCESS. Temp zip deleted.")
                }
            } else if (upd.status == PayloadTransferUpdate.Status.FAILURE || upd.status == PayloadTransferUpdate.Status.CANCELED) {
                if (currentTransferZip != null) {
                    currentTransferZip?.delete()
                    currentTransferZip = null
                    writeLog("Transfer FAILED/CANCELED. Temp zip deleted.")
                }
            }
        }
    }

    private fun handleCommand(cmd: String) {
        when {
            cmd == "GET_FILE_LIST" -> sendFileList()
            cmd.startsWith("DOWNLOAD_FILE:") -> {
                val fn = cmd.substring("DOWNLOAD_FILE:".length)
                Executors.newSingleThreadExecutor().execute {
                    prepareAndSendFile(fn)
                }
            }
            cmd == "DELETE_WATCH_FILES" -> deleteLogFiles()
        }
    }

    // -----------------------------------------------------------------------------------------
    // FILE HANDLING LOGIC
    // -----------------------------------------------------------------------------------------
    private fun sendFileList() {
        try {
            val jsonArr = JSONArray()
            val logFolder = File("/sdcard/log/")
            if (logFolder.exists() && logFolder.isDirectory) {
                val obj = JSONObject()
                obj.put("name", "log_" + System.currentTimeMillis() + ".zip")
                obj.put("size", -1)
                obj.put("last_modified", System.currentTimeMillis())
                jsonArr.put(obj)
            }
            val colaFolder = File("/sdcard/cola/")
            if (colaFolder.exists() && colaFolder.isDirectory) {
                val obj = JSONObject()
                obj.put("name", "COLA_FILE_" + System.currentTimeMillis() + ".zip")
                obj.put("size", -1)
                obj.put("last_modified", System.currentTimeMillis())
                jsonArr.put(obj)
            }
            sendCommand("FILE_LIST:$jsonArr")
        } catch (e: Exception) {
            writeLog("Error creating file list: ${e.message}")
        }
    }

    private var currentTransferZip: File? = null

    private fun prepareAndSendFile(filename: String) {
        val targets = mutableListOf<File>()
        if (filename.startsWith("log_")) {
            targets.add(File("/sdcard/log/"))
        } else if (filename.startsWith("COLA_FILE_")) {
            targets.add(File("/sdcard/cola/"))
        }
        
        if (targets.isEmpty()) return

        val zipFile = File(cacheDir, filename)
        currentTransferZip = zipFile
        try {
            writeLog("Compressing ${targets.size} folders to ${zipFile.absolutePath}...")
            ZipOutputStream(FileOutputStream(zipFile)).use { zos ->
                zos.setLevel(java.util.zip.Deflater.BEST_SPEED)
                for (target in targets) {
                    if (target.exists()) addFolderToZip(target, target.name, zos)
                }
            }
            writeLog("Compression done. Size: ${zipFile.length()} bytes. Starting Payload transfer...")
            sendCommand("FILE_START:$filename")
            val ep = connectedEndpointId
            if (ep != null) {
                Nearby.getConnectionsClient(this).sendPayload(ep, Payload.fromFile(zipFile))
            }
        } catch (e: Exception) {
            writeLog("Error compressing/sending: ${e.message}")
            zipFile.delete()
        }
    }

    private fun addFolderToZip(folder: File, parentPath: String, zos: ZipOutputStream) {
        val children = folder.listFiles() ?: return
        for (child in children) {
            if (child.isDirectory) {
                addFolderToZip(child, "$parentPath/${child.name}", zos)
            } else {
                addFileToZip(child, "$parentPath/${child.name}", zos)
            }
        }
    }

    private fun addFileToZip(file: File, entryName: String, zos: ZipOutputStream) {
        try {
            zos.putNextEntry(ZipEntry(entryName))
            FileInputStream(file).use { input ->
                val buffer = ByteArray(65536)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } >= 0) {
                    zos.write(buffer, 0, bytesRead)
                }
            }
            zos.closeEntry()
        } catch (e: Exception) {
            writeLog("Skip zip ${file.name}: ${e.message}")
        }
    }

    private fun deleteLogFiles() {
        try {
            File("/sdcard/log/").deleteRecursively()
            File("/sdcard/cola/").deleteRecursively()
            writeLog("Log files deleted")
        } catch (e: Exception) {
            writeLog("Failed to delete log files: ${e.message}")
        }
    }

    // -----------------------------------------------------------------------------------------
    // UTILITIES
    // -----------------------------------------------------------------------------------------
    private fun writeLog(msg: String) {
        Log.d(TAG, msg)
        updateNotification("Sync", msg)
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "HealthClient::SyncWakeLock")
        wakeLock?.acquire(30 * 60 * 1000L /*30 minutes*/)
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "Watch Sync Service", NotificationManager.IMPORTANCE_LOW)
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, content: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .build()
    }

    private fun updateNotification(title: String, content: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(1, buildNotification(title, content))
    }
}
