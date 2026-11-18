package com.recover.angola

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.database.Cursor
import android.os.*
import android.provider.CallLog
import android.provider.Telephony
import android.provider.BlockedNumberContract
import android.os.Environment
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.recover.angola/forense"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanRealFiles" -> result.success(scanRealFiles(call.argument<Boolean>("deepScan") ?: false))
                "getTopContacts" -> result.success(getTopContacts())
                "getSms" -> result.success(getRealSms(call.argument<Int>("limit") ?: 100))
                "getBatteryReal" -> result.success(getBatteryReal())
                "checkRootAndSpyware" -> result.success(checkRootAndSpyware())
                else -> result.notImplemented()
            }
        }
    }

    // ============ VARREDURA REAL DO DISCO ============
    private fun scanRealFiles(deepScan: Boolean): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        val sd = Environment.getExternalStorageDirectory()

        // 1. Lixeira oculta .thumbnails - SEMPRE existe
        val thumbDir = File(sd, "DCIM/.thumbnails")
        if (thumbDir.exists()) {
            thumbDir.listFiles()?.forEach { f ->
                if (f.isFile && f.length() > 1024) {
                    results.add(mapOf("path" to f.absolutePath, "source" to ".thumbnails", "type" to "image"))
                }
            }
        }

        // 2. WhatsApp cache e databases
        val waPaths = listOf(
            "WhatsApp/Media/.Statuses",
            "WhatsApp/Media/WhatsApp Images/Sent",
            "WhatsApp/Media/WhatsApp Video/Sent",
            "Android/media/com.whatsapp/WhatsApp/Media",
            "Telegram/Telegram Images",
            "Telegram/Telegram Video"
        )
        waPaths.forEach { p ->
            val dir = File(sd, p)
            if (dir.exists()) {
                dir.listFiles()?.forEach { f ->
                    if (f.isFile && f.length() > 2048) {
                        results.add(mapOf("path" to f.absolutePath, "source" to "whatsapp_cache", "type" to "media"))
                    }
                }
            }
        }

        // 3. Documentos escondidos
        val hiddenRoots = listOf("Download", "Documents", ".hidden", "DCIM/Camera")
        hiddenRoots.forEach { r ->
            val dir = File(sd, r)
            if (dir.exists()) {
                dir.walkTopDown().maxDepth(2).forEach { f ->
                    if (f.isFile && f.name.startsWith(".") || f.name.contains("temp")) {
                        results.add(mapOf("path" to f.absolutePath, "source" to "hidden", "type" to "doc"))
                    }
                }
            }
        }

        // 4. COM ROOT - lê /data/media/0 que é o disco cru
        if (deepScan && isDeviceRooted()) {
            val rawData = File("/data/media/0/DCIM")
            if (rawData.exists()) {
                rawData.walkTopDown().maxDepth(4).forEach { f ->
                    if (f.isFile && f.length() > 5000 && isImageOrVideo(f.name)) {
                        results.add(mapOf("path" to f.absolutePath, "source" to "RAW_DISK", "type" to "forense_total"))
                    }
                }
            }
            // Também /data/system_ce para SMS deletados se root
            val smsDb = File("/data/data/com.android.providers.telephony/databases/mmssms.db")
            if (smsDb.exists()) {
                results.add(mapOf("path" to smsDb.absolutePath, "source" to "SMS_DB_RAW", "type" to "database"))
            }
        }

        return results.take(300) // limita para não travar
    }

    private fun isImageOrVideo(name: String): Boolean {
        val lower = name.lowercase()
        return lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png") || lower.endsWith(".mp4") || lower.endsWith(".webp")
    }

    // ============ TOP 5 NÚMEROS - CallLog REAL ============
    private fun getTopContacts(): List<Map<String, Any>> {
        val mapCount = mutableMapOf<String, MutableMap<String, Any>>()
        try {
            val cursor: Cursor? = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.CACHED_NAME, CallLog.Calls.DATE, CallLog.Calls.DURATION),
                null, null, CallLog.Calls.DATE + " DESC"
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val number = it.getString(it.getColumnIndexOrThrow(CallLog.Calls.NUMBER))
                    val name = it.getString(it.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME))
                    val date = it.getLong(it.getColumnIndexOrThrow(CallLog.Calls.DATE))
                    if (number != null) {
                        val entry = mapCount.getOrPut(number) {
                            mutableMapOf("number" to number, "name" to (name ?: number), "count" to 0, "lastCall" to date, "blocked" to isNumberBlocked(number))
                        }
                        entry["count"] = (entry["count"] as Int) + 1
                        if (date > (entry["lastCall"] as Long)) entry["lastCall"] = date
                    }
                }
            }
        } catch (e: SecurityException) {
            // permissão negada
        }
        return mapCount.values.sortedByDescending { it["count"] as Int }.take(15).toList()
    }

    private fun isNumberBlocked(number: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val cursor = contentResolver.query(BlockedNumberContract.BlockedNumbers.CONTENT_URI, arrayOf(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER), null, null, null)
                cursor?.use {
                    while (it.moveToNext()) {
                        val blocked = it.getString(0)
                        if (blocked == number) return true
                    }
                }
            }
            false
        } catch (_: Exception) { false }
    }

    // ============ SMS REAL ============
    private fun getRealSms(limit: Int): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val cursor = contentResolver.query(Telephony.Sms.CONTENT_URI, arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE, Telephony.Sms.TYPE), null, null, Telephony.Sms.DATE + " DESC LIMIT $limit")
            cursor?.use {
                while (it.moveToNext()) {
                    val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS))
                    val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY))
                    val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    val type = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE))
                    list.add(mapOf("address" to (address ?: ""), "body" to (body ?: ""), "date" to date, "type" to type))
                }
            }
        } catch (e: Exception) { }
        return list
    }

    private fun getBatteryReal(): Map<String, Any> {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val health = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1
        return mapOf(
            "level" to level,
            "isCharging" to (bm.isCharging),
            "health" to when(health) { BatteryManager.BATTERY_HEALTH_GOOD -> "GOOD" else -> "UNKNOWN" }
        )
    }

    // ============ ROOT + SPYWARE ============
    private fun checkRootAndSpyware(): Map<String, Any> {
        val isRooted = isDeviceRooted()
        var hasSpyware = false
        val suspicious = mutableListOf<String>()
        try {
            val pm = packageManager
            val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            for (app in apps) {
                // apps com accessibility
                try {
                    val hasAccess = pm.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS).requestedPermissions?.contains("android.permission.BIND_ACCESSIBILITY_SERVICE") == true
                    if (hasAccess && (app.flags and ApplicationInfo.FLAG_SYSTEM) == 0) {
                        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
                        if (enabled.contains(app.packageName)) {
                            hasSpyware = true
                            suspicious.add(app.packageName)
                        }
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}

        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        val deviceInfo = mapOf(
            "isRooted" to isRooted,
            "hasSpyware" to hasSpyware,
            "suspiciousPackages" to suspicious,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdk" to Build.VERSION.SDK_INT,
            "androidId" to androidId,
            "batteryHealth" to "Real via BatteryManager"
        )
        return deviceInfo
    }

    private fun isDeviceRooted(): Boolean {
        val paths = arrayOf("/system/app/Superuser.apk", "/sbin/su", "/system/bin/su", "/system/xbin/su", "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su")
        if (paths.any { File(it).exists() }) return true
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val reader = process.inputStream.bufferedReader()
            reader.readLine() != null
        } catch (_: Exception) { false } finally { process?.destroy() }
    }
}
