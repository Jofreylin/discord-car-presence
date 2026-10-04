package com.byjofrey.car_presence

import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.discord.socialsdk.DiscordSocialSdkInit
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class DiscordSdkBridge(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "car_presence/discord")
    private val handler = Handler(Looper.getMainLooper())
    private val callbacks = object : Runnable {
        override fun run() {
            nativeRunCallbacks()
            handler.postDelayed(this, 16)
        }
    }
    private var connectResult: MethodChannel.Result? = null
    private var presenceResult: MethodChannel.Result? = null

    fun start() {
        DiscordSocialSdkInit.setEngineActivity(activity)
        System.loadLibrary("car_presence_discord")
        nativeInit()
        handler.post(callbacks)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    nativeStart(call.argument<String>("applicationId") ?: "")
                    handler.post { requestStoredTokens() }
                    result.success(null)
                }
                "connect" -> {
                    connectResult = result
                    nativeConnect(call.argument<String>("applicationId") ?: "")
                }
                "disconnect" -> {
                    nativeDisconnect()
                    result.success(null)
                }
                "getCurrentUser" -> result.success(nativeCurrentUser())
                "getStatus" -> result.success(nativeStatus())
                "updatePresence" -> {
                    if (nativeStatus() != "ready") {
                        result.error("not_ready", "Discord SDK is not Ready", null)
                    } else {
                        presenceResult = result
                        nativeUpdatePresence(
                            call.argument<String>("details") ?: "",
                            call.argument<String>("state") ?: "",
                        )
                    }
                }
                "clearPresence" -> {
                    if (nativeStatus() != "ready") {
                        result.error("not_ready", "Discord SDK is not Ready", null)
                    } else {
                        nativeClearPresence()
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun stop() {
        handler.removeCallbacks(callbacks)
    }

    fun onStatus(status: String) {
        channel.invokeMethod("onStatus", status)
    }

    fun onConnectResult(accessToken: String?, refreshToken: String?, error: String?) {
        bringActivityToFront()
        val pending = connectResult ?: return
        connectResult = null
        if (error != null) {
            pending.error("discord", error, null)
            return
        }
        pending.success(
            mapOf(
                "accessToken" to accessToken,
                "refreshToken" to refreshToken,
            ),
        )
    }

    fun onReplaceTokens(accessToken: String, refreshToken: String) {
        channel.invokeMethod(
            "replaceStoredTokens",
            mapOf(
                "accessToken" to accessToken,
                "refreshToken" to refreshToken,
            ),
        )
    }

    fun onClearTokens() {
        channel.invokeMethod("clearStoredTokens", null)
    }

    fun onPresenceResult(error: String?) {
        val pending = presenceResult ?: return
        presenceResult = null
        if (error.isNullOrEmpty()) {
            pending.success(null)
            return
        }
        pending.error("discord", error, null)
    }

    private fun bringActivityToFront() {
        val intent = Intent(activity, activity.javaClass).apply {
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        activity.startActivity(intent)
    }

    private fun requestStoredTokens() {
        channel.invokeMethod("readStoredTokens", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val stored = result as? Map<*, *>
                nativeRestore(
                    stored?.get("accessToken") as? String,
                    stored?.get("refreshToken") as? String,
                )
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                nativeRestore(null, null)
            }

            override fun notImplemented() {
                nativeRestore(null, null)
            }
        })
    }

    private external fun nativeInit()

    private external fun nativeRunCallbacks()

    private external fun nativeStart(applicationId: String)

    private external fun nativeRestore(accessToken: String?, refreshToken: String?)

    private external fun nativeConnect(applicationId: String)

    private external fun nativeDisconnect()

    private external fun nativeStatus(): String

    private external fun nativeCurrentUser(): Map<String, String>?

    private external fun nativeUpdatePresence(details: String, state: String)

    private external fun nativeClearPresence()
}
