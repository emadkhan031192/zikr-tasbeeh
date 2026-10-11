package com.afzal.zikrtasbeeh.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.LinearGradient
import android.graphics.PixelFormat
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat
import com.afzal.zikrtasbeeh.CounterNative
import com.afzal.zikrtasbeeh.MainActivity
import com.afzal.zikrtasbeeh.Prefs
import com.afzal.zikrtasbeeh.R
import org.json.JSONObject
import kotlin.math.abs

/**
 * The on-screen counter: a foreground service hosting a WindowManager overlay
 * with three modes (bubble / panel / fullscreen).
 *
 * Counts are shared with the Flutter app through SharedPreferences, so taps
 * keep working (and are saved) even when the main app was killed.
 */
class OverlayService : Service() {

    companion object {
        const val ACTION_START = "com.afzal.zikrtasbeeh.overlay.START"
        const val ACTION_STOP = "com.afzal.zikrtasbeeh.overlay.STOP"
        const val ACTION_INC = "com.afzal.zikrtasbeeh.overlay.INC"
        const val ACTION_TOGGLE = "com.afzal.zikrtasbeeh.overlay.TOGGLE"
        const val ACTION_SET_MODE = "com.afzal.zikrtasbeeh.overlay.SET_MODE"
        const val ACTION_REFRESH = "com.afzal.zikrtasbeeh.overlay.REFRESH"
        const val ACTION_APP_FG = "com.afzal.zikrtasbeeh.overlay.APP_FG"
        const val EXTRA_MODE = "mode"
        const val EXTRA_STRINGS = "strings"
        const val EXTRA_IN_FG = "inForeground"

        const val NOTIF_ID = 1001
        const val CHANNEL_ID = "zikr_overlay"

        @Volatile var running = false

        /** Called by ZikrApplication when the main app goes to foreground/background. */
        fun appForeground(context: Context, inForeground: Boolean) {
            if (!running) return
            val i = Intent(context, OverlayService::class.java)
                .setAction(ACTION_APP_FG)
                .putExtra(EXTRA_IN_FG, inForeground)
            try {
                context.startService(i)
            } catch (_: Exception) {
            }
        }

        fun refresh(context: Context) {
            if (!running) return
            try {
                context.startService(
                    Intent(context, OverlayService::class.java).setAction(ACTION_REFRESH)
                )
            } catch (_: Exception) {
            }
        }
    }

    private lateinit var wm: WindowManager
    private var bubbleView: View? = null
    private var panelView: View? = null
    private var fullscreenView: View? = null
    private var currentMode = "bubble"
    private var overlayVisible = true
    private var appInForeground = false
    private var strings = JSONObject()
    private val density: Float by lazy { resources.displayMetrics.density }

