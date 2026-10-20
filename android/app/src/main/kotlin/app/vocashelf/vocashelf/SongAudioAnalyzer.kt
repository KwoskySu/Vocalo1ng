package app.vocashelf.vocashelf

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteOrder
import kotlin.math.*

/** Decodes a small sliding window of the current source, never the whole song.
 * One worker, <= 40 frames, no microphone/session-0 or recording permission. */
class SongAudioAnalyzer(private val context: Context, messenger: BinaryMessenger) {
    private data class Source(val url: String, val headers: Map<String,String>, val id: Long)
    private data class Frame(val ms: Long, val bands: List<Double>, val wave: List<Double>)
    private val lock = Object()
    private val frames = ArrayDeque<Frame>()
    private var source: Source? = null
    private var serial = 0L
    private var position = 0L
    private var playing = false
    private var closed = false
    private var status = "等待音源"
    private val channel = MethodChannel(messenger, "vocalo1ng/audio")
    private val worker = Thread({ run() }, "Vocalo1ng-source-analysis").apply { isDaemon = true; start() }
    init {
        channel.setMethodCallHandler { call, result ->
            synchronized(lock) {
                when(call.method) {
                    "start" -> {
                        val args = call.arguments as? Map<*, *>
                        val url = args?.get("url") as? String ?: ""
                        val headers = (args?.get("headers") as? Map<*, *>)?.entries?.mapNotNull {
                            if(it.key is String && it.value is String) (it.key as String) to (it.value as String) else null
                        }?.toMap() ?: emptyMap()
                        serial++; source = Source(url, headers, serial); frames.clear(); status = "音源分析加载中"; lock.notifyAll(); result.success(null)
                    }
                    "stop" -> { serial++; source = null; frames.clear(); lock.notifyAll(); result.success(null) }
                    "read" -> {
                        val args = call.arguments as? Map<*, *>
                        position = (args?.get("position") as? Number)?.toLong() ?: 0
                        playing = args?.get("playing") == true
                        val nearest = frames.minByOrNull { abs(it.ms-position) }
                        val ready = nearest != null && abs(nearest.ms-position) < 250 && playing
                        result.success(mapOf("available" to ready, "status" to if(ready) "当前歌曲 · 实时频谱" else status,
                            "bands" to if(ready) nearest!!.bands else emptyList<Double>(), "waveform" to if(ready) nearest!!.wave else emptyList<Double>()))
                        lock.notifyAll()
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
    fun close() { synchronized(lock) { closed = true; serial++; source = null; lock.notifyAll() }; channel.setMethodCallHandler(null) }
    private fun run() {
        var failedId = -1L
        var failures = 0
        while(true) {
            val next = synchronized(lock) {
                while(!closed && source == null) lock.wait(200)
                if(closed) return
                source!!
            }
            if(failedId != next.id) { failedId = next.id; failures = 0 }
            try { decode(next) } catch (_: Exception) {
                synchronized(lock) { if(source?.id == next.id) {
                    failures++; frames.clear()
                    status = "此音源暂无法分析 · 播放不受影响"
                    if(failures >= 3) source = null else lock.wait(750L * failures)
                } }
            }
        }
    }
    private fun current(id: Long) = synchronized(lock) { !closed && source?.id == id }
    private fun decode(src: Source) {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        try {
            if(src.url.startsWith("content:")) extractor.setDataSource(context, Uri.parse(src.url), null)
            else if(src.url.startsWith("http")) extractor.setDataSource(src.url, src.headers)
            else extractor.setDataSource(src.url.removePrefix("file://"))
            val track = (0 until extractor.trackCount).firstOrNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true } ?: throw IllegalArgumentException("No audio track")
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            format.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            decoder = codec; codec.configure(format, null, null, 0); codec.start()
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var encoding = AudioFormat.ENCODING_PCM_16BIT
            var decodedAt = -10000L
            var eos = false
            var used = 0
            val pcm = DoubleArray(1024)
            val info = MediaCodec.BufferInfo()
            while(current(src.id)) {
                val target = synchronized(lock) {
                    if(!playing || decodedAt > position + 600) lock.wait(40)
                    position
                }
                if(!current(src.id)) break
                if(decodedAt < target - 500 || decodedAt > target + 1800) {
                    extractor.seekTo(target * 1000, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
                    codec.flush(); eos = false; used = 0; decodedAt = target - 100
                    synchronized(lock) { frames.clear() }
                }
                if(!playing || decodedAt > target + 600) continue
                if(!eos) {
                    val input = codec.dequeueInputBuffer(10000)
                    if(input >= 0) {
                        val buf = codec.getInputBuffer(input)!!
                        val size = extractor.readSampleData(buf, 0)
                        if(size < 0) { codec.queueInputBuffer(input,0,0,0,MediaCodec.BUFFER_FLAG_END_OF_STREAM); eos = true }
                        else { codec.queueInputBuffer(input,0,size,extractor.sampleTime,0); extractor.advance() }
                    }
                }
                val output = codec.dequeueOutputBuffer(info, 10000)
                if(output == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val f = codec.outputFormat
                    rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE); channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    if(f.containsKey(MediaFormat.KEY_PCM_ENCODING)) encoding = f.getInteger(MediaFormat.KEY_PCM_ENCODING)
                    if(encoding != AudioFormat.ENCODING_PCM_16BIT && encoding != AudioFormat.ENCODING_PCM_FLOAT) throw UnsupportedOperationException("PCM format")
                } else if(output >= 0) {
                    val buffer = codec.getOutputBuffer(output)!!; buffer.order(ByteOrder.LITTLE_ENDIAN)
                    buffer.position(info.offset); buffer.limit(info.offset+info.size)
                    val bytes = if(encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
                    var sample = 0
                    while(buffer.remaining() >= channels * bytes) {
                        var mono = 0.0
                        repeat(channels) { mono += if(bytes == 4) buffer.float.toDouble() else buffer.short / 32768.0 }
                        pcm[used++] = (mono/channels).let { if(it.isFinite()) it.coerceIn(-1.0,1.0) else 0.0 }
                        sample++
                        if(used == pcm.size) {
                            val ms = info.presentationTimeUs/1000 + sample*1000L/rate
                            val frame = analyze(pcm, rate, ms)
                            synchronized(lock) { if(source?.id == src.id) { frames.addLast(frame); while(frames.size>40) frames.removeFirst(); status = "等待播放位置" } }
                            used = 0
                        }
                    }
                    decodedAt = info.presentationTimeUs/1000
                    codec.releaseOutputBuffer(output, false)
                    if(info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) synchronized(lock) { lock.wait(100) }
                }
            }
        } finally { try { decoder?.stop() } catch (_:Exception) {}; decoder?.release(); extractor.release() }
    }
    private fun analyze(pcm: DoubleArray, rate: Int, ms: Long): Frame {
        val n = pcm.size; val re = DoubleArray(n) { pcm[it]*(0.5-0.5*cos(2*PI*it/(n-1))) }; val im = DoubleArray(n)
        var j=0
        for(i in 1 until n) { var b=n shr 1; while(j and b != 0) { j=j xor b; b=b shr 1 }; j=j xor b; if(i<j) { val t=re[i]; re[i]=re[j]; re[j]=t } }
        var len=2
        while(len<=n) { val a=-2*PI/len; var start=0
            while(start<n) { for(k in 0 until len/2) { val wr=cos(a*k); val wi=sin(a*k); val at=start+k; val other=at+len/2
                val r=re[other]*wr-im[other]*wi; val x=re[other]*wi+im[other]*wr
                re[other]=re[at]-r; im[other]=im[at]-x; re[at]+=r; im[at]+=x }; start+=len }; len*=2 }
        val top=min(20000.0,rate*.48)
        val bands=List(48) { band ->
            val lo=(40*(top/40).pow(band/48.0)*n/rate).toInt().coerceIn(1,n/2-1)
            val hi=(40*(top/40).pow((band+1)/48.0)*n/rate).toInt().coerceIn(lo+1,n/2)
            var peak=0.0; for(bin in lo until hi) peak=max(peak,hypot(re[bin],im[bin])/(n*.25))
            ((20*log10(max(peak,1e-8))+70)/70).coerceIn(0.0,1.0)
        }
        return Frame(ms,bands,List(128) { pcm[it*n/128] })
    }
}
