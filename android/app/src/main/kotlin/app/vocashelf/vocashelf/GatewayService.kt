package app.vocashelf.vocashelf

import android.app.Service
import android.content.Intent
import android.os.IBinder
import java.io.File
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build
import android.os.PowerManager
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.media.MediaMetadata

// Node and Flutter each own a native VM. Isolate their native runtime lifecycle,
// signal handling and C++/crypto globals in separate Android processes.
class GatewayService : Service() {
    private var mediaSession: MediaSession? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var images: NativeWikiImages? = null
    private external fun startRuntime(directory: String): Int
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        val root = File(filesDir, "runtime")
        images = NativeWikiImages(root)
        Thread({
            try {
                System.loadLibrary("vocalo_runtime")
                val code = startRuntime(root.absolutePath)
                File(root, "runtime.log").appendText("\nRuntime stopped: $code\n")
            } catch (error: Throwable) {
                File(root, "runtime.log").appendText("\n$error\n")
            }
        }, "Vocalo1ng-music").start()
    }
    private val notification by lazy { PlaybackNotification(this) }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "playback") notification.update(intent)
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        if (wakeLock?.isHeld == true) wakeLock!!.release()
        notification.close()
        images?.close()
        super.onDestroy()
        // Node can only be initialized once per process. A later service
        // recreation must get a fresh VM, rather than starting a second one.
        android.os.Process.killProcess(android.os.Process.myPid())
    }
}
