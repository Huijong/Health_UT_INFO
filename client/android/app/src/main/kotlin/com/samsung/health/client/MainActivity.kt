package com.samsung.health.client

import android.Manifest
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
                else -> {
                    result.notImplemented()
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
}
