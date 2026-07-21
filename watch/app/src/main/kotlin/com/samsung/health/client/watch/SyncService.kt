package com.samsung.health.client.watch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
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

class SyncService : Service() {

    companion object {
        private const val TAG = "HP_SyncService"
        private const val CHANNEL_ID = "WatchSyncServiceChannel"
        private const val UDP_BEACON_PORT = 8889
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    private var tcpSocket: Socket? = null
    private var socketWriter: BufferedWriter? = null
    private var socketReader: BufferedReader? = null
    private var isSocketRunning = false

    private var udpListenerThread: Thread? = null
    private var isServiceActive = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireLocks()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(1, createNotification(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(1, createNotification())
            }
            writeLog("Foreground service started successfully.")
        } catch (e: Exception) {
            writeLog("Failed to start foreground service: ${e.message}")
            try {
                startForeground(1, createNotification())
                writeLog("Foreground service started (legacy fallback).")
            } catch (ex: Exception) {
                writeLog("Fatal error starting foreground: ${ex.message}")
            }
        }

        isServiceActive = true
        ensureWifiEnabled()
        startUdpBeaconListener()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        writeLog("Destroying SyncService. Releasing resources...")
        isServiceActive = false
        stopTcpClient()
        releaseLocks()
        super.onDestroy()
    }

    private fun acquireLocks() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "HealthPort:SyncWakeLock").apply {
                acquire(10 * 60 * 1000L)
            }
            val wm = getApplicationContext().getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "HealthPort:SyncWifiLock").apply {
                acquire()
            }
            writeLog("WakeLock and WifiLock acquired.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire locks: ${e.message}")
        }
    }

    private fun releaseLocks() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
            wifiLock?.let {
                if (it.isHeld) it.release()
            }
            writeLog("Locks released.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release locks: ${e.message}")
        }
    }

    private fun ensureWifiEnabled() {
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (!wm.isWifiEnabled) {
                writeLog("Wi-Fi hardware is OFF. Turning ON Wi-Fi on Watch...")
                @Suppress("DEPRECATION")
                wm.isWifiEnabled = true
            } else {
                writeLog("Wi-Fi hardware is already ON.")
            }
        } catch (e: Exception) {
            writeLog("Error checking Wi-Fi hardware: ${e.message}")
        }
    }

    private fun startUdpBeaconListener() {
        udpListenerThread = Thread {
            writeLog("Starting UDP Beacon Listener on port $UDP_BEACON_PORT...")
            var datagramSocket: DatagramSocket? = null
            try {
                datagramSocket = DatagramSocket(UDP_BEACON_PORT)
                val buffer = ByteArray(1024)

                while (isServiceActive && !isSocketRunning) {
                    val packet = DatagramPacket(buffer, buffer.size)
                    datagramSocket.receive(packet)
                    val message = String(packet.data, 0, packet.length, Charsets.UTF_8)
                    writeLog("UDP Beacon received: $message")

                    if (message.startsWith("HEALTHPORT_SERVER:")) {
                        // Format: HEALTHPORT_SERVER:[ip]:[port]
                        val parts = message.split(":")
                        if (parts.size >= 3) {
                            val ip = parts[1]
                            val port = parts[2].toIntOrNull() ?: 8888
                            writeLog("Discovered HealthPort Server at $ip:$port. Connecting TCP...")
                            startTcpClient(ip, port)
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                writeLog("UDP Beacon listener error: ${e.message}")
            } finally {
                try {
                    datagramSocket?.close()
                } catch (e: Exception) {
                    // ignore
                }
            }
        }.apply { start() }
    }

    private fun startTcpClient(ip: String, port: Int) {
        if (isSocketRunning) return
        isSocketRunning = true
        Thread {
            try {
                writeLog("Connecting to TCP Server at $ip:$port...")
                val socket = Socket()
                socket.connect(InetSocketAddress(ip, port), 15000)
                tcpSocket = socket
                writeLog("TCP Connected to Server at $ip:$port!")

                socketWriter = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                socketReader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))

                sendSocketLine("HELLO_FROM_WATCH")

                while (isSocketRunning) {
                    val line = socketReader?.readLine() ?: break
                    writeLog("Socket command received: $line")
                    handleSocketCommand(line)
                }
            } catch (e: Exception) {
                writeLog("TCP Client error: ${e.message}")
            } finally {
                writeLog("TCP Client connection closed.")
                stopTcpClient()
                if (isServiceActive) {
                    // Restart UDP beacon listener if disconnected
                    startUdpBeaconListener()
                }
            }
        }.start()
    }

    private fun stopTcpClient() {
        isSocketRunning = false
        try {
            socketWriter?.close()
            socketReader?.close()
            tcpSocket?.close()
        } catch (e: Exception) {
            // ignore
        }
        socketWriter = null
        socketReader = null
        tcpSocket = null
    }

    private fun sendSocketLine(text: String) {
        try {
            socketWriter?.write(text + "\n")
            socketWriter?.flush()
        } catch (e: Exception) {
            writeLog("Failed to write to socket: ${e.message}")
        }
    }

    private fun handleSocketCommand(command: String) {
        when {
            command == "GET_FILE_LIST" -> {
                val fileListJson = getFileListJson()
                sendSocketLine("FILE_LIST:$fileListJson")
            }
            command.startsWith("DOWNLOAD_FILE:") -> {
                val filename = command.substring("DOWNLOAD_FILE:".length).trim()
                sendSocketFile(filename)
            }
        }
    }

    private fun sendSocketFile(filename: String) {
        val file = File("/sdcard/Documents/COLA_FILE/", filename)
        if (!file.exists()) {
            writeLog("Error: File not found - $filename")
            sendSocketLine("ERROR:File not found")
            return
        }

        try {
            writeLog("Computing MD5 for $filename...")
            val md5 = getMd5OfFile(file)
            val size = file.length()

            writeLog("Sending FILE_START header for $filename (Size: $size, MD5: $md5)...")
            sendSocketLine("FILE_START:$filename:$size:$md5")
            socketWriter?.flush()

            val outputStream = tcpSocket?.getOutputStream() ?: throw Exception("Output stream is null")
            val fileInputStream = FileInputStream(file)
            val buffer = ByteArray(16384)
            var bytesRead: Int
            var totalSent: Long = 0

            writeLog("Streaming bytes for $filename...")
            while (fileInputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
                totalSent += bytesRead
            }
            outputStream.flush()
            fileInputStream.close()
            writeLog("File $filename fully streamed over socket ($totalSent bytes).")
            sendSocketLine("FILE_END:$filename")
        } catch (e: Exception) {
            writeLog("Exception streaming file: ${e.message}")
            sendSocketLine("ERROR:Exception during file stream: ${e.message}")
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
            val folder = File("/sdcard/Documents/COLA_FILE/")
            if (!folder.exists()) folder.mkdirs()
            val logFile = File(folder, "sync_log.txt")
            logFile.appendText("[${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}] $message\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write log: ${e.message}")
        }
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
