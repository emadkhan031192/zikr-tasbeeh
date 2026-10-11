package com.afzal.zikrtasbeeh

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.afzal.zikrtasbeeh.overlay.OverlayService
import org.json.JSONObject

/**
 * Re-arms everything after a reboot:
 * 1. Re-schedules reminders via a headless Flutter engine (alarms are
 *    cleared by Android on reboot).
 * 2. Re-schedules the "remind me if I have not counted today" alarm.
 * 3. Restarts the overlay when "auto-start after reboot" is on and the
 *    overlay was running. On Android 12+ a foreground service cannot always
 *    be started from the background, so on failure a tap-to-resume
 *    notification is shown instead - never a crash.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            return
        }

        // 1. Reminders (headless Dart re-schedules everything).
        val handle = Prefs.getLong(context, "zikr.bootCallback", 0L)
        val reminders = Prefs.getString(context, "zikr.reminders")
        if (handle != 0L && !reminders.isNullOrEmpty() && reminders != "[]") {
            HeadlessBoot.run(context, handle)
        }

        // 2. Conditional "not counted today" alarm.
        ConditionalReminderReceiver.rescheduleIfEnabled(context)

        // 3. Overlay auto-start.
        val settings = Prefs.getJson(context, "zikr.settings") ?: JSONObject()
        val autoStart = settings.optBoolean("autoStartOnBoot", false)
        val wasRunning = Prefs.getBool(context, "zikr.overlay.running", false)
        if (autoStart && wasRunning) {
            val mode = Prefs.getString(context, "zikr.overlay.mode", "bubble") ?: "bubble"
            val strings = Prefs.getString(context, "zikr.overlay.strings")
            val start = Intent(context, OverlayService::class.java)
                .setAction(OverlayService.ACTION_START)
                .putExtra(OverlayService.EXTRA_MODE, mode)
            if (strings != null) {
                start.putExtra(OverlayService.EXTRA_STRINGS, strings)
            }
            try {
                ContextCompat.startForegroundService(context, start)
            } catch (_: Exception) {
                showResumeNotification(context)
            }
        }
    }

    private fun showResumeNotification(context: Context) {
        val channelId = "zikr_boot"
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                val nm = context.getSystemService(NotificationManager::class.java)
                nm.createNotificationChannel(
                    NotificationChannel(
                        channelId,
                        "Counter resume",
                        NotificationManager.IMPORTANCE_HIGH
                    )
                )
            }
            val open = PendingIntent.getService(
                context, 42,
                Intent(context, OverlayService::class.java)
                    .setAction(OverlayService.ACTION_START)
                    .putExtra(
                        OverlayService.EXTRA_MODE,
                        Prefs.getString(context, "zikr.overlay.mode", "bubble")
                    ),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val notif = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_stat_bead)
                .setContentTitle("Tasbeeh counter")
                .setContentText("Tap to resume the on-screen counter")
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            val nm = ContextCompat.getSystemService(context, NotificationManager::class.java)
            nm?.notify(4242, notif)
        } catch (_: Exception) {
        }
    }
}
