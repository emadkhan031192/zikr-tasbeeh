package com.afzal.zikrtasbeeh

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.util.Calendar

/**
 * Direct access to the Flutter SharedPreferences file.
 *
 * The shared_preferences plugin prefixes every key with "flutter.", so all
 * reads/writes here use that prefix. Keys and JSON shapes mirror
 * lib/services/storage.dart - keep both sides in sync.
 */
object Prefs {
    private const val FILE = "FlutterSharedPreferences"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    private fun k(key: String) = "flutter.$key"

    fun getString(context: Context, key: String, def: String? = null): String? =
        prefs(context).getString(k(key), def)

    fun putString(context: Context, key: String, value: String) {
        prefs(context).edit().putString(k(key), value).apply()
    }

    fun remove(context: Context, key: String) {
        prefs(context).edit().remove(k(key)).apply()
    }

    fun getLong(context: Context, key: String, def: Long = 0L): Long {
        val p = prefs(context)
        return try {
            p.getLong(k(key), def)
        } catch (_: ClassCastException) {
            p.getInt(k(key), def.toInt()).toLong()
        }
    }

    fun putLong(context: Context, key: String, value: Long) {
        prefs(context).edit().putLong(k(key), value).apply()
    }

    fun getBool(context: Context, key: String, def: Boolean = false): Boolean =
        prefs(context).getBoolean(k(key), def)

    fun putBool(context: Context, key: String, value: Boolean) {
        prefs(context).edit().putBoolean(k(key), value).apply()
    }

    fun getJson(context: Context, key: String): JSONObject? {
        val raw = getString(context, key) ?: return null
        if (raw.isEmpty()) return null
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            null
        }
    }

    fun putJson(context: Context, key: String, json: JSONObject) {
        putString(context, key, json.toString())
    }

    fun todayKey(): String {
        val cal = Calendar.getInstance()
        return "%04d-%02d-%02d".format(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH)
        )
    }

    /** Adds [delta] to today's total and the all-time total. */
    fun addToHistory(context: Context, delta: Int) {
        if (delta <= 0) return
        val today = todayKey()
        val history = getJson(context, "zikr.history") ?: JSONObject()
        history.put(today, history.optInt(today, 0) + delta)
        putJson(context, "zikr.history", history)
        putLong(context, "zikr.allTime", getLong(context, "zikr.allTime") + delta)
        putString(context, "zikr.lastCountDate", today)
    }
}
