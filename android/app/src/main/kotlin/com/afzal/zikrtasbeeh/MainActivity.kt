package com.afzal.zikrtasbeeh

import android.app.AlarmManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.afzal.zikrtasbeeh.overlay.OverlayService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Hosts the Flutter UI and bridges it to the native overlay, permissions,
 * backup and reminder helpers. Every channel call is defensive: failures
 * return a safe default instead of crashing.
 */
class MainActivity : FlutterActivity() {

    private var pendingPayload: String? = null
    private var importResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_IMPORT_BACKUP = 9001
    }

    @Deprecated("Using classic activity results for maximum compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_IMPORT_BACKUP) return
        val result = importResult
        importResult = null
        if (result == null) return
        try {
            val uri = data?.data
            if (resultCode == RESULT_OK && uri != null) {
                val text = contentResolver.openInputStream(uri)
                    ?.bufferedReader()?.use { it.readText() }
                result.success(text)
            } else {
                result.success(null)
            }
        } catch (_: Exception) {
            result.success(null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.getStringExtra("payload")?.let { pendingPayload = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("payload")?.let { pendingPayload = it }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "zikr_tasbeeh/overlay"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startOverlay" -> {
                    val mode = call.argument<String>("mode") ?: "bubble"
                    if (!Settings.canDrawOverlays(this)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(this, OverlayService::class.java)
                        .setAction(OverlayService.ACTION_START)
                        .putExtra(OverlayService.EXTRA_MODE, mode)
                    val strings: Map<String, String>? =
                        call.argument<Map<String, String>>("strings")
                    if (strings != null) {
                        intent.putExtra(
                            OverlayService.EXTRA_STRINGS,
                            JSONObject(strings).toString()
                        )
                    }
                    try {
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "stopOverlay" -> {
                    try {
                        startService(
                            Intent(this, OverlayService::class.java)
                                .setAction(OverlayService.ACTION_STOP)
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "setOverlayMode" -> {
                    val mode = call.argument<String>("mode") ?: "bubble"
                    OverlayService.refresh(this)
                    try {
                        startService(
                            Intent(this, OverlayService::class.java)
                                .setAction(OverlayService.ACTION_SET_MODE)
                                .putExtra(OverlayService.EXTRA_MODE, mode)
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "refreshOverlay" -> {
                    OverlayService.refresh(this)
                    result.success(null)
                }
                "isOverlayRunning" -> result.success(OverlayService.running)
                "hasOverlayPermission" ->
                    result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    openSettings(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "zikr_tasbeeh/system"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionStatus" -> result.success(permissionStatus())
                "openOverlaySettings" -> {
                    openSettings(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    val i = if (Build.VERSION.SDK_INT >= 26) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.parse("package:$packageName"))
                    }
                    openSettings(i)
                    result.success(null)
                }
                "openExactAlarmSettings" -> {
                    openSettings(
                        Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                "openBatterySettings" -> {
                    openSettings(
                        Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    )
                    result.success(null)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    openSettings(
                        Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    openSettings(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "openAppDetailsSettings" -> {
                    openSettings(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.parse("package:$packageName"))
                    )
                    result.success(null)
                }
                "setKeepScreenAwake" -> {
                    val awake = call.argument<Boolean>("awake") ?: false
                    runOnUiThread {
                        if (awake) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(null)
                }
                "scheduleConditional" -> {
                    val hour = call.argument<Int>("hour") ?: 21
                    val minute = call.argument<Int>("minute") ?: 0
                    val title = call.argument<String>("title") ?: "Time for dhikr"
                    val body = call.argument<String>("body") ?: ""
                    val snoozeMin = call.argument<Int>("snoozeMin") ?: 10
                    Prefs.putJson(
                        this, "zikr.conditional",
                        JSONObject()
                            .put("enabled", true)
                            .put("hour", hour)
                            .put("minute", minute)
                            .put("title", title)
                            .put("body", body)
                            .put("snoozeMin", snoozeMin)
                    )
                    ConditionalReminderReceiver.schedule(this, hour, minute)
                    result.success(null)
                }
                "cancelConditional" -> {
                    Prefs.remove(this, "zikr.conditional")
                    ConditionalReminderReceiver.cancel(this)
                    result.success(null)
                }
                "exportBackup" -> {
                    val json = call.argument<String>("json") ?: ""
                    result.success(exportBackup(json))
                }
                "importBackup" -> {
                    importResult = result
                    try {
                        val pick = Intent(Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*")
                        @Suppress("DEPRECATION")
                        startActivityForResult(pick, REQUEST_IMPORT_BACKUP)
                    } catch (_: Exception) {
                        importResult = null
                        result.success(null)
                    }
                }
                "getAppVersion" -> {
                    val v = try {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0).versionName
                    } catch (_: Exception) {
                        null
                    }
                    result.success(v ?: "1.0.0")
                }
                "takePendingPayload" -> {
                    val p = pendingPayload
                    pendingPayload = null
                    result.success(p)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "zikr_tasbeeh/boot"
        ).setMethodCallHandler { call, result ->
            if (call.method == "bootDone") {
                HeadlessBoot.done()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    // ---------------------------------------------------------------- helpers

    private fun permissionStatus(): Map<String, Boolean> {
        val overlay = try {
            Settings.canDrawOverlays(this)
        } catch (_: Exception) {
            false
        }
        val notifications = try {
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        } catch (_: Exception) {
            false
        }
        val exactAlarm = try {
            if (Build.VERSION.SDK_INT >= 31) {
                getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() ?: false
            } else {
                true
            }
        } catch (_: Exception) {
            false
        }
        val batteryIgnored = try {
            getSystemService(PowerManager::class.java)
                ?.isIgnoringBatteryOptimizations(packageName) ?: false
        } catch (_: Exception) {
            false
        }
        val accessibility = try {
            val flat = ComponentName(
                this, ZikrAccessibilityService::class.java
            ).flattenToString()
            Settings.Secure.getString(
                contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )?.contains(flat) == true
        } catch (_: Exception) {
            false
        }
        return mapOf(
            "overlay" to overlay,
            "notifications" to notifications,
            "exactAlarm" to exactAlarm,
            "batteryIgnored" to batteryIgnored,
            "accessibility" to accessibility
        )
    }

    private fun openSettings(intent: Intent) {
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (_: Exception) {
            // settings page unavailable on this device - stay silent
        }
    }

    private fun exportBackup(json: String): String? {
        if (json.isEmpty()) return null
        val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        val filename = "zikr-tasbeeh-backup-$stamp.json"
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val values = android.content.ContentValues().apply {
                    put(
                        android.provider.MediaStore.Downloads.DISPLAY_NAME,
                        filename
                    )
                    put(
                        android.provider.MediaStore.Downloads.MIME_TYPE,
                        "application/json"
                    )
                    put(
                        android.provider.MediaStore.Downloads.RELATIVE_PATH,
                        "Download/ZikrTasbeeh"
                    )
                }
                val uri = contentResolver.insert(
                    android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values
                ) ?: return null
                contentResolver.openOutputStream(uri)?.use { out ->
                    out.write(json.toByteArray())
                }
                "Download/ZikrTasbeeh/$filename"
            } else {
                @Suppress("DEPRECATION")
                val dir = android.os.Environment.getExternalStoragePublicDirectory(
                    android.os.Environment.DIRECTORY_DOWNLOADS
                )
                val file = java.io.File(dir, filename)
                file.writeText(json)
                file.absolutePath
            }
        } catch (_: Exception) {
            null
        }
    }
}
