package app.vocashelf.vocashelf;

import android.app.*;
import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.MediaController;
import android.media.session.PlaybackState;
import android.os.Looper;
import android.os.IBinder;
import android.view.View;
import android.widget.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.Implements;
import org.robolectric.annotation.Implementation;
import org.robolectric.shadow.api.Shadow;
import org.robolectric.shadows.ShadowMediaSession;
import java.lang.reflect.*;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk=28, application=Application.class)
public class PlaybackNotificationTest {
    // Robolectric doesn't bind MediaController to MediaSession. Capture the
    // actual platform calls instead of inventing a successful binder roundtrip.
    @Implements(MediaSession.class)
    public static class RecordingSession extends ShadowMediaSession {
        public MediaMetadata metadata;
        public PlaybackState playback;
        public PendingIntent activity;
        public MediaSession.Callback callback;
        @Implementation protected void setMetadata(MediaMetadata value) { metadata=value; }
        @Implementation protected void setPlaybackState(PlaybackState value) { playback=value; }
        @Implementation protected void setSessionActivity(PendingIntent value) { activity=value; }
        @Implementation protected void setCallback(MediaSession.Callback value) { callback=value; }
    }
    public static class TestService extends Service {
        @Override public IBinder onBind(Intent intent) { return null; }
    }

