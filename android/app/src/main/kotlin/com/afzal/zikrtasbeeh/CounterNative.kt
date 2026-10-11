package com.afzal.zikrtasbeeh

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import org.json.JSONObject

/**
 * Counting logic shared by the overlay service, the accessibility service
 * and the notification actions. Mirrors CounterService.increment/decrement
 * in Dart - the same target rules, history updates and feedback.
 */
object CounterNative {
    const val MAX_COUNT = 999999

    /** Dhikr ids in the same order as the Dart presets. */
    val dhikrOrder = listOf(
        "subhanallah", "alhamdulillah", "allahuakbar", "astaghfirullah",
        "lailahaillallah", "durood", "custom"
    )

    data class CountState(var count: Int, var target: Int, var rounds: Int)

    data class Snapshot(
        val dhikrId: String,
        val state: CountState,
        val settings: JSONObject,
        val transliteration: String,
        val arabic: String
    )

    private val transliterations = mapOf(
        "subhanallah" to "SubhanAllah",
        "alhamdulillah" to "Alhamdulillah",
        "allahuakbar" to "Allahu Akbar",
        "astaghfirullah" to "Astaghfirullah",
        "lailahaillallah" to "La ilaha illallah",
        "durood" to "Durood Sharif",
        "custom" to "Custom"
    )

    private val arabics = mapOf(
        "subhanallah" to "سُبْحَانَ الله",
        "alhamdulillah" to "الْحَمْدُ لِلَّه",
        "allahuakbar" to "اللهُ أَكْبَر",
        "astaghfirullah" to "أَسْتَغْفِرُ الله",
        "lailahaillallah" to "لَا إِلَهَ إِلَّا الله",
        "durood" to "اللَّهُمَّ صَلِّ عَلَى مُحَمَّد",
        "custom" to "ذِكْر"
    )

    fun transliteration(id: String): String = transliterations[id] ?: id
    fun arabic(id: String): String = arabics[id] ?: ""

    fun readSnapshot(context: Context): Snapshot {
        val dhikrId = Prefs.getString(context, "zikr.currentDhikr", "subhanallah")
            ?: "subhanallah"
        val saved = Prefs.getJson(context, "zikr.dhikr.$dhikrId")
        val settings = Prefs.getJson(context, "zikr.settings") ?: JSONObject()
        val state = CountState(
            count = saved?.optInt("count", 0) ?: 0,
            target = saved?.optInt("target", 33) ?: 33,
            rounds = saved?.optInt("rounds", 0) ?: 0
        )
        return Snapshot(dhikrId, state, settings, transliteration(dhikrId), arabic(dhikrId))
    }

    private fun saveState(context: Context, dhikrId: String, s: CountState) {
        val json = JSONObject()
            .put("count", s.count)
            .put("target", s.target)
            .put("rounds", s.rounds)
        Prefs.putJson(context, "zikr.dhikr.$dhikrId", json)
    }

    /**
     * Adds [delta] (may be negative) to the current dhikr, applying target
     * rules, history and feedback. Returns the new snapshot.
     */
    fun addCount(context: Context, delta: Int): Snapshot {
        val snap = readSnapshot(context)
        val s = snap.state
        val oldCount = s.count
        var newCount = (oldCount + delta).coerceIn(0, MAX_COUNT)
        var applied = newCount - oldCount
        val crossed = oldCount < s.target && newCount >= s.target && s.target > 0

        var newDhikrId = snap.dhikrId
        if (crossed) {
            when (snap.settings.optString("onTargetReached", "newRound")) {
                "stop" -> {
                    newCount = s.target
                    applied = newCount - oldCount
                }
                "newRound" -> {
                    s.rounds += 1
                    newCount -= s.target
                }
                "nextDhikr" -> {
                    s.rounds += 1
                    newCount = 0
                    val idx = dhikrOrder.indexOf(snap.dhikrId)
                    newDhikrId = dhikrOrder[(idx + 1).coerceAtLeast(0) % dhikrOrder.size]
                }
            }
        }

        s.count = newCount
        saveState(context, snap.dhikrId, s)
        if (newDhikrId != snap.dhikrId) {
            Prefs.putString(context, "zikr.currentDhikr", newDhikrId)
        }
        if (applied > 0) {
            Prefs.addToHistory(context, applied)
        }

        // Feedback
        val milestoneEvery = snap.settings.optInt("milestoneEvery", 0)
        if (crossed) {
            feedbackTarget(context, snap.settings)
        } else if (applied > 0) {
            if (milestoneEvery > 0 && (newCount / milestoneEvery) > (oldCount / milestoneEvery)) {
                feedbackTap(context, snap.settings, strong = true)
            } else {
                feedbackTap(context, snap.settings, strong = false)
            }
        }
        return readSnapshot(context)
    }

    fun resetCount(context: Context): Snapshot {
        val snap = readSnapshot(context)
        if (snap.settings.optBoolean("lockReset", false)) {
            return snap // locked - caller may toast
        }
        snap.state.count = 0
        saveState(context, snap.dhikrId, snap.state)
        return readSnapshot(context)
    }

    fun isResetLocked(context: Context): Boolean =
        (Prefs.getJson(context, "zikr.settings") ?: JSONObject())
            .optBoolean("lockReset", false)

    // ------------------------------------------------------------- feedback

    private fun vibrator(context: Context): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= 31) {
                context.getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Vibrator::class.java)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun buzz(context: Context, durationMs: Long, strength: Int) {
        val vib = vibrator(context) ?: return
        try {
            if (!vib.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= 26) {
                val amp = intArrayOf(64, 140, 255)[strength.coerceIn(0, 2)]
                vib.vibrate(VibrationEffect.createOneShot(durationMs, amp))
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(durationMs)
            }
        } catch (_: Exception) {
        }
    }

    fun feedbackTap(context: Context, settings: JSONObject, strong: Boolean) {
        if (settings.optBoolean("vibration", true)) {
            buzz(context, if (strong) 80 else 25, settings.optInt("vibrationStrength", 1))
        }
        if (settings.optBoolean("sound", false)) {
            ClickSound.play(context)
        }
    }

    fun feedbackTarget(context: Context, settings: JSONObject) {
        if (settings.optBoolean("longVibrationAtTarget", true)) {
            buzz(context, 450, 2)
        } else {
            feedbackTap(context, settings, strong = false)
            return
        }
        if (settings.optBoolean("sound", false)) {
            ClickSound.play(context)
        }
    }

    /** Tiny click sound played from the bundled Flutter asset. */
    object ClickSound {
        private var pool: SoundPool? = null
        private var soundId: Int = 0
        private var loaded = false

        @Synchronized
        fun play(context: Context) {
            try {
                if (pool == null) {
                    val attrs = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    pool = SoundPool.Builder()
                        .setMaxStreams(2)
                        .setAudioAttributes(attrs)
                        .build()
                    val fd = context.assets.openFd("flutter_assets/assets/sounds/click.wav")
                    soundId = pool!!.load(fd, 1)
                    loaded = true
                }
                if (loaded) {
                    pool?.play(soundId, 1f, 1f, 1, 0, 1f)
                }
            } catch (_: Exception) {
            }
        }
    }
}
