package com.samsung.health.client

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

class GuideDialogActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Simple Watch Dialog layout
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setPadding(24, 24, 24, 24)
            setBackgroundColor(android.graphics.Color.parseColor("#121212"))
        }

        val textTitle = TextView(this).apply {
            text = "워치 SysDump 실행 가이드"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 13f
            gravity = android.view.Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        layout.addView(textTitle)

        val spacer = android.view.View(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(1, 10)
        }
        layout.addView(spacer)

        val textDesc = TextView(this).apply {
            text = "잠시 후 키패드 화면이 열리면\n*#9900#\n을 순서대로 직접 눌러주세요!"
            setTextColor(android.graphics.Color.parseColor("#A0A0A0"))
            textSize = 11.5f
            gravity = android.view.Gravity.CENTER
        }
        layout.addView(textDesc)

        val spacer2 = android.view.View(this).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(1, 16)
        }
        layout.addView(spacer2)

        val btnConfirm = Button(this).apply {
            text = "확인 (다이얼러 열기)"
            textSize = 11f
            setTextColor(android.graphics.Color.BLACK)
            setBackgroundColor(android.graphics.Color.parseColor("#3DFFC1"))
            setOnClickListener {
                openSamsungDialer()
                finish()
            }
        }
        layout.addView(btnConfirm)

        setContentView(layout)
    }

    private fun openSamsungDialer() {
        writeLog("[GuideActivity] Attempting to open Samsung Wear OS Dialer...")
        try {
            // Target Samsung Dialer specifically on Wear OS
            val intent = Intent(Intent.ACTION_DIAL).apply {
                setClassName("com.samsung.android.dialer", "com.samsung.android.dialer.dialpad.DialpadActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            writeLog("[GuideActivity][SUCCESS] Samsung Dialer activity triggered.")
        } catch (e: Exception) {
            writeLog("[GuideActivity][WARN] Samsung Dialer not found or failed: ${e.message}. Trying generic fallback...")
            try {
                // Fallback to generic Dialer intent
                val intent = Intent(Intent.ACTION_DIAL).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                writeLog("[GuideActivity][SUCCESS] Generic fallback dialer triggered.")
            } catch (fe: Exception) {
                val sw = java.io.StringWriter()
                fe.printStackTrace(java.io.PrintWriter(sw))
                writeLog("[GuideActivity][ERROR] Fallback dialer failed: ${fe.message}\nStackTrace:\n$sw")
            }
        }
    }

    private fun writeLog(msg: String) {
        android.util.Log.d("HP_GuideActivity", msg)
        try {
            val folder = cacheDir
            if (!folder.exists()) folder.mkdirs()
            val ts = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            val logFile = java.io.File(folder, "message_receive_log.txt")
            logFile.appendText("[$ts] $msg\n")
        } catch (_: Exception) {}
    }
}
