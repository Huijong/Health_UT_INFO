package com.samsung.health.client

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.CapabilityClient
import androidx.wear.remote.interactions.RemoteActivityHelper

class MainActivity : FlutterActivity() {

    private val fileChannel = FileChannelPlugin { this }
    private val wifiP2pPlugin by lazy { WifiP2pPlugin(this) }
    private val CHANNEL = "com.samsung.health.client/app_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fileChannel.register(flutterEngine)
        wifiP2pPlugin.register(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSamsungHealthVersion" -> {
                    val version = getSamsungHealthVersion()
                    result.success(version)
                }
                "getAndroidId" -> {
                    val androidId = android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID)
                    result.success(androidId ?: "")
                }
                "checkWatchAppInstalled" -> {
                    checkWatchAppInstalled(result)
                }
                "launchWatchPlayStore" -> {
                    launchWatchPlayStore(result)
                }
                "requestNearbyPermissions" -> {
                    requestNearbyPermissions(result)
                }
                "openHotspotSettings" -> {
                    openHotspotSettings(result)
                }
                "openSysDump" -> {
                    openSysDump(result)
                }
                "requestWatchWifiJoin" -> {
                    requestWatchWifiJoin(result)
                }
                "openWatchSysDump" -> {
                    openWatchSysDump(result)
                }
                "launchSamsungBrowser" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        launchSamsungBrowser(url, result)
                    } else {
                        result.error("BAD_ARGS", "URL is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openSysDump(result: MethodChannel.Result) {
        try {
            // 1. Target Samsung Dialer specifically
            val intent = Intent(Intent.ACTION_DIAL)
            intent.setClassName("com.samsung.android.dialer", "com.samsung.android.dialer.DialtactsActivity")
            intent.data = Uri.parse("tel:*%239900%23")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success("DIRECT")
        } catch (e: Exception) {
            // 2. Fallback to default dialer if Samsung dialer package name differs
            try {
                val dialIntent = Intent(Intent.ACTION_DIAL)
                dialIntent.data = Uri.parse("tel:*%239900%23")
                dialIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(dialIntent)
                result.success("FALLBACK")
            } catch (ex: Exception) {
                result.error("INTENT_ERROR", ex.message, null)
            }
        }
    }

    private fun openHotspotSettings(result: MethodChannel.Result) {
        try {
            // 1. Target Samsung specific Mobile AP Settings Activity
            val intent = Intent()
            intent.setClassName("com.android.settings", "com.samsung.settings.wifi.mobileap.WifiApSettings")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            try {
                // 2. Fallback to standard Tether Settings
                val intent = Intent()
                intent.setClassName("com.android.settings", "com.android.settings.Settings\$TetherSettingsActivity")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(true)
            } catch (ex: Exception) {
                try {
                    // 3. Fallback to wireless settings
                    val intent = Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                } catch (exc: Exception) {
                    result.error("INTENT_ERROR", exc.message, null)
                }
            }
        }
    }

    private fun requestNearbyPermissions(result: MethodChannel.Result) {
        val permissions = mutableListOf<String>()
        
        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val missing = permissions.filter {
                checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
            }

            if (missing.isNotEmpty()) {
                requestPermissions(missing.toTypedArray(), 200)
                result.success(false)
            } else {
                result.success(true)
            }
        } else {
            result.success(true)
        }
    }

    private fun checkWatchAppInstalled(result: MethodChannel.Result) {
        val context = this
        Thread {
            try {
                val capabilityInfo = Tasks.await(
                    Wearable.getCapabilityClient(context)
                        .getCapability("watch_file_sync", CapabilityClient.FILTER_REACHABLE)
                )
                val isInstalled = capabilityInfo.nodes.isNotEmpty()
                runOnUiThread { result.success(isInstalled) }
            } catch (e: Exception) {
                runOnUiThread { result.success(false) } // Fallback to false on error (e.g. Google Play Services not available)
            }
        }.start()
    }

    private fun launchWatchPlayStore(result: MethodChannel.Result) {
        val context = this
        Thread {
            try {
                val nodeClient = Wearable.getNodeClient(context)
                val nodes = Tasks.await(nodeClient.connectedNodes)
                if (nodes.isEmpty()) {
                    runOnUiThread { result.error("NO_NODES", "연결된 Wear OS 기기가 없습니다.", null) }
                    return@Thread
                }
                
                val remoteActivityHelper = RemoteActivityHelper(context)
                
                // Open Play Store details on the watch for the watch application package
                val intent = Intent(Intent.ACTION_VIEW)
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                    .setData(Uri.parse("market://details?id=com.samsung.health.client.watch"))
                
                for (node in nodes) {
                    remoteActivityHelper.startRemoteActivity(intent, node.id)
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("REMOTE_INTENT_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun getSamsungHealthVersion(): String {
        return try {
            val pInfo = packageManager.getPackageInfo("com.sec.android.app.shealth", 0)
            pInfo.versionName ?: "알 수 없음"
        } catch (e: PackageManager.NameNotFoundException) {
            "미설치"
        } catch (e: Exception) {
            "오류: ${e.message}"
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!fileChannel.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
    private fun writeClientLog(msg: String) {
        android.util.Log.d("HP_ClientMain", msg)
        try {
            val folder = java.io.File("/sdcard/Documents/COLA_FILE/")
            if (!folder.exists()) folder.mkdirs()
            val ts = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            java.io.File(folder, "client_sync_log.txt").appendText("[$ts] $msg\n")
        } catch (_: Exception) {}
    }

    private fun requestWatchWifiJoin(result: MethodChannel.Result) {
        val context = this
        writeClientLog("Initiating watch WiFi join request from Phone...")
        Thread {
            try {
                val nodeClient = Wearable.getNodeClient(context)
                val nodes = Tasks.await(nodeClient.connectedNodes)
                if (nodes.isEmpty()) {
                    writeClientLog("[FAIL] No connected Galaxy Watch nodes found over Bluetooth.")
                    runOnUiThread { result.success(false) }
                    return@Thread
                }
                
                writeClientLog("Found ${nodes.size} paired nodes. Sending WiFi join request...")
                val messageClient = Wearable.getMessageClient(context)
                var sentCount = 0
                for (node in nodes) {
                    writeClientLog("Sending to Node: ${node.displayName} (ID: ${node.id})")
                    // Send message path "/request_wifi_join"
                    Tasks.await(messageClient.sendMessage(node.id, "/request_wifi_join", ByteArray(0)))
                    writeClientLog("Message successfully dispatched to Node: ${node.displayName}")
                    sentCount++
                }
                runOnUiThread { result.success(sentCount > 0) }
            } catch (e: Exception) {
                writeClientLog("[ERROR] Failed to send message: ${e.message}")
                runOnUiThread { result.error("WEARABLE_MSG_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun openWatchSysDump(result: MethodChannel.Result) {
        val context = this
        writeClientLog("[SysDump] Command requested from Phone UI...")
        Thread {
            try {
                val nodeClient = Wearable.getNodeClient(context)
                val nodes = Tasks.await(nodeClient.connectedNodes)
                if (nodes.isEmpty()) {
                    writeClientLog("[SysDump][FAIL] No Bluetooth connected Watch nodes found.")
                    runOnUiThread { result.success(false) }
                    return@Thread
                }

                writeClientLog("[SysDump] Found ${nodes.size} connected watch nodes. Broadcasting command...")
                val messageClient = Wearable.getMessageClient(context)
                var sentCount = 0
                for (node in nodes) {
                    writeClientLog("[SysDump] Sending /open_watch_sysdump message to Node: ${node.displayName} (ID: ${node.id})")
                    val taskResult = messageClient.sendMessage(node.id, "/open_watch_sysdump", ByteArray(0))
                    Tasks.await(taskResult)
                    writeClientLog("[SysDump] Message dispatched successfully to Node: ${node.displayName}")
                    sentCount++
                }
                writeClientLog("[SysDump][SUCCESS] Dispatched to total $sentCount watch nodes.")
                runOnUiThread { result.success(sentCount > 0) }
            } catch (e: Exception) {
                val sw = java.io.StringWriter()
                e.printStackTrace(java.io.PrintWriter(sw))
                writeClientLog("[SysDump][ERROR] Failed to dispatch Wearable Message. StackTrace:\n$sw")
                runOnUiThread { result.error("WEARABLE_MSG_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun launchSamsungBrowser(url: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.setPackage("com.sec.android.app.sbrowser")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success("SAMSUNG_BROWSER")
        } catch (e: Exception) {
            // Fallback to system default browser if Samsung Internet is not installed
            try {
                val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(fallbackIntent)
                result.success("DEFAULT_BROWSER")
            } catch (ex: Exception) {
                result.error("LAUNCH_ERROR", ex.message, null)
            }
        }
    }
}
