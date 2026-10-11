package com.afzal.zikrtasbeeh

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.util.Calendar

/**
 * "Remind me if I have not counted today": a native daily exact alarm that
 * checks the last-count date and only then posts a notification. This
 * condition cannot be evaluated by a pre-scheduled notification, so it lives
 * outside flutter_local_notifications.
 */
class ConditionalReminderReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_CHECK = "com.afzal.zikrtasbeeh.COND_CHECK"
        const val ACTION_SNOOZE_FIRE = "com.afzal.zikrtasbeeh.COND_SNOOZE_FIRE"
        const val NOTIF_ID = 2001
        const val CHANNEL_ID = "zikr_reminders"

        fun readConfig(context: Context): JSONObject? =
            Prefs.getJson(context, "zikr.conditional")

        fun isEnabled(context: Context): Boolean =
            readConfig(context)?.optBoolean("enabled", false) == true

        fun rescheduleIfEnabled(context: Context) {
            val cfg = readConfig(context) ?: return
            if (cfg.optBoolean("enabled", false)) {
                schedule(
                    context,
                    cfg.optInt("hour", 21),
                    cfg.optInt("minute", 0)
                )
            }
        }

        fun schedule(context: Context, hour: Int, minute: Int) {
            cancel(context)
            val trigger = nextTrigger(hour, minute)
            val am = context.getSystemService(AlarmManager::class.java) ?: return
            val pi = PendingIntent.getBroadcast(
                context, 7001,
                Intent(context, ConditionalReminderReceiver::class.java)
                    .setAction(ACTION_CHECK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                if (Build.VERSION.SDK_INT >= 31 && am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                } else {
                    @Suppress("DEPRECATION")
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                }
            } catch (_: SecurityException) {
                try {
                    @Suppress("DEPRECATION")
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                } catch (_: Exception) {
                }
            }
        }

        fun snoozeOnce(context: Context, minutes: Int) {
            val trigger = System.currentTimeMillis() + minutes * 60_000L
            val am = context.getSystemService(AlarmManager::class.java) ?: return
            val pi = PendingIntent.getBroadcast(
                context, 7002,
                Intent(context, ConditionalReminderReceiver::class.java)
                    .setAction(ACTION_SNOOZE_FIRE),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                if (Build.VERSION.SDK_INT >= 31 && am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                } else {
                    @Suppress("DEPRECATION")
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                }
            } catch (_: Exception) {
            }
        }

        fun cancel(context: Context) {
            val am = context.getSystemService(AlarmManager::class.java) ?: return
            for (req in listOf(7001, 7002)) {
                val pi = PendingIntent.getBroadcast(
                    context, req,
                    Intent(context, ConditionalReminderReceiver::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.cancel(pi)
                pi.cancel()
            }
        }

        private fun nextTrigger(hour: Int, minute: Int): Long {
            val cal = Calendar.getInstance()
            cal.set(Calendar.HOUR_OF_DAY, hour)
            cal.set(Calendar.MINUTE, minute)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            if (cal.timeInMillis <= System.currentTimeMillis()) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            return cal.timeInMillis
        }

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                try {
                    val nm = context.getSystemService(NotificationManager::class.java)
                    nm.createNotificationChannel(
                        NotificationChannel(
                            CHANNEL_ID,
                            "Dhikr reminders",
                            NotificationManager.IMPORTANCE_HIGH
                        )
                    )
                } catch (_: Exception) {
                }
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_CHECK -> {
                // Re-arm for tomorrow first, then evaluate today's condition.
                rescheduleIfEnabled(context)
                val last = Prefs.getString(context, "zikr.lastCountDate")
                if (last != Prefs.todayKey()) {
                    showNotification(context)
                }
            }
            ACTION_SNOOZE_FIRE -> showNotification(context)
        }
    }

    private fun showNotification(context: Context) {
        ensureChannel(context)
        val cfg = readConfig(context) ?: JSONObject()
        val title = cfg.optString("title", "Time for dhikr").ifEmpty { "Time for dhikr" }
        val body = cfg.optString("body", "").ifEmpty { "You have not counted today yet." }
        val snoozeMin = cfg.optInt("snoozeMin", 10)

        val openApp = PendingIntent.getActivity(
            context, 7101,
            Intent(context, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra("payload", """{"kind":"conditional"}"""),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val done = PendingIntent.getBroadcast(
            context, 7102,
            Intent(context, ConditionalActionReceiver::class.java)
                .setAction(ConditionalActionReceiver.ACTION_DONE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val snooze = PendingIntent.getBroadcast(
            context, 7103,
            Intent(context, ConditionalActionReceiver::class.java)
                .setAction(ConditionalActionReceiver.ACTION_SNOOZE)
                .putExtra(ConditionalActionReceiver.EXTRA_MINUTES, snoozeMin),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_bead)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(openApp)
            .setAutoCancel(true)
            .addAction(0, "Done", done)
            .addAction(0, "Snooze", snooze)
            .build()
        try {
            val nm = ContextCompat.getSystemService(context, NotificationManager::class.java)
            nm?.notify(NOTIF_ID, notif)
        } catch (_: Exception) {
        }
    }
}

/** Handles the Done / Snooze actions of the conditional reminder. */
class ConditionalActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DONE = "com.afzal.zikrtasbeeh.COND_DONE"
        const val ACTION_SNOOZE = "com.afzal.zikrtasbeeh.COND_SNOOZE"
        const val EXTRA_MINUTES = "minutes"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_DONE -> {
                try {
                    val nm = ContextCompat.getSystemService(
                        context, NotificationManager::class.java
                    )
                    nm?.cancel(ConditionalReminderReceiver.NOTIF_ID)
                } catch (_: Exception) {
                }
            }
            ACTION_SNOOZE -> {
                val minutes = intent.getIntExtra(EXTRA_MINUTES, 10).coerceIn(1, 120)
                ConditionalReminderReceiver.snoozeOnce(context, minutes)
                try {
                    val nm = ContextCompat.getSystemService(
                        context, NotificationManager::class.java
                    )
                    nm?.cancel(ConditionalReminderReceiver.NOTIF_ID)
                } catch (_: Exception) {
                }
            }
        }
    }
}
