package com.taobao.power_image

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.taobao.power_image.dispatcher.PowerImageDispatcher;

class PowerImagePlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        @JvmField
        var appContext: Context? = null
    }

    private lateinit var channel: MethodChannel
    private var engineContext: PowerImageEngineContext? = null

    init {
        System.loadLibrary("powerimage")
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {

        appContext = binding.applicationContext

        channel = MethodChannel(binding.binaryMessenger, "power_image")
        channel.setMethodCallHandler(this)

        if (engineContext == null) {
            engineContext = PowerImageEngineContext()
        }

        engineContext?.onAttachedToEngine(binding)

        PowerImageDispatcher.getInstance().prepare()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" ->
                result.success("Android ${android.os.Build.VERSION.RELEASE}")

            else ->
                result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {

        engineContext?.onDetached()
        engineContext = null

        channel.setMethodCallHandler(null)
        appContext = null
    }
}
