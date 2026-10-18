package app.vocashelf.vocashelf

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.zip.ZipInputStream
import java.util.concurrent.Executors
import android.content.ContentValues
import android.content.Intent
import android.provider.MediaStore
import android.os.Build

class MainActivity : FlutterActivity() {
    companion object {
        private val worker = Executors.newSingleThreadExecutor()
        @Volatile private var started = false
        @Volatile private var failure: String? = null
    }
    private var pendingQr: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null
    private var runtimeChannel: MethodChannel? = null
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 29) window.isNavigationBarContrastEnforced = false
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        runtimeChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "vocalo1ng/runtime")
        PlaybackTransport.channel = runtimeChannel
        runtimeChannel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "fullscreen" -> {
                        val enabled = call.arguments == true
                        if (Build.VERSION.SDK_INT >= 30) {
                            window.insetsController?.let { controller ->
                                controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                                if(enabled) controller.hide(android.view.WindowInsets.Type.systemBars())
                                else controller.show(android.view.WindowInsets.Type.systemBars())
                            }
                        } else {
                            @Suppress("DEPRECATION")
                            window.decorView.systemUiVisibility = if(enabled) 5894 else 1792
                        }
                        result.success(enabled)
                    }
                    "openLoginApp" -> {
                        val packages = when(call.arguments as? String) {
                            "netease" -> listOf("com.netease.cloudmusic")
                            "bilibili" -> listOf("tv.danmaku.bili", "tv.danmaku.bilibilihd")
                            "qq" -> listOf("com.tencent.mobileqq")
                            else -> emptyList()
                        }
                        var opened = false
                        for (name in packages) {
                            val intent = packageManager.getLaunchIntentForPackage(name) ?: continue
                            try { startActivity(intent); opened = true; break } catch (_: android.content.ActivityNotFoundException) { }
                        }
                        result.success(opened)
                    }
                    "playback" -> {
                        val args = call.arguments as Map<*, *>
                        val playing = args["playing"] == true
                        if (playing && Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
                            !getPreferences(MODE_PRIVATE).getBoolean("notificationAsked", false)) {
                            getPreferences(MODE_PRIVATE).edit().putBoolean("notificationAsked", true).apply()
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1902)
                        }
                        val update = Intent(this, GatewayService::class.java).apply {
                            action = "playback"
                            putExtra("playing", playing)
                            putExtra("buffering", args["buffering"] == true)
                            putExtra("mediaId", args["mediaId"] as? String ?: "")
                            putExtra("title", args["title"] as? String ?: "Vocalo1ng")
                            putExtra("artist", args["artist"] as? String ?: "")
                            putExtra("cover", args["cover"] as? String ?: "")
                            putExtra("index", (args["index"] as? Number)?.toInt() ?: -1)
                            putExtra("count", (args["count"] as? Number)?.toInt() ?: 0)
                            putExtra("position", (args["position"] as? Number)?.toLong() ?: 0)
                            putExtra("duration", (args["duration"] as? Number)?.toLong() ?: 0)
                            putExtra("buffered", (args["buffered"] as? Number)?.toLong() ?: 0)
                            putExtra("queue", org.json.JSONArray(args["queue"] as? List<*> ?: emptyList<Any>()).toString())
                        }
                        if (playing && Build.VERSION.SDK_INT >= 26) startForegroundService(update) else startService(update)
                        result.success(true)
                    }
                    "saveQr" -> {
                        try {
                            val bytes = call.arguments as ByteArray
                            require(bytes.size <= 2000000)
                            if (Build.VERSION.SDK_INT >= 29) {
                                val values = ContentValues().apply {
                                    put(MediaStore.Images.Media.DISPLAY_NAME, "Vocalo1ng-login-${System.currentTimeMillis()}.png")
                                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Vocalo1ng")
                                    put(MediaStore.Images.Media.IS_PENDING, 1)
                                }
                                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: error("无法创建图片")
                                try {
                                    contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
                                    values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0)
                                    contentResolver.update(uri, values, null, null)
                                } catch (error: Throwable) { contentResolver.delete(uri, null, null); throw error }
                                result.success(true)
                            } else {
                                check(pendingResult == null)
                                pendingQr = bytes; pendingResult = result
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE); type = "image/png"
                                    putExtra(Intent.EXTRA_TITLE, "Vocalo1ng-login.png")
                                }, 1901)
                            }
                        } catch (error: Throwable) { result.error("save", error.toString(), null) }
                    }
                    "start" -> worker.execute {
                        try {
                            if (failure != null) error(failure!!)
                            if (!started) {
                                val root = File(filesDir, "runtime")
                                root.mkdirs()
                                File(root, "tmp").mkdirs()
                                val revision = assets.open("gateway.sha256").bufferedReader().use { it.readText() }
                                val stamp = File(root, "revision")
                                if (!stamp.exists() || stamp.readText() != revision) {
                                    ZipInputStream(assets.open("gateway.zip")).use { zip ->
                                        while (true) {
                                            val entry = zip.nextEntry ?: break
                                            val target = File(root, entry.name)
                                            require(target.canonicalPath.startsWith(root.canonicalPath + File.separator))
                                            if (entry.isDirectory) target.mkdirs() else {
                                                target.parentFile!!.mkdirs()
                                                target.outputStream().use { zip.copyTo(it) }
                                            }
                                            zip.closeEntry()
                                        }
                                    }
                                    stamp.writeText(revision)
                                }
                                started = true
                            }
                            startService(Intent(this, GatewayService::class.java))
                            runOnUiThread { result.success(true) }
                        } catch (error: Throwable) {
                            failure = error.toString()
                            runOnUiThread { result.error("runtime", failure, null) }
                        }
                    }
                    "diagnostics" -> {
                        val log = File(filesDir, "runtime/runtime.log")
                        result.success((failure ?: "") + "\n" + if (log.exists()) log.readText().takeLast(12000) else "")
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("transport")?.let { runtimeChannel?.invokeMethod("transport", it) }
    }
    override fun onResume() {
        super.onResume()
        // Android may stop an idle background service. Returning to the app
        // should restart its local service without changing any account files.
        if (started) {
            startService(Intent(this, GatewayService::class.java))
            runtimeChannel?.invokeMethod("refreshPlayback",null)
        }
    }
    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 1901) return
        val callback = pendingResult ?: return
        try {
            val uri = data?.data
            if (resultCode == RESULT_OK && uri != null) {
                contentResolver.openOutputStream(uri)!!.use { it.write(pendingQr!!) }
                callback.success(true)
            } else callback.error("cancelled", "已取消保存", null)
        } catch (error: Throwable) { callback.error("save", error.toString(), null) }
        finally { pendingResult = null; pendingQr = null }
    }
}
