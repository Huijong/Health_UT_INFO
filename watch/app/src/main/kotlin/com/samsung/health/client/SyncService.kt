package com.samsung.health.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
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
import java.net.Socket
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
    private var wifiLock: WifiManager.WifiLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connectedEndpointId: String? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var wifiJoinRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        isServiceActive = true
        isRunning = true
        createNotificationChannel()
        startForeground(1, buildNotification("Ready", "Waiting for command"))
        acquireLocks()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "ACTION_TRIGGER_WIFI_JOIN") {
            val ssid = intent.getStringExtra("ssid") ?: "healthport"
            val pwd = intent.getStringExtra("pwd") ?: "12345678"
            writeLog("Received Wake-Up Command. Starting Wi-Fi join in 1.5s...")
            
            wifiJoinRunnable?.let { mainHandler.removeCallbacks(it) }
            wifiJoinRunnable = Runnable { connectToWifi(ssid, pwd) }
            mainHandler.postDelayed(wifiJoinRunnable!!, 1500)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isServiceActive = false
        isRunning = false
        stopDiscovery()
        connectedEndpointId?.let { Nearby.getConnectionsClient(this).disconnectFromEndpoint(it) }
        releaseLocks()
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
                writeLog("Connected to $epId.")
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
        override fun onPayloadTransferUpdate(epId: String, upd: PayloadTransferUpdate) {}
    }

    private fun handleCommand(cmd: String) {
        when {
            cmd.startsWith("WAKE_UP:") -> {
                val parts = cmd.split(":", limit = 3)
                if (parts.size >= 3) {
                    val ssid = parts[1]
                    val pwd = parts[2]
                    connectToWifi(ssid, pwd)
                }
            }
            cmd == "GET_FILE_LIST" -> sendFileList()
            cmd.startsWith("TCP_READY:") -> {
                // Format: TCP_READY:ip:port:filename
                val parts = cmd.split(":")
                if (parts.size >= 4) {
                    val ip = parts[1]
                    val port = parts[2].toIntOrNull() ?: 34567
                    val filename = cmd.substring("TCP_READY:$ip:$port:".length)
                    Executors.newSingleThreadExecutor().execute {
                        prepareAndSendFileViaTcp(ip, port, filename)
                    }
                }
            }
            cmd == "DELETE_WATCH_FILES" -> deleteLogFiles()
        }
    }

    // -----------------------------------------------------------------------------------------
    // FILE HANDLING & RAW TCP LOGIC
    // -----------------------------------------------------------------------------------------
    private fun sendFileList() {
        try {
            val jsonArr = JSONArray()
            val logFolder = File("/sdcard/log/")
            if (logFolder.exists() && logFolder.isDirectory) {
                val obj = JSONObject()
                val ts = logFolder.lastModified()
                obj.put("name", "log_$ts.zip")
                obj.put("size", -1)
                obj.put("last_modified", ts)
                jsonArr.put(obj)
            }
            val colaFolder = File("/sdcard/Documents/COLA_FILE/")
            var hasColaData = false
            writeLog("Checking COLA folder: ${colaFolder.absolutePath}, exists: ${colaFolder.exists()}, isDir: ${colaFolder.isDirectory}")
            if (colaFolder.exists() && colaFolder.isDirectory) {
                val colaPattern = Regex("^\\d{10}$")
                val children = colaFolder.listFiles()
                writeLog("COLA folder children count: ${children?.size}")
                if (children != null) {
                    for (f in children) {
                        writeLog("COLA child: ${f.name}, isDir: ${f.isDirectory}, matches: ${colaPattern.matches(f.name)}")
                        if (f.isDirectory && colaPattern.matches(f.name)) {
                            hasColaData = true
                            break
                        }
                    }
                }
            }
            writeLog("hasColaData final result: $hasColaData")
            if (hasColaData) {
                val obj = JSONObject()
                val ts = colaFolder.lastModified()
                obj.put("name", "COLA_FILE_$ts.zip")
                obj.put("size", -1)
                obj.put("last_modified", ts)
                jsonArr.put(obj)
            }
            sendCommand("FILE_LIST:$jsonArr")
        } catch (e: Exception) {
            writeLog("Error creating file list: ${e.message}")
        }
    }

    private fun prepareAndSendFileViaTcp(ip: String, port: Int, filename: String) {
        val targets = mutableListOf<File>()
        if (filename.startsWith("log_")) {
            targets.add(File("/sdcard/log/"))
        } else if (filename.startsWith("COLA_FILE_")) {
            val colaFolder = File("/sdcard/Documents/COLA_FILE/")
            val colaPattern = Regex("^\\d{10}$")
            colaFolder.listFiles()?.forEach { f ->
                if (f.isDirectory && colaPattern.matches(f.name)) {
                    targets.add(f)
                }
            }
        }
        
        if (targets.isEmpty()) return

        val zipFile = File(cacheDir, filename)
        try {
            sendCommand("PREPARING_FILE")
            writeLog("Compressing ${targets.size} folders to ${zipFile.absolutePath}...")
            ZipOutputStream(FileOutputStream(zipFile)).use { zos ->
                zos.setLevel(java.util.zip.Deflater.BEST_SPEED)
                for (target in targets) {
                    if (target.exists()) addFolderToZip(target, target.name, zos)
                }
            }
            writeLog("Compression done. Size: ${zipFile.length()} bytes. Connecting to Phone TCP $ip:$port...")
            
            val socket = Socket(ip, port)
            socket.sendBufferSize = 1048576 // 1MB
            val outputStream = socket.getOutputStream()
            
            writeLog("TCP Connected! Sending file size header...")
            val dataOut = java.io.DataOutputStream(outputStream)
            dataOut.writeLong(zipFile.length())
            dataOut.flush()
            
            writeLog("Streaming file...")
            java.io.FileInputStream(zipFile).use { input ->
                val buffer = ByteArray(1048576) // 1MB chunks
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } >= 0) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                outputStream.flush()
            }
            socket.close()
            writeLog("TCP Transfer complete! Deleting temp zip...")
            zipFile.delete()
            
        } catch (e: Exception) {
            writeLog("TCP/Compression error: ${e.message}")
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
            File("/sdcard/Documents/COLA_FILE/").deleteRecursively()
            writeLog("Log and COLA files deleted")
            sendCommand("DELETE_WATCH_FILES_OK")
        } catch (e: Exception) {
            writeLog("Failed to delete log files: ${e.message}")
            sendCommand("DELETE_WATCH_FILES_OK") // Prevent UI from freezing
        }
    }

    // -----------------------------------------------------------------------------------------
    // UTILITIES
    // -----------------------------------------------------------------------------------------
    private fun writeLog(msg: String) {
        Log.d(TAG, msg)
        updateNotification("Sync", msg)
        try {
            val logFile = java.io.File(android.os.Environment.getExternalStorageDirectory(), "Documents/COLA_FILE/watch_debug.log")
            logFile.parentFile?.mkdirs()
            logFile.appendText("${System.currentTimeMillis()}: $msg\n")
        } catch (e: Exception) {}
    }

    private fun acquireLocks() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "HealthClient::SyncWakeLock")
        wakeLock?.acquire(30 * 60 * 1000L /*30 minutes*/)
        
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "HealthClient::SyncWifiLock")
        wifiLock?.acquire()
    }

    private fun releaseLocks() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        if (wifiLock?.isHeld == true) wifiLock?.release()
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            networkCallback?.let { cm.unregisterNetworkCallback(it) }
            cm.bindProcessToNetwork(null)
        } catch (e: Exception) {}
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

    private fun connectToWifi(ssid: String, pwd: String) {
        try {
            val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            networkCallback?.let { 
                try { cm.unregisterNetworkCallback(it) } catch (e: Exception) {} 
            }
            networkCallback = null

            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (!wm.isWifiEnabled) {
                @Suppress("DEPRECATION")
                wm.isWifiEnabled = true
            }

            writeLog("Attempting to connect to Wi-Fi SSID: $ssid")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val specifier = WifiNetworkSpecifier.Builder()
                    .setSsid(ssid)
                    .setWpa2Passphrase(pwd)
                    .build()
                
                val request = NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .setNetworkSpecifier(specifier)
                    .build()

                val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                networkCallback = object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        super.onAvailable(network)
                        writeLog("Wi-Fi network available! Binding process...")
                        cm.bindProcessToNetwork(network)
                        writeLog("Starting Nearby Discovery now that Wi-Fi is connected...")
                        mainHandler.post { startDiscovery() }
                    }
                    override fun onLost(network: Network) {
                        super.onLost(network)
                        writeLog("Wi-Fi network lost.")
                        cm.bindProcessToNetwork(null)
                    }
                }
                cm.requestNetwork(request, networkCallback!!)
                writeLog("Requested network via WifiNetworkSpecifier")
            } else {
                @Suppress("DEPRECATION")
                val wifiConfig = android.net.wifi.WifiConfiguration().apply {
                    this.SSID = "\"$ssid\""
                    this.preSharedKey = "\"$pwd\""
                }
                
                @Suppress("DEPRECATION")
                val netId = wm.addNetwork(wifiConfig)
                if (netId != -1) {
                    @Suppress("DEPRECATION")
                    wm.disconnect()
                    @Suppress("DEPRECATION")
                    wm.enableNetwork(netId, true)
                    @Suppress("DEPRECATION")
                    wm.reconnect()
                    writeLog("Wi-Fi addNetwork triggered for netId: $netId")
                } else {
                    writeLog("addNetwork returned -1, API 29+ device fallback?")
                }
                mainHandler.postDelayed({
                    writeLog("Starting Nearby Discovery after fallback addNetwork...")
                    startDiscovery()
                }, 3000)
            }
        } catch (e: Exception) {
            writeLog("Wi-Fi connection error: ${e.message}")
        }
    }
}
