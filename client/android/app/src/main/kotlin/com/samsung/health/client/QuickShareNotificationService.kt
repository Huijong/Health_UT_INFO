package com.samsung.health.client

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class QuickShareNotificationService : NotificationListenerService() {
    companion object {
        var onLinkDetected: ((String) -> Unit)? = null
        var onUploadProgress: (() -> Unit)? = null
        var uploadStartTime: Long = 0L
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        if (packageName.contains("com.samsung.android.app.sharelive")) {
            if (sbn.postTime < uploadStartTime) {
                Log.d("QS_NOTI", "Ignoring old notification (postTime: ${sbn.postTime} < $uploadStartTime)")
                return
            }
            val title = sbn.notification.extras.getString("android.title") ?: ""
            val text = sbn.notification.extras.getString("android.text") ?: ""
            
            Log.d("QS_NOTI", "Quick Share Notification: Title=$title, Text=$text")
            
            // Dump all extras to find the URL
            val extras = sbn.notification.extras
            if (extras != null) {
                for (key in extras.keySet()) {
                    val value = extras.get(key)
                    Log.d("QS_NOTI", "Extra: $key = $value")
                }
            }
            
            // Try to find URL in any extra
            var foundUrl: String? = null
            if (extras != null) {
                for (key in extras.keySet()) {
                    val value = extras.get(key)?.toString() ?: ""
                    val extracted = extractLink(value)
                    if (extracted != null) {
                        foundUrl = extracted
                        Log.d("QS_NOTI", "Found URL in extra $key: $foundUrl")
                        break
                    }
                }
            }

            if (title.contains("\uB9C1\uD06C \uC0DD\uC131\uB428") || text.contains("\uB9C1\uD06C \uC0DD\uC131\uB428") ||
                title.contains("Link created") || text.contains("Link created")) {
                
                // 1. Try to find 'Copy' action and trigger it automatically!
                if (sbn.notification.actions != null) {
                    for (action in sbn.notification.actions) {
                        val actionTitle = action.title?.toString() ?: ""
                        Log.d("QS_NOTI", "Found Action: $actionTitle")
                        if (actionTitle.contains("\uBCF5\uC0AC") || actionTitle.contains("Copy")) {
                            Log.d("QS_NOTI", "Auto-triggering Copy Action!")
                            try {
                                action.actionIntent.send()
                            } catch (e: Exception) {
                                Log.e("QS_NOTI", "Failed to send action intent", e)
                            }
                        }
                    }
                }

                val link = foundUrl ?: extractLink(text) ?: extractLink(title) ?: "unknown_link"
                Log.d("QS_NOTI", "Quick Share Link Ready: $link")
                onLinkDetected?.invoke(link)
            } else if (title.contains("\uC5C5\uB85C\uB4DC \uC911") || text.contains("\uC5C5\uB85C\uB4DC \uC911") ||
                       title.contains("Uploading") || text.contains("Uploading")) {
                onUploadProgress?.invoke()
            }
        }
    }

    private fun extractLink(text: String): String? {
        val urlRegex = "(http(s)?://[\\w-]+(\\.[\\w-]+)+([\\w.,@?^=%&:/~+#-]*[\\w@?^=%&/~+#-])?)".toRegex()
        val matchResult = urlRegex.find(text)
        return matchResult?.value
    }
}
