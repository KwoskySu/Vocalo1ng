package app.vocashelf.vocashelf

import java.io.File
import java.net.ServerSocket
import java.net.InetAddress
import java.net.HttpURLConnection
import java.net.URL
import java.net.URI
import java.net.URLDecoder
import java.util.UUID
import java.util.concurrent.Executors
import org.json.JSONObject

// Only public VocaWiki image files, using Android's normal HTTPS stack. This is
// not a generic proxy: no arbitrary hosts, credentials, redirects or TLS bypass.
class NativeWikiImages(root: File) {
    private val socket = ServerSocket(0, 8, InetAddress.getByName("127.0.0.1"))
    private val workers = Executors.newFixedThreadPool(3)
    private val token = UUID.randomUUID().toString() + UUID.randomUUID().toString()
    init {
        File(root, "native-images.json").writeText(JSONObject().put("port", socket.localPort).put("token", token).toString())
        Thread({
            while (!socket.isClosed) {
                try {
                    val client = socket.accept()
                    workers.execute {
                        client.use { connection ->
                            try {
                                connection.soTimeout = 3000
                                val input = connection.getInputStream().bufferedReader(Charsets.US_ASCII)
                                val line = input.readLine() ?: error("missing request")
                                require(line.length < 8192)
                                var authorized = false
                                var size = line.length
                                while (true) {
                                    val header = input.readLine() ?: break
                                    size += header.length; require(size < 12000)
                                    if (header.isEmpty()) break
                                    if (header.substringBefore(':').equals("Authorization", true)) authorized = header.substringAfter(':').trim() == "Bearer $token"
                                }
                                require(authorized && line.startsWith("GET /image?url="))
                                val value = line.substringAfter("GET /image?url=").substringBefore(' ')
                                val target = URI(URLDecoder.decode(value, "UTF-8"))
                                val api = target.path == "/api.php" && (target.rawQuery?.contains("action=query") == true || target.rawQuery?.contains("action=parse") == true)
                                require(target.scheme == "https" && target.host == "voca.wiki" && target.userInfo == null && (target.port == -1 || target.port == 443) && (target.path.startsWith("/images/") || api))
                                val request = URL(target.toASCIIString()).openConnection() as HttpURLConnection
                                try {
                                    request.instanceFollowRedirects = false
                                    request.connectTimeout = 12000; request.readTimeout = 15000
                                    request.setRequestProperty("User-Agent", "Vocalo1ng/0.4.1 (personal music reader)")
                                    request.setRequestProperty("Referer", "https://voca.wiki/")
                                    require(request.responseCode == 200)
                                    val type = request.contentType?.substringBefore(';') ?: ""
                                    require(if (api) type == "application/json" else type.matches(Regex("image/[a-zA-Z0-9.+-]+")))
                                    require(request.contentLengthLong <= 8388608)
                                    val bytes = request.inputStream.use { stream ->
                                        val buffer = java.io.ByteArrayOutputStream()
                                        val chunk = ByteArray(16384)
                                        while (true) {
                                            val count = stream.read(chunk); if (count < 0) break
                                            require(buffer.size() + count <= 8388608)
                                            buffer.write(chunk, 0, count)
                                        }
                                        buffer.toByteArray()
                                    }
                                    val output = connection.getOutputStream()
                                    output.write("HTTP/1.1 200 OK\r\nContent-Type: $type\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
                                    output.write(bytes); output.flush()
                                } finally { request.disconnect() }
                            } catch (_: Throwable) {
                                try { connection.getOutputStream().write("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray(Charsets.US_ASCII)) } catch (_: Throwable) {}
                            }
                        }
                    }
                } catch (_: Throwable) { if (!socket.isClosed) Thread.sleep(100) }
            }
        }, "Vocalo1ng-wiki-images").start()
    }
    fun close() { socket.close(); workers.shutdownNow() }
}
