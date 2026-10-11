package com.afzal.zikrtasbeeh

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.view.FlutterCallbackInformation

/**
 * Runs the Dart [bootRescheduleCallback] in a headless Flutter engine.
 *
 * Android clears scheduled alarms on reboot, so the BOOT_COMPLETED receiver
 * uses this to re-schedule all reminders (recomputing prayer times for the
 * new day with the offline adhan package). The Dart side calls back
 * "bootDone" on the zikr_tasbeeh/boot channel when finished; a 90 s timeout
 * destroys the engine as a safety net.
 */
object HeadlessBoot {
    private var engine: FlutterEngine? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeoutTask = Runnable { destroy() }

    @Synchronized
    fun run(context: Context, callbackHandle: Long) {
        if (engine != null) return
        try {
            val appContext = context.applicationContext
            val engine = FlutterEngine(appContext)
            GeneratedPluginRegistrant.registerWith(engine)
            val callbackInfo =
                FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
            val bundlePath =
                FlutterInjector.instance().flutterLoader().findAppBundlePath()
            engine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(appContext.assets, bundlePath, callbackInfo)
            )
            this.engine = engine
            handler.postDelayed(timeoutTask, 90_000)
        } catch (_: Exception) {
            destroy()
        }
    }

    @Synchronized
    fun done() {
        handler.removeCallbacks(timeoutTask)
        destroy()
    }

    private fun destroy() {
        try {
            engine?.destroy()
        } catch (_: Exception) {
        }
        engine = null
    }
}
