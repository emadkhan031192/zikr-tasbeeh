package com.afzal.zikrtasbeeh

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import com.afzal.zikrtasbeeh.overlay.OverlayService

/**
 * Optional accessibility service: lets the volume buttons count while
 * another app is open (volume up = +1, volume down = −1).
 *
 * It only reads volume key events - nothing else. It never inspects the
 * screen content, notifications or any other data. Key events are consumed
 * only when the overlay is running and the "volume buttons" setting is on;
 * otherwise they pass through untouched.
 */
class ZikrAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        // canRequestFilterKeyEvents=true is declared in the XML config;
        // nothing else to do here.
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return false
        if (!OverlayService.running) return false
        val settings = Prefs.getJson(this, "zikr.settings")
        if (settings?.optBoolean("volumeButtons", false) != true) return false
        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                CounterNative.addCount(this, 1)
                OverlayService.refresh(this)
                true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                CounterNative.addCount(this, -1)
                OverlayService.refresh(this)
                true
            }
            else -> false
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used: this service only filters key events.
    }

    override fun onInterrupt() {
        // Nothing to clean up.
    }
}
