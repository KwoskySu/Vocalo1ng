package app.vocashelf.vocashelf

import android.app.*
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.BitmapShader
import android.graphics.Shader
import android.media.MediaMetadata
import android.media.MediaDescription
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.*
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import org.json.JSONArray
import android.widget.RemoteViews

class PlaybackNotification(private val service: Service) {
    private val manager = service.getSystemService(Service.NOTIFICATION_SERVICE) as NotificationManager
    private val handler = Handler(Looper.getMainLooper())
    private val images = Executors.newSingleThreadExecutor()
    private val session = MediaSession(service, "Vocalo1ng")
    private val wake = (service.getSystemService(Service.POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Vocalo1ng:playback")
    private var state: Intent? = null
    private var coverUrl = ""
    private var cover: Bitmap? = null
    private var compactCover: Bitmap? = null
    private var accent = Color.rgb(39, 65, 61)
    private var updatedAt = SystemClock.elapsedRealtime()
    private var closed = false
    private var lastPlayback: PlaybackState? = null
    private val progressTick = object : Runnable {
        override fun run() {
            if (!closed && state?.getBooleanExtra("playing", false) == true) {
                // Keep the visible progress card current as well as MediaSession.
                if (Build.VERSION.SDK_INT >= 33) refreshProgress() else render()
                handler.postDelayed(this, 1000)
            }
        }
    }
    init {
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("playback", "音乐播放", NotificationManager.IMPORTANCE_LOW))
        session.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
        session.setSessionActivity(openPlayer())
        session.setCallback(object : MediaSession.Callback() {
            override fun onPlay() { control("play").send() }
            override fun onPause() { control("pause").send() }
            override fun onSkipToNext() { control("next").send() }
            override fun onSkipToPrevious() { control("previous").send() }
            override fun onSkipToQueueItem(id: Long) { control("queue:$id").send() }
            override fun onSeekTo(pos: Long) {
                val duration = state?.getLongExtra("duration", 0) ?: 0
                control("seek:${pos.coerceIn(0, if(duration>0) duration else Long.MAX_VALUE)}").send()
            }
        })
        session.isActive = true
    }
    private fun control(action: String) = PendingIntent.getBroadcast(service, action.hashCode(), Intent(service, PlaybackTransportReceiver::class.java).apply {
        this.action = "app.vocalo1ng.TRANSPORT"; putExtra("transport", action)
    }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun openPlayer() = PendingIntent.getActivity(service, 0, Intent(service, MainActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun update(intent: Intent) {
        val incoming = Intent(intent)
        val previous = state
        if (previous != null && previous.getStringExtra("mediaId") == incoming.getStringExtra("mediaId") && incoming.getLongExtra("duration", 0) <= 0) {
            incoming.putExtra("duration", previous.getLongExtra("duration", 0))
        }
        state = incoming
        updatedAt = SystemClock.elapsedRealtime()
        handler.removeCallbacks(progressTick)
        if (intent.getBooleanExtra("playing", false) && !intent.getBooleanExtra("buffering",false)) handler.postDelayed(progressTick, 1000)
        val next = intent.getStringExtra("cover") ?: ""
        if (coverUrl != next) {
            coverUrl = next; cover = null; compactCover = null
            accent = Color.rgb(39, 65, 61)
            if (next.isNotBlank()) images.execute {
                val bitmap = try {
                    val request = URL(next).openConnection() as HttpURLConnection
                    try {
                        request.connectTimeout = 8000; request.readTimeout = 10000
                        request.inputStream.use { stream ->
                            val bytes = stream.readBytesLimited(4 * 1024 * 1024)
                            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                            val options = BitmapFactory.Options().apply { inSampleSize = maxOf(1, maxOf(bounds.outWidth,bounds.outHeight) / 512) }
                            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                        }
                    } finally { request.disconnect() }
                } catch (_: Throwable) { null }
                val thumb = bitmap?.let { roundedCover(it) }
                val color = bitmap?.let { coverColor(it) } ?: Color.rgb(39,65,61)
                handler.post { if (!closed && coverUrl == next) { cover = bitmap; compactCover = thumb; accent = color; render() } }
            }
        }
        val queue = JSONArray(intent.getStringExtra("queue") ?: "[]")
        session.setQueue((0 until queue.length()).map { i ->
            val item = queue.getJSONObject(i)
            MediaSession.QueueItem(MediaDescription.Builder().setMediaId(item.optString("id"))
                .setTitle(item.optString("title")).setSubtitle(item.optString("artist")).build(), item.optLong("index", i.toLong()))
        })
        session.setQueueTitle("当前播放列表")
        render()
    }
    private fun render() {
        if (closed) return
        val data = state ?: return
        val title = data.getStringExtra("title") ?: "Vocalo1ng"
        val artist = data.getStringExtra("artist") ?: ""
        val playing = data.getBooleanExtra("playing", false)
        val buffering = playing && data.getBooleanExtra("buffering", false)
        val duration = data.getLongExtra("duration", 0).coerceAtLeast(0)
        val elapsed = if (playing && !buffering) SystemClock.elapsedRealtime() - updatedAt else 0
        val position = (data.getLongExtra("position", 0) + elapsed).coerceIn(0, if(duration>0)duration else Long.MAX_VALUE)
        val count = data.getIntExtra("count", 0)
        val index = data.getIntExtra("index", -1)
        val metadata = MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_MEDIA_ID, data.getStringExtra("mediaId") ?: title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, if (count > 0) "当前播放列表 · ${index+1}/$count" else "Vocalo1ng")
            .putLong(MediaMetadata.METADATA_KEY_DURATION, duration)
        cover?.let { metadata.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it).putBitmap(MediaMetadata.METADATA_KEY_ART, it) }
        session.setMetadata(metadata.build())
        val playback = PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_SKIP_TO_QUEUE_ITEM or PlaybackState.ACTION_SEEK_TO)
            .setBufferedPosition(data.getLongExtra("buffered",0).coerceAtLeast(position))
            .setActiveQueueItemId(index.toLong()).setState(if(buffering) PlaybackState.STATE_BUFFERING else if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                position, if (playing && !buffering) 1f else 0f, SystemClock.elapsedRealtime()).build()
        lastPlayback = playback
        session.setPlaybackState(playback)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(service,"playback") else Notification.Builder(service)
        val progress = if(duration>0) (position*1000/duration).toInt().coerceIn(0,1000) else 0
        val legacy = Build.VERSION.SDK_INT < 29
        // SystemUI rebuilds styled RemoteViews. Plain MediaStyle discards a
        // custom progress panel during that rebuild; DecoratedMedia preserves it.
        val modern = Build.VERSION.SDK_INT >= 33
        val style = if (modern) Notification.MediaStyle() else Notification.DecoratedMediaCustomViewStyle()
        style.setMediaSession(session.sessionToken)
        if(legacy) style.setShowActionsInCompactView(1,2,3) else style.setShowActionsInCompactView(0,1,2)
        builder.setProgress(1000,progress,false).setShowWhen(false)
        if (!modern) {
            val views=RemoteViews(service.packageName,R.layout.playback_notification)
            views.setTextViewText(R.id.track_title,title)
            views.setTextViewText(R.id.track_artist,artist)
            views.setTextViewText(R.id.track_position,time(position))
            views.setTextViewText(R.id.track_duration,time(duration))
            views.setProgressBar(R.id.track_progress,1000,progress,false)
            if(compactCover!=null) views.setImageViewBitmap(R.id.track_cover,compactCover) else views.setImageViewResource(R.id.track_cover,R.mipmap.ic_launcher)
            builder.setCustomBigContentView(views)
            val compact = RemoteViews(service.packageName, R.layout.playback_notification_compact)
            compact.setTextViewText(R.id.track_title, title)
            compact.setTextViewText(R.id.track_artist, artist)
            compact.setTextViewText(R.id.track_position, "${time(position)} / ${time(duration)}")
            compact.setProgressBar(R.id.track_progress, 1000, progress, false)
            if(compactCover != null) compact.setImageViewBitmap(R.id.track_cover, compactCover)
            else compact.setImageViewResource(R.id.track_cover, R.mipmap.ic_launcher)
            builder.setCustomContentView(compact)
        }
        builder.setColor(accent)
        if (modern) cover?.let { builder.setLargeIcon(it) }
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        if(Build.VERSION.SDK_INT>=26) builder.setColorized(false)
        // Legacy MediaStyle turns largeIcon into a huge decorative right panel.
        // Our own thumbnail remains in the progress panel; lockscreen/session
        // album art is kept separately in MediaMetadata above.
        // Session metadata retains artwork. A template largeIcon reserves an
        // extra column which can squeeze custom progress on vendor templates.
        if(legacy) builder.addAction(Notification.Action.Builder(R.drawable.notification_back,"后退10秒",control("seek:${(position-10000).coerceAtLeast(0)}")).build())
        builder.setContentTitle(title).setContentText(artist)
            .setSubText(if(count>0) "当前列表 · 第 ${index+1}/$count 首" else "Vocalo1ng")
            .setSmallIcon(R.drawable.notification_music).setContentIntent(openPlayer())
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(Notification.VISIBILITY_PUBLIC).setOnlyAlertOnce(true).setOngoing(playing)
            .addAction(Notification.Action.Builder(R.drawable.notification_previous,"上一首",control("previous")).build())
            .addAction(Notification.Action.Builder(if(playing) R.drawable.notification_pause else R.drawable.notification_play,if(playing) "暂停" else "播放",control("toggle")).build())
            .addAction(Notification.Action.Builder(R.drawable.notification_next,"下一首",control("next")).build())
        if(legacy) builder.addAction(Notification.Action.Builder(R.drawable.notification_forward,"前进10秒",control("seek:${(position+10000).coerceAtMost(if(duration>0)duration else Long.MAX_VALUE)}")).build())
        val notification = builder.setStyle(style).build()
        if (playing) {
            if (Build.VERSION.SDK_INT >= 29) {
                service.startForeground(401, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else service.startForeground(401, notification)
            if(!wake.isHeld) wake.acquire()
        } else {
            if(wake.isHeld) wake.release()
            service.stopForeground(Service.STOP_FOREGROUND_DETACH)
            manager.notify(401, notification)
        }
    }
    private fun refreshProgress() {
        val data = state ?: return
        val previous = lastPlayback ?: return
        if(previous.state != PlaybackState.STATE_PLAYING) return
        val duration = data.getLongExtra("duration",0)
        val elapsed = SystemClock.elapsedRealtime() - updatedAt
        val position = (data.getLongExtra("position",0)+elapsed).coerceIn(0,if(duration>0)duration else Long.MAX_VALUE)
        val next = PlaybackState.Builder(previous)
            .setState(PlaybackState.STATE_PLAYING,position,1f,SystemClock.elapsedRealtime())
            .setBufferedPosition(data.getLongExtra("buffered",0).coerceAtLeast(position)).build()
        lastPlayback=next
        session.setPlaybackState(next)
    }
    private fun time(ms:Long) = "${ms/60000}:${((ms/1000)%60).toString().padStart(2,'0')}"
    private fun roundedCover(bitmap: Bitmap): Bitmap {
        val image = Bitmap.createScaledBitmap(bitmap,128,128,true)
        val result = Bitmap.createBitmap(128,128,Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader=BitmapShader(image,Shader.TileMode.CLAMP,Shader.TileMode.CLAMP) }
        Canvas(result).drawRoundRect(0f,0f,128f,128f,18f,18f,paint)
        return result
    }
    private fun coverColor(bitmap: Bitmap): Int {
        val sample=Bitmap.createScaledBitmap(bitmap,8,8,true)
        var r=0; var g=0; var b=0
        for(y in 0..7) for(x in 0..7) { val c=sample.getPixel(x,y);r+=Color.red(c);g+=Color.green(c);b+=Color.blue(c) }
        val hsv=FloatArray(3);Color.RGBToHSV(r/64,g/64,b/64,hsv)
        hsv[1]=hsv[1].coerceAtMost(.45f);hsv[2]=.28f
        return Color.HSVToColor(hsv)
    }
    fun close() { closed=true;handler.removeCallbacks(progressTick);images.shutdownNow(); session.release(); if(wake.isHeld) wake.release() }
}

private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
    val output = java.io.ByteArrayOutputStream()
    val buffer = ByteArray(16384)
    while(true) { val n=read(buffer); if(n<0) break; require(output.size()+n<=limit); output.write(buffer,0,n) }
    return output.toByteArray()
}
