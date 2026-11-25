package com.musicplay.music_play

import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METADATA_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "read") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = call.argument<String>("uri")
                if (uri == null) {
                    result.error("bad_args", "uri is required", null)
                    return@setMethodCallHandler
                }
                executor.execute {
                    val outcome = runCatching { readMetadata(Uri.parse(uri)) }
                    mainHandler.post {
                        outcome
                            .onSuccess { result.success(it) }
                            .onFailure { result.error("metadata_failed", it.message, null) }
                    }
                }
            }
    }

    private fun readMetadata(uri: Uri): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            if (uri.scheme == null || uri.scheme == "file") {
                retriever.setDataSource(uri.path)
            } else {
                retriever.setDataSource(this, uri)
            }
            fun field(key: Int) = retriever.extractMetadata(key)?.takeIf { it.isNotBlank() }
            return mapOf(
                "title" to field(MediaMetadataRetriever.METADATA_KEY_TITLE),
                "artist" to (field(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    ?: field(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST)),
                "album" to field(MediaMetadataRetriever.METADATA_KEY_ALBUM),
                "durationMs" to field(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull(),
            )
        } finally {
            retriever.release()
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val METADATA_CHANNEL = "music_play/metadata"
    }
}
