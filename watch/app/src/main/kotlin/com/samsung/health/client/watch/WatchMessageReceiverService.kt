package com.samsung.health.client.watch

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
            writeLog("[BG_MSG] Received /request_wifi_join from paired phone!")

            // Trigger Wifi join process via SyncService
            val intent = Intent(this, SyncService::class.java).apply {
                action = "ACTION_TRIGGER_WIFI_JOIN"
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                writeLog("[BG_MSG] Successfully launched SyncService with ACTION_TRIGGER_WIFI_JOIN.")
            } catch (e: Exception) {
                writeLog("[BG_MSG] Failed to start SyncService: ${e.message}")
            }
        }
    }

    private fun writeLog(msg: String) {
        Log.d(TAG, msg)
        try {
            val folder = File("/sdcard/Documents/COLA_FILE/")
            if (!folder.exists()) folder.mkdirs()
            val ts = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            File(folder, "sync_log.txt").appendText("[$ts] $msg\n")
        } catch (_: Exception) {}
    }
}
