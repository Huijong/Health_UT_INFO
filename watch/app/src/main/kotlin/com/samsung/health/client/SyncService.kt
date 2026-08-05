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
import org.json.JSONArray
import org.json.JSONObject
import java.io.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class SyncService : Service() {

    companion object {
        private const val TAG = "HP_SyncService"
        private const val CHANNEL_ID = "WatchSyncServiceChannel"
        private const val TCP_PORT = 8888
        private const val UDP_PORT = 8889
        private const val BUFFER_SIZE = 1024 * 1024

        @Volatile
        var isRunning = false
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    // TCP Socket
    private var tcpSocket: Socket? = null
    private var socketWriter: BufferedWriter? = null
    private var socketReader: BufferedReader? = null
    private var isSocketRunning = false

    // Service state
    private var isServiceActive = false

    // UDP Listener
    private var udpListenerThread: Thread? = null
    private var udpStarted = false

    // Direct Connect Thread for Hotspot
    private var directConnectThread: Thread? = null

    // Active Wi-Fi Network for binding
    private var activeWifiNetwork: Network? = null
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // Auto Wifi Join System Callback
    private var autoJoinCallback: ConnectivityManager.NetworkCallback? = null

    // ────────────────────────────────────────────────────────────────
    // LIFECYCLE
    // ────────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        acquireLocks()

        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(1, createNotification(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(1, createNotification())
            }
            writeLog("Foreground service started successfully.")
        } catch (e: Exception) {
            writeLog("Foreground start error: ${e.message}")
            try { startForeground(1, createNotification()) } catch (_: Exception) {}
        }

        isServiceActive = true
        ensureWifiEnabled()

        // Request Physical Wi-Fi Network directly (without internet requirement for offline hotspot compatibility)
        requestPhysicalWifiNetwork()

        // Start UDP listener immediately
        startUdpBeaconListener()

        // Start Direct Connect fallback
        startDirectConnectFallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && intent.action == "ACTION_TRIGGER_WIFI_JOIN") {
            writeLog("Received Intent command: ACTION_TRIGGER_WIFI_JOIN. Scheduling Wi-Fi join in 1.5s...")
            mainHandler.postDelayed({
                triggerWifiNetworkSpecifier(intent.getStringExtra("ssid") ?: "healthport", intent.getStringExtra("pwd") ?: "12345678")
            }, 1500)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        writeLog("Destroying SyncService. Releasing resources...")
        isRunning = false
        isServiceActive = false
        mainHandler.removeCallbacksAndMessages(null)
        stopTcpClient()
        releaseWifiNetworkRequest()
        releaseAutoJoinRequest()
        releaseLocks()
        super.onDestroy()
    }

    // ────────────────────────────────────────────────────────────────
    // WIFI NETWORK SPECIFIER (AUTO JOIN GALAXY WATCH WI-FI)
    // ────────────────────────────────────────────────────────────────

    private fun triggerWifiNetworkSpecifier(ssid: String, pwd: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            writeLog("WifiNetworkSpecifier is not supported on Android version < 10")
            return
        }

        try {
            writeLog("Triggering WifiNetworkSpecifier for SSID '$ssid'...")
            ensureWifiEnabled()

            // Release any existing autojoin callback to prevent memory leak
            releaseAutoJoinRequest()

            // 1. Build Network Specifier targeting hotspot credentials
            val specifier = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(pwd)
                .build()

            // 2. Build Network Request
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .setNetworkSpecifier(specifier)
                .build()

            // 3. Register callback. Android OS will now display a Wear OS popup asking user to approve join
            autoJoinCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    writeLog("Successfully joined healthport hotspot network!")
                    activeWifiNetwork = network
                    connectivityManager?.bindProcessToNetwork(network)
                    
                    // Restart UDP search immediately since we are now on the hotspot
                    mainHandler.post {
                        startUdpBeaconListener()
                    }
                }

                override fun onUnavailable() {
                    super.onUnavailable()
                    writeLog("User denied joining healthport hotspot or network was not found.")
                }

                override fun onLost(network: Network) {
                    super.onLost(network)
                    writeLog("Connection to healthport lost.")
                }
            }

            autoJoinCallback?.let {
                connectivityManager?.requestNetwork(request, it)
                writeLog("OS confirmation dialog has been triggered. Please look at the Watch Screen.")
            }

        } catch (e: Exception) {
            writeLog("Failed to execute WifiNetworkSpecifier: ${e.message}")
        }
    }

    private fun releaseAutoJoinRequest() {
        try {
            autoJoinCallback?.let {
                connectivityManager?.unregisterNetworkCallback(it)
            }
            autoJoinCallback = null
        } catch (_: Exception) {}
    }

    // ────────────────────────────────────────────────────────────────
    // BIND PHYSICAL WI-FI NETWORK (BYPASS BLUETOOTH PROXY)
    // ────────────────────────────────────────────────────────────────

    private fun requestPhysicalWifiNetwork() {
        try {
            writeLog("Requesting physical Wi-Fi network link (offline ok) from OS...")
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .build()

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    writeLog("Physical Wi-Fi network available! Binding active socket link...")
                    activeWifiNetwork = network
                    connectivityManager?.bindProcessToNetwork(network)
                    // 기존에 엉뚱한 망(LTE 등)으로 연결된 가짜 소켓이 있다면 강제 종료하여 새 Wi-Fi 망으로 재접속 유도
                    stopTcpClient()
                }

                override fun onLost(network: Network) {
                    super.onLost(network)
                    writeLog("Physical Wi-Fi network lost.")
                    if (activeWifiNetwork == network) {
                        activeWifiNetwork = null
                        connectivityManager?.bindProcessToNetwork(null)
                    }
                }
            }

            networkCallback?.let {
                connectivityManager?.requestNetwork(request, it)
            }
        } catch (e: Exception) {
            writeLog("Failed to request Wi-Fi network: ${e.message}")
        }
    }

    private fun releaseWifiNetworkRequest() {
        try {
            networkCallback?.let {
                connectivityManager?.unregisterNetworkCallback(it)
            }
            connectivityManager?.bindProcessToNetwork(null)
            activeWifiNetwork = null
            writeLog("Wi-Fi network binding released.")
        } catch (_: Exception) {}
    }

    // ────────────────────────────────────────────────────────────────
    // LOCKS
    // ────────────────────────────────────────────────────────────────

    private fun acquireLocks() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "HealthPort:SyncWakeLock")
                .apply { acquire(10 * 60 * 1000L) }
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "HealthPort:SyncWifiLock")
                .apply { acquire() }
            writeLog("WakeLock and WifiLock acquired.")
        } catch (e: Exception) { Log.e(TAG, "Lock error: ${e.message}") }
    }

    private fun releaseLocks() {
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
            wifiLock?.let { if (it.isHeld) it.release() }
            writeLog("Locks released.")
        } catch (e: Exception) { Log.e(TAG, "Release lock error: ${e.message}") }
    }

    // ────────────────────────────────────────────────────────────────
    // WI-FI HARDWARE
    // ────────────────────────────────────────────────────────────────

    private fun ensureWifiEnabled() {
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (!wm.isWifiEnabled) {
                writeLog("Wi-Fi is OFF → turning ON...")
                @Suppress("DEPRECATION")
                wm.isWifiEnabled = true
            } else {
                writeLog("Wi-Fi hardware is already ON.")
            }
        } catch (e: Exception) { writeLog("Wi-Fi check error: ${e.message}") }
    }

    // ────────────────────────────────────────────────────────────────
    // UDP BEACON LISTENER
    // ────────────────────────────────────────────────────────────────

    private fun startUdpBeaconListener() {
        if (udpStarted || isSocketRunning) return
        udpStarted = true

        udpListenerThread = Thread {
            writeLog("Starting UDP Beacon Listener on port $UDP_PORT...")
            var ds: DatagramSocket? = null
            try {
                ds = DatagramSocket(null)
                ds.reuseAddress = true
                ds.soTimeout = 15000
                ds.bind(InetSocketAddress(UDP_PORT))

                val buf = ByteArray(1024)
                while (isServiceActive && !isSocketRunning) {
                    try {
                        val pkt = DatagramPacket(buf, buf.size)
                        ds.receive(pkt)
                        val msg = String(pkt.data, 0, pkt.length, Charsets.UTF_8)
                        writeLog("UDP Beacon received: $msg")
                        if (msg.startsWith("HEALTHPORT_SERVER:")) {
                            val parts = msg.split(":")
                            if (parts.size >= 3) {
                                val ip = parts[1]
                                val port = parts[2].toIntOrNull() ?: TCP_PORT
                                writeLog("Discovered Server at $ip:$port → Connecting TCP...")
                                startTcpClient(ip, port)
                                break
                            }
                        }
                    } catch (e: java.net.SocketTimeoutException) {
                        writeLog("UDP timeout - listening for beacon...")
                    }
                }
            } catch (e: Exception) {
                writeLog("UDP Beacon listener error: ${e.message}")
            } finally {
                try { ds?.close() } catch (_: Exception) {}
                udpStarted = false
            }
        }.apply { isDaemon = true; start() }
    }

    // ────────────────────────────────────────────────────────────────
    // DIRECT TCP CONNECT FALLBACK (FOR HOTSPOT & BT TETHERING)
    // ────────────────────────────────────────────────────────────────

    private fun startDirectConnectFallback() {
        if (directConnectThread?.isAlive == true) return
        directConnectThread = Thread {
            writeLog("Starting Direct Connection Fallback thread...")
            val fallbackIps = listOf("192.168.43.1", "192.168.44.1", "192.168.45.1", "192.168.1.1", "192.168.0.1")
            
            while (isServiceActive) {
                if (!isSocketRunning) {
                    val fallbackIps = mutableListOf<String>()
                    getWifiGatewayIp()?.let {
                        fallbackIps.add(it)
                    }
                    fallbackIps.addAll(listOf("192.168.43.1", "192.168.44.1", "192.168.45.1", "192.168.1.1", "192.168.0.1"))
                    val uniqueIps = fallbackIps.distinct()
                    
                    for (ip in uniqueIps) {
                        if (isSocketRunning) break
                        try {
                            val socket = Socket()
                            socket.receiveBufferSize = BUFFER_SIZE
                            socket.sendBufferSize = BUFFER_SIZE
                            
                            activeWifiNetwork?.let {
                                it.bindSocket(socket)
                            }
                            
                            writeLog("Attempting direct TCP connection to gateway: $ip:$TCP_PORT...")
                            socket.connect(InetSocketAddress(ip, TCP_PORT), 3000)
                            
                            writeLog("Direct connection success to $ip! Initiating synchronization client...")
                            tcpSocket = socket
                            isSocketRunning = true
                            
                            socketWriter = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                            socketReader = BufferedReader(InputStreamReader(BufferedInputStream(socket.getInputStream(), BUFFER_SIZE), Charsets.UTF_8))
                            
                            sendSocketLine("HELLO_FROM_WATCH")
                            
                            while (isSocketRunning) {
                                val line = socketReader?.readLine() ?: break
                                handleSocketCommand(line, socket.getInputStream())
                            }
                        } catch (e: Exception) {
                            // Silently ignore
                        } finally {
                            if (isSocketRunning) {
                                writeLog("Direct client session closed.")
                                stopTcpClient()
                            }
                        }
                    }
                }
                Thread.sleep(3000)
            }
        }.apply { isDaemon = true; start() }
    }

    // ────────────────────────────────────────────────────────────────
    // TCP CLIENT (UDP BEACON INITIATED)
    // ────────────────────────────────────────────────────────────────

    private fun startTcpClient(ip: String, port: Int) {
        if (isSocketRunning) return
        isSocketRunning = true
        Thread {
            try {
                writeLog("TCP connecting to $ip:$port...")
                val socket = Socket()
                socket.receiveBufferSize = BUFFER_SIZE
                socket.sendBufferSize = BUFFER_SIZE

                activeWifiNetwork?.let {
                    it.bindSocket(socket)
                }

                socket.connect(InetSocketAddress(ip, port), 15000)
                tcpSocket = socket
                writeLog("TCP connected to $ip:$port!")

                socketWriter = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                socketReader = BufferedReader(InputStreamReader(BufferedInputStream(socket.getInputStream(), BUFFER_SIZE), Charsets.UTF_8))

                sendSocketLine("HELLO_FROM_WATCH")

                while (isSocketRunning) {
                    val line = socketReader?.readLine() ?: break
                    handleSocketCommand(line, socket.getInputStream())
                }
            } catch (e: Exception) {
                writeLog("TCP error: ${e.message}")
            } finally {
                writeLog("TCP closed. Resetting socket state for retry...")
                stopTcpClient()
                // Do NOT call stopSelf() here — let directConnectFallback retry automatically.
            }
        }.apply { isDaemon = true; start() }
    }

    private fun stopTcpClient() {
        isSocketRunning = false
        try { socketWriter?.close() } catch (_: Exception) {}
        try { socketReader?.close() } catch (_: Exception) {}
        try { tcpSocket?.close() } catch (_: Exception) {}
        socketWriter = null; socketReader = null; tcpSocket = null
    }

    private fun sendSocketLine(text: String) {
        try { socketWriter?.run { write(text + "\n"); flush() } }
        catch (e: Exception) { writeLog("Socket write error: ${e.message}") }
    }

    private fun handleSocketCommand(command: String, inStream: InputStream) {
        writeLog("CMD: $command")
        when {
            command == "GET_FILE_LIST" -> {
                // Notify phone that compression is in progress
                sendSocketLine("COMPRESSING")
                // Compress any unzipped COLA folders into new naming format
                compressColaFiles()
                compressLogFiles()
                // Send the final file list
                sendSocketLine("FILE_LIST:${getFileListJson()}")
            }
            command.startsWith("DOWNLOAD_FILE:") -> {
                sendSocketFile(command.substring("DOWNLOAD_FILE:".length).trim())
            }
        }
    }

    // ────────────────────────────────────────────────────────────────
    // COLA FILE COMPRESSION
    // ────────────────────────────────────────────────────────────────

    /** Returns the watch firmware version string from Build.DISPLAY, safe for filenames. */
    private fun getWatchSoftwareVersion(): String {
        return Build.DISPLAY
            .replace("/", "_")
            .replace("\\", "_")
            .replace(" ", "_")
            .replace(":", "_")
    }

    /**
     * Parses a folder name in YYMMDDHHMM format (10 digits) into
     * a (YYYYMMDD, HHMMSS) pair suitable for the zip filename.
     * Falls back to current time if the name doesn't match.
     */
    private fun parseColaDateTime(name: String): Pair<String, String> {
        return if (name.length >= 10 && name.take(10).all { it.isDigit() }) {
            val yy  = name.substring(0, 2)
            val mon = name.substring(2, 4)
            val dd  = name.substring(4, 6)
            val hh  = name.substring(6, 8)
            val min = name.substring(8, 10)
            Pair("20${yy}${mon}${dd}", "${hh}${min}00")
        } else {
            val sdf = java.text.SimpleDateFormat("yyyyMMdd_HHmmss", java.util.Locale.US)
            val parts = sdf.format(java.util.Date()).split("_")
            Pair(parts[0], parts[1])
        }
    }

    /** Builds the zip output filename from the source folder name. */
    private fun buildColaZipName(folderName: String): String {
        val version = getWatchSoftwareVersion()
        val (dateStr, timeStr) = parseColaDateTime(folderName)
        return "COLA_FILE_${version}_${dateStr}_${timeStr}.zip"
    }

    private fun buildLogZipName(): String {
        val version = getWatchSoftwareVersion()
        val (dateStr, timeStr) = parseColaDateTime("ALL")
        return "log_${version}_${dateStr}_${timeStr}.zip"
    }

    private fun compressLogFiles() {
        val logFolder = File("/sdcard/log/")
        writeLog("COMPRESS: logFolder exists? ${logFolder.exists()}, isDir? ${logFolder.isDirectory}, canRead? ${logFolder.canRead()}")
        
        if (!logFolder.exists()) {
            writeLog("COMPRESS: /sdcard/log/ does not exist. Aborting log compression.")
            return
        }

        val targetFolder = File("/sdcard/Documents/COLA_FILE/")
        if (!targetFolder.exists()) { targetFolder.mkdirs() }

        val zipName = buildLogZipName()
        val zipFile = File(targetFolder, zipName)

        targetFolder.listFiles { _, n -> n.startsWith("log_") && n.endsWith(".zip") }?.forEach { f ->
            try { f.delete() } catch (_: Exception) {}
        }

        writeLog("COMPRESS: log folder → $zipName")
        try {
            ZipOutputStream(BufferedOutputStream(FileOutputStream(zipFile))).use { zos ->
                zos.setLevel(java.util.zip.Deflater.NO_COMPRESSION)
                addFolderToZip(logFolder, "log", zos)
            }
            writeLog("COMPRESS: done → $zipName")
        } catch (e: Exception) {
            writeLog("COMPRESS log error: ${e.message}")
            try { zipFile.delete() } catch (_: Exception) {}
        }
    }

    /**
     * Scans /sdcard/Documents/COLA_FILE/ for directories whose names
     * are 10-digit date-time strings (YYMMDDHHMM) and compresses each
     * one into COLA_FILE_[version]_[date]_[time].zip.
     * Already-compressed archives (COLA_FILE_*.zip) are skipped.
     */
    private fun compressColaFiles() {
        val folder = File("/sdcard/Documents/COLA_FILE/")
        if (!folder.exists()) { folder.mkdirs(); return }

        val colaPattern = Regex("^\\d{10}$")
        val targets = folder.listFiles { f ->
            f.isDirectory && colaPattern.matches(f.name)
        }?.sortedBy { it.name } ?: return

        if (targets.isEmpty()) {
            writeLog("COMPRESS: no unzipped COLA folders found.")
            return
        }

        val newestFolder = targets.last()
        val zipName = buildColaZipName(newestFolder.name)
        val zipFile = File(folder, zipName)

        if (zipFile.exists()) {
            writeLog("COMPRESS: $zipName already exists, skipping.")
            return
        }

        // Clean up old zip files before creating the new unified one
        folder.listFiles { _, n -> n.startsWith("COLA_FILE_") && n.endsWith(".zip") }?.forEach { f ->
            try { f.delete() } catch (_: Exception) {}
        }

        writeLog("COMPRESS: ${targets.size} folders → $zipName")
        try {
            ZipOutputStream(BufferedOutputStream(FileOutputStream(zipFile))).use { zos ->
                zos.setLevel(java.util.zip.Deflater.NO_COMPRESSION)
                for (dir in targets) {
                    addFolderToZip(dir, dir.name, zos)
                }
            }
            writeLog("COMPRESS: done → $zipName")
        } catch (e: Exception) {
            writeLog("COMPRESS error: ${e.message}")
            try { zipFile.delete() } catch (_: Exception) {}
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
        zos.putNextEntry(ZipEntry(entryName))
        FileInputStream(file).use { it.copyTo(zos, bufferSize = 65536) }
        zos.closeEntry()
    }

    private fun sendSocketFile(filename: String) {
        val file = File("/sdcard/Documents/COLA_FILE/", filename)
        if (!file.exists()) { sendSocketLine("ERROR:File not found"); return }
        try {
            val md5 = getMd5(file)
            val size = file.length()
            writeLog("Sending $filename ($size bytes) with 1MB Buffer...")
            sendSocketLine("FILE_START:$filename:$size:$md5")
            socketWriter?.flush()
            
            // 패킷 병합 방지: 폰의 BufferedReader가 파일 데이터까지 미리 읽어버리는 현상을 막기 위해 패킷 경계선(Delay) 형성
            Thread.sleep(200)
            
            val out = BufferedOutputStream(tcpSocket?.getOutputStream() ?: return, BUFFER_SIZE)
            FileInputStream(file).use { fis ->
                val buf = ByteArray(65536)
                var r: Int
                while (fis.read(buf).also { r = it } != -1) {
                    out.write(buf, 0, r)
                }
                out.flush()
            }
            writeLog("$filename sent successfully.")
        } catch (e: Exception) {
            writeLog("File send error: ${e.message}")
            sendSocketLine("ERROR:${e.message}")
        }
    }

    private fun getFileListJson(): String {
        val folder = File("/sdcard/Documents/COLA_FILE/")
        if (!folder.exists()) folder.mkdirs()
        val arr = JSONArray()
        folder.listFiles { _, n -> n.endsWith(".zip", true) }?.forEach { f ->
            arr.put(JSONObject().apply { put("name", f.name); put("size", f.length()); put("last_modified", f.lastModified()) })
        }
        return arr.toString()
    }

    // ────────────────────────────────────────────────────────────────
    // UTILITIES
    // ────────────────────────────────────────────────────────────────

    private fun getWifiGatewayIp(): String? {
        return try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val dhcp = wm.dhcpInfo
            val gateway = dhcp.gateway
            if (gateway != 0) {
                val ip = String.format(
                    java.util.Locale.US,
                    "%d.%d.%d.%d",
                    gateway and 0xff,
                    gateway shr 8 and 0xff,
                    gateway shr 16 and 0xff,
                    gateway shr 24 and 0xff
                )
                writeLog("DHCP detected Gateway IP: $ip")
                ip
            } else {
                null
            }
        } catch (e: Exception) {
            writeLog("Failed to read DHCP gateway: ${e.message}")
            null
        }
    }

    private fun getMd5(file: File): String {
        val d = MessageDigest.getInstance("MD5")
        FileInputStream(file).use { fis ->
            val b = ByteArray(32768)
            var r: Int
            while (fis.read(b).also { r = it } > 0) d.update(b, 0, r)
        }
        return java.math.BigInteger(1, d.digest()).toString(16).padStart(32, '0')
    }

    fun writeLog(msg: String) {
        Log.d(TAG, msg)
        try {
            val folder = File("/sdcard/Documents/COLA_FILE/")
            if (!folder.exists()) folder.mkdirs()
            val ts = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            File(folder, "sync_log.txt").appendText("[$ts] $msg\n")
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Watch Sync", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(NotificationManager::class.java))?.createNotificationChannel(ch)
        }
    }

    private fun createNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HealthPort Sync")
            .setContentText("기기 연동 대기 중...")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .build()
}
