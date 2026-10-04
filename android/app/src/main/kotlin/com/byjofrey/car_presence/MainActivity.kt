package com.byjofrey.car_presence

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var discord: DiscordSdkBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        discord?.stop()
        discord = DiscordSdkBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        discord?.start()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onDestroy() {
        discord?.stop()
        discord = null
        super.onDestroy()
    }
}
