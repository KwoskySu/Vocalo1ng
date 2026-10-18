package app.vocashelf.vocashelf

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

// Runs in the Flutter process. Transport controls must not launch an Activity;
// opening the player is a separate sessionActivity/contentIntent action.
object PlaybackTransport {
    var channel: MethodChannel? = null
}
class PlaybackTransportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if(intent.action != "app.vocalo1ng.TRANSPORT") return
        val action = intent.getStringExtra("transport") ?: return
        if(action in listOf("play","pause","toggle","next","previous") ||
            Regex("(?:seek|queue):[0-9]{1,16}").matches(action)) {
            PlaybackTransport.channel?.invokeMethod("transport",action)
        }
    }
}
