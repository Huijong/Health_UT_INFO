package com.samsung.health.client.watch

import android.Manifest
import android.app.Activity
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
import java.io.File

class MainActivity : Activity() {

    private lateinit var statusText: TextView
    private lateinit var actionButton: Button
    private var isServiceRunning = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Simple UI Layout
        val rootLayout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setPadding(16, 16, 16, 16)
            setBackgroundColor(android.graphics.Color.BLACK)
        }

        statusText = TextView(this).apply {
            text = "HealthPort Sync\n대기 중"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 14f
            gravity = android.view.Gravity.CENTER
        }
        rootLayout.addView(statusText)

        val spacer = android.view.View(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(1, 16)
        }
        rootLayout.addView(spacer)

        actionButton = Button(this).apply {
            text = "연동 시작"
            setBackgroundColor(android.graphics.Color.parseColor("#2E5BFF"))
            setTextColor(android.graphics.Color.WHITE)
        }
        rootLayout.addView(actionButton)

        setContentView(rootLayout)

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
    }

    override fun onResume() {
        super.onResume()
        checkAndUpdateServiceState()
    }

    private fun checkAndUpdateServiceState() {
        isServiceRunning = isServiceRunning(SyncService::class.java)
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
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }

        val missingPermissions = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missingPermissions.toTypedArray(), 101)
        } else {
            startSyncService()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == 101) {
            val denied = permissions.filterIndexed { index, _ -> 
                index < grantResults.size && grantResults[index] != PackageManager.PERMISSION_GRANTED 
            }
            if (denied.isEmpty() && grantResults.isNotEmpty()) {
                startSyncService()
            } else {
                Toast.makeText(this, "거부된 권한:\n${denied.joinToString("\n") { it.substringAfterLast(".") }}", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun startSyncService() {
        val intent = Intent(this, SyncService::class.java)
        startService(intent)
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
