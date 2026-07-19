package com.samsung.health.client

import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val fileChannel = FileChannelPlugin { this }
    private val CHANNEL = "com.samsung.health.client/app_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fileChannel.register(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSamsungHealthVersion") {
                val version = getSamsungHealthVersion()
                result.success(version)
            } else if (call.method == "getAndroidId") {
                val androidId = android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID)
                result.success(androidId ?: "")
            } else {
                result.notImplemented()
            }
        }
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
