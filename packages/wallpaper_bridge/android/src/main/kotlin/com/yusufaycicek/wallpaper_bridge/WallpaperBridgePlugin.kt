package com.yusufaycicek.wallpaper_bridge

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Display
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

/**
 * Sets the wallpaper with WallpaperManager and reports the physical display
 * size. Registered as a plugin (not in MainActivity) so it also exists in the
 * WorkManager background engine, which has no Activity.
 */
class WallpaperBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())
    private var executor: ExecutorService? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        executor = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor?.shutdown()
        executor = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "displaySize" -> result.success(displaySize())
            "isSupported" -> {
                val wm = WallpaperManager.getInstance(context)
                result.success(wm.isWallpaperSupported && wm.isSetWallpaperAllowed)
            }
            "setWallpaper" -> setWallpaper(call, result)
            else -> result.notImplemented()
        }
    }

    /** Portrait physical pixels of the default display. */
    private fun displaySize(): Map<String, Int> {
        val display = context.getSystemService(DisplayManager::class.java)
            .getDisplay(Display.DEFAULT_DISPLAY)
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        display.getRealMetrics(metrics)
        val w = min(metrics.widthPixels, metrics.heightPixels)
        val h = max(metrics.widthPixels, metrics.heightPixels)
        return mapOf("width" to w, "height" to h)
    }

    private fun setWallpaper(call: MethodCall, result: MethodChannel.Result) {
        val rgba = call.argument<ByteArray>("rgba")
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val target = call.argument<String>("target")
        if (rgba == null || width == null || height == null || target == null ||
            rgba.size != width * height * 4
        ) {
            result.error("BAD_ARGS", "rgba/width/height/target missing or inconsistent", null)
            return
        }
        val flags = when (target) {
            "lock" -> WallpaperManager.FLAG_LOCK
            "home" -> WallpaperManager.FLAG_SYSTEM
            else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
        }
        val worker = executor
        if (worker == null) {
            result.error("DETACHED", "Plugin is not attached to an engine", null)
            return
        }
        // Decoding and writing the wallpaper takes a few hundred ms: keep it
        // off the platform thread.
        worker.execute {
            try {
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                // ARGB_8888 is stored as R, G, B, A bytes: the same layout as
                // Flutter's rawRgba, so no conversion is needed.
                bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
                WallpaperManager.getInstance(context).setBitmap(bitmap, null, true, flags)
                bitmap.recycle()
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                mainHandler.post { result.error("SET_FAILED", e.message, e.javaClass.name) }
            }
        }
    }

    companion object {
        const val CHANNEL = "com.yusufaycicek.dayleaf/wallpaper"
    }
}
