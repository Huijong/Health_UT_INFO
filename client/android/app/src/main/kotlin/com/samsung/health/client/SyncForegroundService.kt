package com.samsung.health.client

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class SyncForegroundService : Service() {
    companion object {
        const val ACTION_START_SYNC = "START_SYNC"
        const val ACTION_UPDATE_PROGRESS = "UPDATE_PROGRESS"
        const val ACTION_COMPLETE_SYNC = "COMPLETE_SYNC"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        val action = intent?.action ?: ACTION_START_SYNC
        val message = intent?.getStringExtra("message") ?: "백그라운드에서 데이터를 수신하고 있습니다."
        val progress = intent?.getIntExtra("progress", -1) ?: -1
        val isComplete = (action == ACTION_COMPLETE_SYNC)

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (isComplete) {
                putExtra("SYNC_COMPLETE", true)
            }
        }

        val pendingIntent = android.app.PendingIntent.getActivity(
            this, 
            if (isComplete) 1 else 0, 
            mainIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (isComplete) "워치 동기화 완료" else "워치 동기화 중"
        
        val builder = NotificationCompat.Builder(this, "SYNC_CHANNEL_ID")
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setPriority(NotificationCompat.PRIORITY_HIGH) // Use HIGH to ensure it shows progress visibly
            .setContentIntent(pendingIntent)
            .setAutoCancel(isComplete)

        if (!isComplete && progress >= 0) {
            builder.setProgress(100, progress, false)
        } else if (!isComplete && progress < 0) {
            builder.setProgress(0, 0, true) // Indeterminate
        } else {
            builder.setProgress(0, 0, false) // Remove progress bar on complete
        }

        val notification = builder.build()

        if (isComplete) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(1, notification)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                stopForeground(false)
            }
            stopSelf()
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(1, notification)
            }
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "SYNC_CHANNEL_ID",
                "워치 동기화 서비스",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            if (manager != null) {
                manager.createNotificationChannel(channel)
            }
        }
    }
}