    // ------------------------------------------------------------------ lifecycle

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == null) {
            // The system restarted the service: restore the previous mode.
            currentMode =
                Prefs.getString(this, "zikr.overlay.mode", "bubble") ?: "bubble"
            Prefs.getString(this, "zikr.overlay.strings")?.let {
                try {
                    strings = JSONObject(it)
                } catch (_: Exception) {
                }
            }
            startOverlay()
            return START_STICKY
        }
        // If the permission was revoked while running, stop gracefully.
        if (!Settings.canDrawOverlays(this) &&
            action != ACTION_STOP && action != ACTION_APP_FG
        ) {
            stopOverlay()
            return START_NOT_STICKY
        }
        when (action) {
            ACTION_START -> {
                currentMode = intent.getStringExtra(EXTRA_MODE) ?: "bubble"
                intent.getStringExtra(EXTRA_STRINGS)?.let {
                    try {
                        strings = JSONObject(it)
                    } catch (_: Exception) {
                    }
                }
                startOverlay()
            }
            ACTION_STOP -> stopOverlay()
            ACTION_INC -> {
                CounterNative.addCount(this, 1)
                refreshViews()
                updateNotification()
            }
            ACTION_TOGGLE -> {
                overlayVisible = !overlayVisible
                applyVisibility()
                updateNotification()
            }
            ACTION_SET_MODE -> {
                val mode = intent.getStringExtra(EXTRA_MODE) ?: return START_STICKY
                setMode(mode)
            }
            ACTION_REFRESH -> {
                refreshViews()
                applyVisibility()
                updateNotification()
            }
            ACTION_APP_FG -> {
                appInForeground = intent.getBooleanExtra(EXTRA_IN_FG, false)
                applyVisibility()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        removeAllViews()
        running = false
        Prefs.putBool(this, "zikr.overlay.running", false)
        super.onDestroy()
    }

    // ------------------------------------------------------------------ start/stop

    private fun startOverlay() {
        if (!Settings.canDrawOverlays(this)) return
        removeAllViews()
        Prefs.putBool(this, "zikr.overlay.running", true)
        Prefs.putString(this, "zikr.overlay.mode", currentMode)
        Prefs.putString(this, "zikr.overlay.strings", strings.toString())
        startForegroundService()
        running = true
        overlayVisible = true
        applyVisibility()
        refreshViews()
        updateNotification()
    }

    private fun stopOverlay() {
        removeAllViews()
        running = false
        Prefs.putBool(this, "zikr.overlay.running", false)
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
        }
        stopSelf()
    }

    private fun startForegroundService() {
        val notif = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(
                    NOTIF_ID, notif,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIF_ID, notif)
            }
        } catch (_: Exception) {
            // POST_NOTIFICATIONS denied etc. - keep the overlay best-effort
            try {
                if (Build.VERSION.SDK_INT >= 29) {
                    startForeground(
                        NOTIF_ID, notif,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(NOTIF_ID, notif)
                }
            } catch (_: Exception) {
            }
        }
    }

    // ------------------------------------------------------------------ views

    private fun removeAllViews() {
        bubbleView?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        panelView?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        fullscreenView?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        bubbleView = null
        panelView = null
        fullscreenView = null
    }

    private fun applyVisibility() {
        val settings = Prefs.getJson(this, "zikr.settings") ?: JSONObject()
        val hideInApp = settings.optBoolean("hideOverlayInApp", true)
        val shouldShow = overlayVisible && !(appInForeground && hideInApp)
        if (shouldShow) {
            when (currentMode) {
                "bubble" -> if (bubbleView == null) showBubble()
                "panel" -> if (panelView == null) showPanel()
                "fullscreen" -> if (fullscreenView == null) showFullscreen()
            }
        } else {
            removeAllViews()
        }
    }

    private fun setMode(mode: String) {
        if (mode == currentMode && (bubbleView != null || panelView != null || fullscreenView != null)) {
            return
        }
        currentMode = mode
        Prefs.putString(this, "zikr.overlay.mode", mode)
        removeAllViews()
        overlayVisible = true
        applyVisibility()
        refreshViews()
    }

    private fun baseParams(width: Int, height: Int): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            width, height,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
    }

    private fun savedPos(defaultX: Int, defaultY: Int): Pair<Int, Int> {
        val pos = Prefs.getJson(this, "zikr.overlay.pos")
        return if (pos != null) {
            Pair(pos.optInt("x", defaultX), pos.optInt("y", defaultY))
        } else {
            Pair(defaultX, defaultY)
        }
    }

    private fun savePos(x: Int, y: Int) {
        Prefs.putJson(this, "zikr.overlay.pos", JSONObject().put("x", x).put("y", y))
    }

    private fun screenSize(): Pair<Int, Int> {
        val dm = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getMetrics(dm)
        return Pair(dm.widthPixels, dm.heightPixels)
    }

    // --------------------------------------------------------------- bubble

    private fun showBubble() {
        val v = LayoutInflater.from(this).inflate(R.layout.overlay_bubble, null)
        val (sw, sh) = screenSize()
        val margin = (16 * density).toInt()
        val (dx, dy) = savedPos(sw - (104 * density).toInt() - margin, (sh * 0.35).toInt())
        val params = baseParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        params.x = dx
        params.y = dy
        val settings = Prefs.getJson(this, "zikr.settings") ?: JSONObject()
        val sizeScale = settings.optDouble("bubbleSize", 1.0).toFloat()
        val opacity = settings.optDouble("bubbleOpacity", 1.0).toFloat()
        v.scaleX = sizeScale
        v.scaleY = sizeScale
        v.alpha = opacity.coerceIn(0.3f, 1f)
        makeDraggable(v, params,
            onTap = {
                CounterNative.addCount(this, 1)
                refreshViews()
                updateNotification()
            },
            onLongPress = { setMode("panel") },
            snapToEdge = settings.optBoolean("snapToEdge", true),
            viewWidthPx = (104 * density * sizeScale).toInt()
        )
        try {
            wm.addView(v, params)
        } catch (_: Exception) {
            return
        }
        bubbleView = v
    }

    // ---------------------------------------------------------------- panel

    private fun showPanel() {
        val v = LayoutInflater.from(this).inflate(R.layout.overlay_panel, null)
        val (sw, sh) = screenSize()
        val panelW = (300 * density).toInt()
        val (dx, dy) = savedPos((sw - panelW) / 2, (sh * 0.2).toInt())
        val params = baseParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        params.x = dx
        params.y = dy
        val settings = Prefs.getJson(this, "zikr.settings") ?: JSONObject()
        if (settings.optBoolean("tapThroughWhenDimmed", false) &&
            settings.optDouble("bubbleOpacity", 1.0) < 0.999
        ) {
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        val header = v.findViewById<View>(R.id.panel_header)
        makeDraggable(header, params, onTap = null, onLongPress = null,
            snapToEdge = false, viewWidthPx = panelW, hostView = v)

        v.findViewById<View>(R.id.panel_minus).setOnClickListener {
            CounterNative.addCount(this, -1)
            refreshViews()
            updateNotification()
        }
        v.findViewById<View>(R.id.panel_plus).setOnClickListener {
            CounterNative.addCount(this, 1)
            refreshViews()
            updateNotification()
        }
        v.findViewById<View>(R.id.panel_reset).setOnClickListener {
            if (CounterNative.isResetLocked(this)) {
                Toast.makeText(this, "Reset is locked", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            CounterNative.resetCount(this)
            refreshViews()
            updateNotification()
        }
        v.findViewById<View>(R.id.panel_minimize).setOnClickListener {
            setMode("bubble")
        }
        v.findViewById<View>(R.id.panel_close).setOnClickListener {
            stopOverlay()
        }
        try {
            wm.addView(v, params)
        } catch (_: Exception) {
            return
        }
        panelView = v
    }

    // ----------------------------------------------------------- fullscreen

    private fun showFullscreen() {
        val v = LayoutInflater.from(this).inflate(R.layout.overlay_fullscreen, null)
        val params = baseParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT
        )
        params.flags = params.flags or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        val settings = Prefs.getJson(this, "zikr.settings") ?: JSONObject()
        if (settings.optBoolean("tapThroughWhenDimmed", false) &&
            settings.optDouble("bubbleOpacity", 1.0) < 0.999
        ) {
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        v.setOnClickListener {
            CounterNative.addCount(this, readStep())
            refreshViews()
            updateNotification()
        }
        v.findViewById<ImageButton>(R.id.fs_close).setOnClickListener {
            setMode("panel")
        }
        try {
            wm.addView(v, params)
        } catch (_: Exception) {
            return
        }
        fullscreenView = v
    }

    private fun readStep(): Int {
        val settings = Prefs.getJson(this, "zikr.settings") ?: JSONObject()
        return settings.optInt("stepSize", 1).coerceIn(1, 1000)
    }

    // ----------------------------------------------------------------- drag

    private fun makeDraggable(
        view: View,
        params: WindowManager.LayoutParams,
        onTap: (() -> Unit)?,
        onLongPress: (() -> Unit)?,
        snapToEdge: Boolean,
        viewWidthPx: Int,
        hostView: View = view
    ) {
        val handler = Handler(Looper.getMainLooper())
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        var longFired = false
        val longTask = Runnable {
            if (!moved) {
                longFired = true
                onLongPress?.invoke()
            }
        }
        view.setOnTouchListener { _, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = ev.rawX
                    downY = ev.rawY
                    startX = params.x
                    startY = params.y
                    moved = false
                    longFired = false
                    if (onLongPress != null) handler.postDelayed(longTask, 550)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = ev.rawX - downX
                    val dy = ev.rawY - downY
                    if (!moved && (abs(dx) > slop || abs(dy) > slop)) {
                        moved = true
                        handler.removeCallbacks(longTask)
                    }
                    if (moved) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        try {
                            wm.updateViewLayout(hostView, params)
                        } catch (_: Exception) {
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    handler.removeCallbacks(longTask)
                    if (moved) {
                        if (snapToEdge) {
                            val (sw, _) = screenSize()
                            val margin = (12 * density).toInt()
                            params.x = if (params.x + viewWidthPx / 2 < sw / 2) {
                                margin
                            } else {
                                sw - viewWidthPx - margin
                            }
                            try {
                                wm.updateViewLayout(hostView, params)
                            } catch (_: Exception) {
                            }
                        }
                        savePos(params.x, params.y)
                    } else if (!longFired) {
                        onTap?.invoke()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    handler.removeCallbacks(longTask)
                    true
                }
                else -> false
            }
        }
    }

    // ---------------------------------------------------------------- refresh

    private fun refreshViews() {
        if (!Settings.canDrawOverlays(this)) {
            stopOverlay()
            return
        }
        val snap = CounterNative.readSnapshot(this)
        val settings = snap.settings
        val theme = settings.optString("theme", "cyan")
        val digitSize = settings.optString("digitSize", "normal")
        val scale = when (digitSize) {
            "small" -> 0.78f
            "large" -> 1.18f
            else -> 1.0f
        }
        val showArabic = settings.optBoolean("showArabic", true)

        bubbleView?.findViewById<TextView>(R.id.bubble_count)?.let {
            it.text = "${snap.state.count}"
        }

        panelView?.let { v ->
            v.findViewById<TextView>(R.id.panel_arabic)?.let {
                it.visibility = if (showArabic) View.VISIBLE else View.GONE
                it.text = snap.arabic
            }
            v.findViewById<TextView>(R.id.panel_name)?.text = snap.transliteration
            v.findViewById<TextView>(R.id.panel_count)?.let {
                it.text = "${snap.state.count}"
                styleNeon(it, theme, digitBasePx(snap.state.count) * 0.52f * scale)
            }
            val reached = snap.state.count >= snap.state.target && snap.state.target > 0
            val progressText = strings.optString("progressOf", "{c} of {t}")
                .replace("{c}", "${snap.state.count}")
                .replace("{t}", "${snap.state.target}")
            v.findViewById<TextView>(R.id.panel_progress_text)?.text = progressText
            v.findViewById<ProgressBar>(R.id.panel_progress)?.let {
                it.max = snap.state.target.coerceAtLeast(1)
                it.progress = snap.state.count.coerceAtMost(it.max)
            }
            v.findViewById<TextView>(R.id.panel_status)?.let {
                if (reached) {
                    it.text = strings.optString("targetReached", "Target reached")
                    it.setTextColor(0xFF35E08A.toInt())
                } else {
                    val toGo = (snap.state.target - snap.state.count).coerceAtLeast(0)
                    it.text = strings.optString("toGoFmt", "{n} to go")
                        .replace("{n}", "$toGo")
                    it.setTextColor(0xFF8A94A8.toInt())
                }
            }
            v.findViewById<TextView>(R.id.panel_round)?.let {
                if (snap.state.rounds > 0) {
                    it.visibility = View.VISIBLE
                    it.text = "${strings.optString("roundLabel", "Round")} ${snap.state.rounds + 1}"
                } else {
                    it.visibility = View.GONE
                }
            }
        }

        fullscreenView?.findViewById<TextView>(R.id.fs_count)?.let {
            it.text = "${snap.state.count}"
            styleNeon(it, theme, digitBasePx(snap.state.count) * scale)
        }
    }

    /** Base digit size in px, mirroring the design spec (200/170/128/104/86). */
    private fun digitBasePx(value: Int): Float {
        val base = when ("$value".length) {
            1, 2 -> 200f
            3 -> 170f
            4 -> 128f
            5 -> 104f
            else -> 86f
        }
        return base * density
    }

    private fun themeColors(name: String): Triple<Int, Int, Int> {
        return when (name) {
            "green" -> Triple(0xFF3DFF88.toInt(), 0xFF00A651.toInt(), 0xFF3DFF88.toInt())
            "orange" -> Triple(0xFFFFC53D.toInt(), 0xFFFF6A00.toInt(), 0xFFFFB020.toInt())
            "purple" -> Triple(0xFFD18BFF.toInt(), 0xFF7A2BFF.toInt(), 0xFFB45CFF.toInt())
            else -> Triple(0xFF22F5FF.toInt(), 0xFF0A74FF.toInt(), 0xFF22F5FF.toInt())
        }
    }

    private fun styleNeon(tv: TextView, theme: String, sizePx: Float) {
        val (top, bottom, glow) = themeColors(theme)
        try {
            tv.typeface = ResourcesCompat.getFont(this, R.font.nunito_black)
        } catch (_: Exception) {
        }
        tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, sizePx)
        tv.setLayerType(View.LAYER_TYPE_SOFTWARE, null)
        tv.setShadowLayer(sizePx * 0.13f, 0f, 0f, glow)
        tv.post {
            try {
                val h = tv.height.toFloat().coerceAtLeast(sizePx)
                tv.paint.shader = LinearGradient(
                    0f, 0f, 0f, h,
                    intArrayOf(top, bottom), null, Shader.TileMode.CLAMP
                )
                tv.invalidate()
            } catch (_: Exception) {
            }
        }
    }

    // ------------------------------------------------------------ notification

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            val ch = NotificationChannel(
                CHANNEL_ID,
                "On-screen counter",
                NotificationManager.IMPORTANCE_LOW
            )
            ch.setShowBadge(false)
            try {
                nm.createNotificationChannel(ch)
            } catch (_: Exception) {
            }
        }
    }

    private fun actionIntent(action: String, requestCode: Int): PendingIntent {
        val i = Intent(this, OverlayService::class.java).setAction(action)
        return PendingIntent.getService(
            this, requestCode, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildNotification(): Notification {
        val snap = CounterNative.readSnapshot(this)
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val toggleLabel = if (overlayVisible) {
            strings.optString("hide", "Hide")
        } else {
            strings.optString("show", "Show")
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_bead)
            .setContentTitle(strings.optString("title", "Tasbeeh counter"))
            .setContentText("${snap.state.count} · ${snap.transliteration}")
            .setContentIntent(openApp)
            .setOngoing(true)
            .setShowWhen(false)
            .addAction(0, strings.optString("plusOne", "+1"), actionIntent(ACTION_INC, 1))
            .addAction(0, toggleLabel, actionIntent(ACTION_TOGGLE, 2))
            .addAction(0, strings.optString("stop", "Stop"), actionIntent(ACTION_STOP, 3))
            .build()
    }

    private fun updateNotification() {
        if (!running) return
        try {
            val nm = ContextCompat.getSystemService(this, NotificationManager::class.java)
            nm?.notify(NOTIF_ID, buildNotification())
        } catch (_: Exception) {
        }
    }
}
