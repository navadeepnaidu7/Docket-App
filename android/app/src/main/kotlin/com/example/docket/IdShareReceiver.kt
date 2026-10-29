package com.example.docket

import android.content.Intent
import android.content.ClipData
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

/** Receives only local content grants. No document data is logged or uploaded. */
class IdShareReceiver(private val activity: FlutterActivity, private val channel: MethodChannel) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val pending = ArrayDeque<Map<String, Any>>()
    private val batches = mutableMapOf<String, File>()
    private var activeCopies = 0

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> result.success(if (pending.isEmpty()) null else pending.removeFirst())
                "shareFile" -> {
                    try {
                        val file = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                        val root = File(activity.cacheDir, "id_exports").canonicalFile
                        require(file.path.startsWith(root.path + File.separator) && file.isFile)
                        val mime = when (file.extension) {
                            "pdf" -> "application/pdf"
                            "png" -> "image/png"
                            "jpg" -> "image/jpeg"
                            "webp" -> "image/webp"
                            "heic" -> "image/heic"
                            else -> throw IllegalArgumentException("Unsupported type")
                        }
                        val uri = FileProvider.getUriForFile(activity, activity.packageName + ".id_files", file)
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newRawUri("Document", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        activity.startActivity(Intent.createChooser(send, "Share document"))
                        result.success(null)
                    } catch (_: Exception) { result.error("SHARE_FAILED", "Could not share file.", null) }
                }
                "release" -> {
                    val token = call.argument<String>("token")
                    val dir = batches.remove(token)
                    scope.launch(Dispatchers.IO) { dir?.listFiles()?.forEach { it.delete() }; dir?.delete() }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        scope.launch(Dispatchers.IO) {
            val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000
            File(activity.cacheDir, "id_received").listFiles()?.forEach { dir ->
                if (dir.isDirectory && dir.lastModified() < cutoff) {
                    dir.listFiles()?.forEach { it.delete() }; dir.delete()
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    fun receive(intent: Intent?) {
        val uris = when (intent?.action) {
            Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.toList() ?: emptyList()
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            else -> return
        }
        if (uris.isEmpty()) return
        if (uris.size > 4 || activeCopies + pending.size >= 4) {
            pending.addLast(mapOf("error" to "Share up to 4 images or PDFs at a time."))
            channel.invokeMethod("filesAvailable", null)
            return
        }
        activeCopies++
        scope.launch {
            val token = UUID.randomUUID().toString()
            val dir = File(File(activity.cacheDir, "id_received"), token)
            val batch = withContext(Dispatchers.IO) {
                try {
                    dir.mkdirs()
                    val paths = uris.mapIndexed { index, uri ->
                        require(uri.scheme == "content")
                        val mime = activity.contentResolver.getType(uri) ?: intent?.type
                        val extension = when (mime) {
                            "application/pdf" -> "pdf"
                            "image/jpeg", "image/jpg" -> "jpg"
                            "image/png" -> "png"
                            "image/webp" -> "webp"
                            "image/heic", "image/heif" -> "heic"
                            else -> throw IllegalArgumentException("Unsupported type")
                        }
                        val file = File(dir, "original-$index.$extension")
                        activity.contentResolver.openInputStream(uri).use { input ->
                            requireNotNull(input)
                            file.outputStream().use { output ->
                                val buffer = ByteArray(64 * 1024)
                                var total = 0L
                                while (true) {
                                    val size = input.read(buffer)
                                    if (size < 0) break
                                    total += size
                                    require(total <= 25L * 1024 * 1024)
                                    output.write(buffer, 0, size)
                                }
                                require(total > 0)
                            }
                        }
                        file.absolutePath
                    }
                    mapOf<String, Any>("token" to token, "files" to paths)
                } catch (_: Exception) {
                    dir.listFiles()?.forEach { it.delete() }; dir.delete()
                    mapOf<String, Any>("error" to "Could not import these files. Choose images or PDFs up to 25 MB each.")
                }
            }
            activeCopies--
            if (batch.containsKey("token")) batches[token] = dir
            pending.addLast(batch)
            channel.invokeMethod("filesAvailable", null)
        }
    }

    fun close() { channel.setMethodCallHandler(null); scope.cancel() }
}
