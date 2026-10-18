package com.example.skyroot

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        flutterEngine.platformViewsController.registry.registerViewFactory("skyroot/original-game", SkyrootGameViewFactory(messenger))
        MethodChannel(messenger, "skyroot/progress").setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("skyroot_original", MODE_PRIVATE)
            when (call.method) {
                "load" -> result.success(prefs.getString("save", null))
                "reset" -> { prefs.edit().remove("save").apply(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
}
