package com.afzal.zikrtasbeeh

import android.app.Activity
import android.app.Application
import android.os.Bundle
import com.afzal.zikrtasbeeh.overlay.OverlayService

/**
 * Tracks whether the main app is in the foreground so the overlay service
 * can honor "Hide overlay while Noor Tasbeeh is open".
 */
class ZikrApplication : Application(), Application.ActivityLifecycleCallbacks {

    private var resumedCount = 0

    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(this)
    }

    override fun onActivityResumed(activity: Activity) {
        if (resumedCount == 0) {
            OverlayService.appForeground(this, true)
        }
        resumedCount++
    }

    override fun onActivityPaused(activity: Activity) {
        resumedCount--
        if (resumedCount <= 0) {
            resumedCount = 0
            OverlayService.appForeground(this, false)
        }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
    override fun onActivityStarted(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
    override fun onActivityDestroyed(activity: Activity) {}
}
