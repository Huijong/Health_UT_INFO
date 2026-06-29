package com.samsung.health.client

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * FIT / Cola.zip 전용 파일 피커 MethodChannel
 *
 * 왜 별도 구현?
 * file_picker 8.x의 pickFiles()는 Android에서 initialDirectory를
 * startFileExplorer() 호출 시 전달하지 않아 폴더 이동이 불가능하다.
 * 여기서는 DocumentsContract.buildDocumentUri()로 올바른 content URI를
 * EXTRA_INITIAL_URI에 직접 주입한다.
 */
class FileChannelPlugin(
    private val activityProvider: () -> Activity?
) {
    companion object {
        const val CHANNEL = "com.samsung.health.client/file_picker"
        private const val REQ_FIT  = 9001
        private const val REQ_COLA = 9002
        // Android 외부 저장소 Documents Provider authority
        private const val AUTHORITY = "com.android.externalstorage.documents"
    }

    private var pendingResult: MethodChannel.Result? = null

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val activity = activityProvider()
                if (activity == null) {
                    result.error("NO_ACTIVITY", "Activity not available", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                when (call.method) {
                    "pickFit" -> openPicker(
                        activity    = activity,
                        requestCode = REQ_FIT,
                        mimeType    = "*/*",            // .fit 은 공식 MIME 없음
                        docId       = "primary:Download/삼성 헬스/fit"
                    )
                    "pickCola" -> openPicker(
                        activity    = activity,
                        requestCode = REQ_COLA,
                        mimeType    = "application/zip",
                        docId       = "primary:Documents/COLA_FILE"
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun openPicker(activity: Activity, requestCode: Int, mimeType: String, docId: String) {
        // EXTRA_INITIAL_URI 에 넣을 content URI 생성
        val initialUri = DocumentsContract.buildDocumentUri(AUTHORITY, docId)

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri)
        }
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, requestCode)
    }

    /**
     * MainActivity.onActivityResult 에서 호출.
     * 우리 요청 코드면 true 반환(처리 완료), 아니면 false 반환(상위로 위임).
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_FIT && requestCode != REQ_COLA) return false

        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            // 취소
            pendingResult?.success(null)
            pendingResult = null
            return true
        }

        val activity = activityProvider()
        if (activity == null) {
            pendingResult?.error("NO_ACTIVITY", "Activity lost before copy", null)
            pendingResult = null
            return true
        }

        try {
            val localPath = copyToCache(activity.contentResolver, activity.cacheDir, uri)
            pendingResult?.success(localPath)
        } catch (e: Exception) {
            pendingResult?.error("COPY_ERROR", "파일 복사 실패: ${e.message}", null)
        }
        pendingResult = null
        return true
    }

    /** content URI → 앱 캐시 디렉토리 복사, 로컬 경로 반환 */
    private fun copyToCache(cr: ContentResolver, cacheDir: File, uri: Uri): String {
        val name = queryDisplayName(cr, uri) ?: (uri.lastPathSegment ?: "file")
        val dest = File(cacheDir, "sh_picker/$name").also { it.parentFile?.mkdirs() }

        cr.openInputStream(uri)!!.use { inp ->
            FileOutputStream(dest).use { out -> inp.copyTo(out) }
        }
        return dest.absolutePath
    }

    private fun queryDisplayName(cr: ContentResolver, uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = cr.query(uri, arrayOf("_display_name"), null, null, null)
            if (cursor != null && cursor.moveToFirst()) cursor.getString(0) else null
        } finally {
            cursor?.close()
        }
    }
}
