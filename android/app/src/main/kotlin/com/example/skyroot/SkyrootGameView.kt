package com.example.skyroot

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.webkit.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject
import java.io.ByteArrayInputStream

class SkyrootGameViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        SkyrootGameView(context, viewId, args as? Map<*, *> ?: emptyMap<Any, Any>(), messenger)
}

@SuppressLint("SetJavaScriptEnabled")
class SkyrootGameView(context: Context, id: Int, params: Map<*, *>, messenger: BinaryMessenger) : PlatformView {
    private val webView = WebView(context)
    private val channel = MethodChannel(messenger, "skyroot/game/$id")
    private val prefs = context.getSharedPreferences("skyroot_original", Context.MODE_PRIVATE)
    private val origin = "appassets.androidplatform.net"
    private var safeArea = insets(params)

    init {
        webView.setBackgroundColor(Color.rgb(11, 23, 20))
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            mediaPlaybackRequiresUserGesture = true
            builtInZoomControls = false
            displayZoomControls = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }
        val debug = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        WebView.setWebContentsDebuggingEnabled(debug)
        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                Log.println(if (message.messageLevel() == ConsoleMessage.MessageLevel.ERROR) Log.ERROR else Log.INFO,
                    "SkyrootJS", "${message.message()} (${message.sourceId()}:${message.lineNumber()})")
                return true
            }
        }
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) = applySafeArea()

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                request.url.scheme != "https" || request.url.host != origin

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                val uri = request.url
                val path = uri.path.orEmpty()
                // Serve only APK assets from a synthetic HTTPS origin. No network fallback.
                if (uri.scheme != "https" || uri.host != origin || path.contains("..") ||
                    !(path.startsWith("/game/") || path.startsWith("/images/"))) return missing()
                val mime = when (path.substringAfterLast('.')) {
                    "html" -> "text/html"
                    "js", "mjs" -> "text/javascript"
                    "css" -> "text/css"
                    "json" -> "application/json"
                    "webp" -> "image/webp"
                    "png" -> "image/png"
                    "mp3" -> "audio/mpeg"
                    "ogg" -> "audio/ogg"
                    else -> "application/octet-stream"
                }
                return try {
                    WebResourceResponse(mime, "UTF-8", context.assets.open("flutter_assets/assets$path"))
                } catch (error: Exception) {
                    Log.e("SkyrootJS", "Missing bundled asset: $path", error)
                    missing()
                }
            }
        }
        webView.addJavascriptInterface(object {
            @JavascriptInterface fun load(): String = prefs.getString("save", "null") ?: "null"
            @JavascriptInterface fun save(json: String) {
                if (json.length > 100_000) return
                try {
                    val data = JSONObject(json)
                    if (data.optInt("v") == 2) prefs.edit().putString("save", json).apply()
                } catch (error: Exception) { Log.e("SkyrootJS", "Invalid save", error) }
            }
            @JavascriptInterface fun home() { webView.post { channel.invokeMethod("home", null) } }
        }, "SkyrootNative")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pause" -> {
                    webView.evaluateJavascript("window.skyrootLifecycle?.pause()") { webView.onPause(); result.success(null) }
                }
                "resume" -> { webView.onResume(); webView.evaluateJavascript("window.skyrootLifecycle?.resume()", null); result.success(null) }
                "back" -> { webView.evaluateJavascript("window.skyrootBack ? (window.skyrootBack(), true) : false") { handled -> if (handled != "true") channel.invokeMethod("home", null) }; result.success(null) }
                "insets" -> {
                    safeArea = insets(call.arguments as? Map<*, *>)
                    applySafeArea()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        val stage = ((params["stage"] as? Number)?.toInt() ?: 0).coerceIn(0, 10)
        val skin = ((params["skin"] as? Number)?.toInt() ?: 0).coerceIn(0, 10)
        val quality = if (params["lightMode"] != false) "light" else "detail"
        val (t, r, b, l) = safeArea
        webView.loadUrl("https://$origin/game/index.html?stage=$stage&skin=$skin&quality=$quality&debug=${if (debug) 1 else 0}" +
            "&safeTop=$t&safeRight=$r&safeBottom=$b&safeLeft=$l")
    }

    // Logical-pixel insets from Flutter; WebView CSS pixels use the same density.
    private fun insets(map: Map<*, *>?): List<Int> = listOf("safeTop", "safeRight", "safeBottom", "safeLeft")
        .map { ((map?.get(it) as? Number)?.toDouble() ?: 0.0).coerceIn(0.0, 200.0).toInt() }

    private fun applySafeArea() {
        val (t, r, b, l) = safeArea
        webView.evaluateJavascript("window.skyrootSetSafeArea?.($t,$r,$b,$l)", null)
    }

    private fun missing() = WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", emptyMap(), ByteArrayInputStream("Asset not found".toByteArray()))
    override fun getView(): View = webView
    override fun dispose() {
        channel.setMethodCallHandler(null)
        webView.evaluateJavascript("window.skyrootLifecycle?.pause()") {
            webView.stopLoading()
            webView.removeJavascriptInterface("SkyrootNative")
            webView.destroy()
        }
    }
}