    @Test @Config(sdk=36, shadows=RecordingSession.class)
    public void android16PublishesSeekableProgressAfterDurationArrives() throws Exception {
        TestService service=Robolectric.buildService(TestService.class).create().get();
        PlaybackNotification publisher=new PlaybackNotification(service);
        try {
            publisher.update(new Intent().putExtra("title","Song").putExtra("playing",false));
            publisher.update(new Intent().putExtra("title","Song").putExtra("artist","Artist")
                .putExtra("mediaId","track-1").putExtra("duration",277000L).putExtra("position",83000L)
                .putExtra("buffered",120000L).putExtra("playing",false));
            Notification n=Shadows.shadowOf(service.getSystemService(NotificationManager.class)).getNotification(401);
            assertEquals("android.app.Notification$MediaStyle",n.extras.getString("android.template"));
            assertNull("Modern SystemUI owns the layout",n.contentView);
            assertNull(n.bigContentView);
            assertNotNull(n.extras.getParcelable(Notification.EXTRA_MEDIA_SESSION));
            assertEquals(3,n.actions.length);
            Field field=PlaybackNotification.class.getDeclaredField("session");field.setAccessible(true);
            RecordingSession recorded=Shadow.extract((MediaSession)field.get(publisher));
            assertEquals(277000L,recorded.metadata.getLong(MediaMetadata.METADATA_KEY_DURATION));
            assertEquals("track-1",recorded.metadata.getString(MediaMetadata.METADATA_KEY_MEDIA_ID));
            assertEquals(83000L,recorded.playback.getPosition());
            assertEquals(120000L,recorded.playback.getBufferedPosition());
            assertTrue((recorded.playback.getActions()&PlaybackState.ACTION_SEEK_TO)!=0);
            assertNotNull(recorded.activity);
            recorded.callback.onSeekTo(150000L);
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            java.util.List<Intent> broadcasts=Shadows.shadowOf((Application)service.getApplication()).getBroadcastIntents();
            assertTrue(broadcasts.stream().anyMatch(i->"seek:150000".equals(i.getStringExtra("transport"))));
            assertNull("Seeking must not open the player Activity",Shadows.shadowOf((Application)service.getApplication()).getNextStartedActivity());
            publisher.update(new Intent().putExtra("title","Song").putExtra("duration",277000L)
                .putExtra("position",83000L).putExtra("playing",true));
            Shadows.shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(2));
            assertTrue("Modern progress is actively published every second",recorded.playback.getPosition()>=85000L);
            assertEquals("System seek bar uses the session playback speed",1f,recorded.playback.getPlaybackSpeed(),0f);
            publisher.update(new Intent().putExtra("title","Song").putExtra("mediaId","track-1").putExtra("duration",277000L).putExtra("position",83000L).putExtra("playing",false));
            publisher.update(new Intent().putExtra("title","Song").putExtra("mediaId","track-1").putExtra("duration",0L).putExtra("position",83000L).putExtra("playing",false));
            assertEquals("Transient missing duration must not remove progress",277000L,recorded.metadata.getLong(MediaMetadata.METADATA_KEY_DURATION));
            publisher.update(new Intent().putExtra("title","Song").putExtra("duration",277000L)
                .putExtra("position",83000L).putExtra("playing",true).putExtra("buffering",true));
            assertEquals(PlaybackState.STATE_BUFFERING,recorded.playback.getState());
            assertEquals(0f,recorded.playback.getPlaybackSpeed(),0f);
        } finally { publisher.close(); }
    }

    @Test public void systemRebuildKeepsLegacyProgressWithoutLargeArtworkColumn() throws Exception {
        TestService service=Robolectric.buildService(TestService.class).create().get();
        PlaybackNotification controller=new PlaybackNotification(service);
        try {
            Bitmap art=Bitmap.createBitmap(64,64,Bitmap.Config.ARGB_8888);
            for(String name:new String[]{"cover","compactCover"}) {
                Field field=PlaybackNotification.class.getDeclaredField(name);field.setAccessible(true);field.set(controller,art);
            }
            controller.update(new Intent().putExtra("title","Still Shining")
                .putExtra("artist","Mayonazy / 重音テト").putExtra("duration",277000L)
                .putExtra("position",83000L).putExtra("playing",false));
            Notification notification=Shadows.shadowOf(service.getSystemService(NotificationManager.class)).getNotification(401);
            assertEquals("android.app.Notification$DecoratedMediaCustomViewStyle",notification.extras.getString("android.template"));
            assertNull("Artwork must not reserve the system's giant side column",notification.getLargeIcon());
            assertEquals(5,notification.actions.length);
            assertArrayEquals(new int[]{1,2,3},notification.extras.getIntArray(Notification.EXTRA_COMPACT_ACTIONS));

            // SystemUI rebuilds styled views, rather than using the serialized
            // bigContentView directly. This is the path missed in 0.4.7.
            Method recover=Notification.Builder.class.getDeclaredMethod("recoverBuilder",android.content.Context.class,Notification.class);
            recover.setAccessible(true);
            Notification.Builder rebuilt=(Notification.Builder)recover.invoke(null,service,notification);
            Method flag=Notification.Builder.class.getDeclaredMethod("setRebuildStyledRemoteViews",boolean.class);
            flag.setAccessible(true);flag.invoke(rebuilt,true);
            Method make=Notification.Builder.class.getDeclaredMethod("createBigContentView");
            make.setAccessible(true);
            RemoteViews remote=(RemoteViews)make.invoke(rebuilt);
            FrameLayout parent=new FrameLayout(service);
            View root=remote.apply(service,parent);
            int width=(int)(320*service.getResources().getDisplayMetrics().density);
            root.measure(View.MeasureSpec.makeMeasureSpec(width,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED));
            root.layout(0,0,width,root.getMeasuredHeight());
            ProgressBar progress=root.findViewById(R.id.track_progress);
            assertNotNull("Progress survives a framework template rebuild",progress);
            assertEquals(299,progress.getProgress());
            assertTrue("Progress occupies most of the notification width",progress.getMeasuredWidth()>width*.65);
            assertEquals("1:23",((TextView)root.findViewById(R.id.track_position)).getText().toString());
            assertEquals("4:37",((TextView)root.findViewById(R.id.track_duration)).getText().toString());
            assertEquals("Still Shining",((TextView)root.findViewById(R.id.track_title)).getText().toString());
        } finally { controller.close(); }
    }
}
