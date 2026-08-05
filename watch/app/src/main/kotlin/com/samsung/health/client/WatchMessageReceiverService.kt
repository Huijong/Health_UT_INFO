package com.samsung.health.client

import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import java.io.File

class WatchMessageReceiverService : WearableListenerService() {

    companion object {
        private const val TAG = "HP_MsgReceiver"
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == "/request_wifi_join") {
            writeLog("[BG_MSG] Received /request_wifi_join. Bringing MainActivity to foreground...")
            try {
                val mainIntent = Intent(this, MainActivity::class.java).apply {
                    action = "ACTION_TRIGGER_WIFI_JOIN"
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    if (messageEvent.data != null && messageEvent.data.isNotEmpty()) {
                        try {
                            val payloadStr = String(messageEvent.data, Charsets.UTF_8)
                            val json = org.json.JSONObject(payloadStr)
                            putExtra("ssid", json.optString("ssid", "healthport"))
                            putExtra("pwd", json.optString("pwd", "12345678"))
                        } catch (e: Exception) {}
                    }
                }
                startActivity(mainIntent)
                writeLog("[BG_MSG] MainActivity launched successfully with wifi join action.")
            } catch (e: Exception) {
                writeLog("[BG_MSG] Failed to start MainActivity: ${e.message}")
            }
        } else if (messageEvent.path == "/open_watch_sysdump") {
            writeLog("[SysDump_Msg] Received command from phone! Launching dialog activity directly...")
            try {
                // 1. Trigger Notification (Vibration & Backup access)
                sendSysDumpNotification()
                
                // 2. Launch Dialog UI Activity directly on Watch screen
                val dialogIntent = Intent(this, GuideDialogActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(dialogIntent)
                writeLog("[SysDump_Msg] Successfully launched GuideDialogActivity and dispatched Notification.")
            } catch (e: Exception) {
                val sw = java.io.StringWriter()
                e.printStackTrace(java.io.PrintWriter(sw))
                writeLog("[SysDump_Msg][FAIL] Error starting Dialog/Notification: ${e.message}\nStackTrace:\n$sw")
            }
        }
    }

    private fun sendSysDumpNotification() {
        val channelId = "sysdump_channel"
        val channelName = "SysDump Launcher"
        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                channelName,
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Launch SysDump on Watch"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, GuideDialogActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        
        val pendingIntent = android.app.PendingIntent.getActivity(
            this,
            9900,
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        // Simple default android icon or application icon
        val iconRes = applicationInfo.icon

        val builder = androidx.core.app.NotificationCompat.Builder(this, channelId)
            .setSmallIcon(iconRes)
            .setContentTitle("SysDump 가이드")
            .setContentText("터치하여 다이얼러 진입 및 *#9900# 입력 실행")
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        notificationManager.notify(9900, builder.build())
    }

    private fun writeLog(msg: String) {
        Log.d(TAG, msg)
        try {
            val folder = cacheDir
            if (!folder.exists()) folder.mkdirs()
            val ts = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            File(folder, "message_receive_log.txt").appendText("[$ts] $msg\n")
        } catch (_: Exception) {}
    }
}
