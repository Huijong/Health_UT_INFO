package com.samsung.health.client

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import java.io.File

class MainActivity : Activity(), MessageClient.OnMessageReceivedListener {

    private lateinit var statusText: TextView
    private lateinit var actionButton: Button
    private var isServiceRunning = false
    private var wifiJoinPending = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Simple UI Layout
        // ScrollView wrapper to support circular screens perfectly
        // FrameLayout: fills screen so child can be CENTER-gravity
        val rootFrame = android.widget.FrameLayout(this).apply {
            setBackgroundColor(android.graphics.Color.BLACK)
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val rootLayout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setPadding(24, 0, 24, 0)
            layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.view.Gravity.CENTER
            )
        }

        statusText = TextView(this).apply {
            text = "HealthPort Sync\n대기 중"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 14f
            gravity = android.view.Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        rootLayout.addView(statusText)

        val spacer = android.view.View(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(1, 16)
        }
        rootLayout.addView(spacer)

        actionButton = Button(this).apply {
            text = "연동 시작"
            textSize = 13f
            setBackgroundColor(android.graphics.Color.parseColor("#2E5BFF"))
            setTextColor(android.graphics.Color.WHITE)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                120
            ).apply {
                gravity = android.view.Gravity.CENTER
                leftMargin = 16
                rightMargin = 16
            }
        }
        rootLayout.addView(actionButton)

        rootFrame.addView(rootLayout)
        setContentView(rootFrame)

        actionButton.setOnClickListener {
            if (isServiceRunning) {
                stopSyncService()
            } else {
                checkPermissionsAndStart()
            }
        }

        // Initialize documents folder
        val folder = File("/sdcard/Documents/COLA_FILE/")
        if (!folder.exists()) {
            folder.mkdirs()
        }

        // Register Wearable Message Listener
        Wearable.getMessageClient(this).addListener(this)

        // Process startup intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent != null && intent.action == "ACTION_TRIGGER_WIFI_JOIN") {
            wifiJoinPending = true
            isServiceRunning = SyncService.isRunning
            if (!isServiceRunning) {
                checkPermissionsAndStart()
            } else {
                sendWifiJoinToService()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        checkAndUpdateServiceState()
    }

    override fun onDestroy() {
        // Unregister Wearable Message Listener
        Wearable.getMessageClient(this).removeListener(this)
        super.onDestroy()
    }

    // ────────────────────────────────────────────────────────────────
    // WEARABLE MESSAGE LISTENER
    // ────────────────────────────────────────────────────────────────

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == "/request_wifi_join") {
            runOnUiThread {
                Toast.makeText(this, "WiFi 자동 연결 수신", Toast.LENGTH_SHORT).show()
                // 액티비티가 포그라운드에 있을 때 직접 서비스에 와이파이 조인 요청
                wifiJoinPending = true
                isServiceRunning = SyncService.isRunning
                if (!isServiceRunning) {
                    checkPermissionsAndStart()
                } else {
                    sendWifiJoinToService()
                }
            }
        }
    }

    private fun sendWifiJoinToService() {
        val serviceIntent = Intent(this, SyncService::class.java).apply {
                action = "ACTION_TRIGGER_WIFI_JOIN"
                intent?.extras?.let { putExtras(it) }
            }
        // 서비스가 이미 실행 중이므로, startForegroundService 대신 startService를 호출하여
        // ForegroundService 시작 후 5초 내 startForeground 미호출로 인한 강제 종료(Crash)를 방지합니다.
        startService(serviceIntent)
        wifiJoinPending = false
    }

    private fun checkAndUpdateServiceState() {
        isServiceRunning = SyncService.isRunning
        if (isServiceRunning) {
            statusText.text = "HealthPort Sync\n작동 중..."
            actionButton.text = "연동 종료"
            actionButton.setBackgroundColor(android.graphics.Color.parseColor("#FF5252"))
        } else {
            statusText.text = "HealthPort Sync\n대기 중"
            actionButton.text = "연동 시작"
            actionButton.setBackgroundColor(android.graphics.Color.parseColor("#2E5BFF"))
        }
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        @Suppress("DEPRECATION")
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun checkPermissionsAndStart() {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val missingPermissions = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missingPermissions.toTypedArray(), 101)
        } else {
            checkManageExternalStorageAndStart()
        }
    }

    private fun checkManageExternalStorageAndStart() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                AlertDialog.Builder(this)
                    .setTitle("파일 접근 권한")
                    .setMessage("설정 창이 열리면 [권한] -> [파일 및 미디어] 항목을 '항상 허용'으로 변경해주세요.")
                    .setPositiveButton("확인") { _, _ ->
                        launchStorageSettings()
                    }
                    .setNegativeButton("취소", null)
                    .show()
                return
            }
        }
        startSyncService()
    }

    private fun launchStorageSettings() {
        try {
            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
            intent.data = Uri.parse("package:$packageName")
            startActivityForResult(intent, 102)
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivityForResult(intent, 102)
            } catch (e2: Exception) {
                Toast.makeText(this, "설정 화면을 열 수 없습니다.", Toast.LENGTH_LONG).show()
                startSyncService()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == 101) {
            val denied = permissions.filterIndexed { index, _ -> 
                index < grantResults.size && grantResults[index] != PackageManager.PERMISSION_GRANTED 
            }
            if (denied.isEmpty() && grantResults.isNotEmpty()) {
                checkManageExternalStorageAndStart()
            } else {
                Toast.makeText(this, "거부된 권한:\n${denied.joinToString("\n") { it.substringAfterLast(".") }}", Toast.LENGTH_LONG).show()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 102) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (Environment.isExternalStorageManager()) {
                    startSyncService()
                } else {
                    Toast.makeText(this, "모든 파일 접근 권한이 필요합니다.", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun startSyncService() {
        val serviceIntent = Intent(this, SyncService::class.java).apply {
            if (wifiJoinPending) {
                action = "ACTION_TRIGGER_WIFI_JOIN"
                intent?.extras?.let { putExtras(it) }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        wifiJoinPending = false
        isServiceRunning = true
        statusText.text = "HealthPort Sync\n작동 중..."
        actionButton.text = "연동 종료"
        actionButton.setBackgroundColor(android.graphics.Color.parseColor("#FF5252"))
    }

    private fun stopSyncService() {
        val intent = Intent(this, SyncService::class.java)
        stopService(intent)
        isServiceRunning = false
        statusText.text = "HealthPort Sync\n대기 중"
        actionButton.text = "연동 시작"
        actionButton.setBackgroundColor(android.graphics.Color.parseColor("#2E5BFF"))
    }
}
