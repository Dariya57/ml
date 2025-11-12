package com.example.pp

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.SharedPreferences
import android.util.Log
import android.app.ActivityManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Handler
import android.os.Looper

class AppBlockerService : AccessibilityService() {
    
    companion object {
        private const val TAG = "AppBlockerService"
        private const val PREFS_NAME = "AppBlockerPrefs"
        private const val KEY_BLOCKED_APPS = "blocked_apps"
        private const val CHECK_INTERVAL_MS = 4000L // Редкая фоновая проверка (энергоэффективно)
        
        fun getBlockedApps(context: Context): Set<String> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val blockedAppsJson = prefs.getStringSet(KEY_BLOCKED_APPS, emptySet()) ?: emptySet()
            return blockedAppsJson
        }
        
        fun setBlockedApps(context: Context, packageNames: Set<String>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putStringSet(KEY_BLOCKED_APPS, packageNames).apply()
            Log.d(TAG, "Blocked apps updated: $packageNames")
        }
        
        fun getUnlockedSeconds(context: Context, packageName: String): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getInt("unlocked_seconds_$packageName", 0)
        }

        private fun getUnlockStartTs(context: Context, packageName: String): Long {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getLong("unlock_start_ts_$packageName", 0L)
        }

        private fun setUnlockStartTs(context: Context, packageName: String, ts: Long) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putLong("unlock_start_ts_$packageName", ts).apply()
        }

        private fun clearUnlockStartTs(context: Context, packageName: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove("unlock_start_ts_$packageName").apply()
        }
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var lastCheckedPackage: String? = null
    private var lastCheckTime: Long = 0
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        val packageName = event.packageName?.toString() ?: return
        val eventType = event.eventType
        
        // Логируем ВСЕ события с тегом, чтобы видеть в логах
        Log.w(TAG, "🔔 EVENT: type=$eventType, package=$packageName, className=${event.className}")
        
        // Обрабатываем ВСЕ типы событий, связанные с окнами
        when (eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                Log.w(TAG, "🚪 WINDOW_STATE_CHANGED: $packageName")
                checkAndBlockApp(packageName)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                // Проверяем чаще при изменении контента
                checkAndBlockApp(packageName)
            }
            AccessibilityEvent.TYPE_VIEW_FOCUSED -> {
                // Также проверяем при фокусе
                checkAndBlockApp(packageName)
            }
            else -> {
                // Для остальных событий тоже проверяем, если это окно
                if (packageName.isNotEmpty()) {
                    checkAndBlockApp(packageName)
                }
            }
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.e(TAG, "✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅")
        Log.e(TAG, "✅ AppBlockerService CONNECTED AND READY!")
        Log.e(TAG, "✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅")
        
        // Проверяем список заблокированных приложений
        val blockedApps = getBlockedApps(this)
        Log.e(TAG, "📋 Current blocked apps: $blockedApps (count: ${blockedApps.size})")
        
        if (blockedApps.isEmpty()) {
            Log.e(TAG, "⚠️⚠️⚠️ WARNING: NO APPS ARE BLOCKED! ⚠️⚠️⚠️")
        }
        
        // Запускаем периодическую проверку запущенных приложений
        startPeriodicCheck()
        Log.e(TAG, "✅ Periodic check started")
    }
    
    private fun startPeriodicCheck() {
        Log.d(TAG, "⏰ Starting periodic check every ${CHECK_INTERVAL_MS}ms")
        handler.post(object : Runnable {
            override fun run() {
                checkRunningApps()
                handler.postDelayed(this, CHECK_INTERVAL_MS)
            }
        })
    }
    
    private fun checkRunningApps() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

            // 1) Пытаемся через устаревший API (иногда работает)
            @Suppress("DEPRECATION")
            run {
                try {
                    val runningTasks = activityManager.getRunningTasks(1)
                    if (runningTasks.isNotEmpty()) {
                        val topActivity = runningTasks[0].topActivity
                        val packageName = topActivity?.packageName
                        if (!packageName.isNullOrBlank() && packageName != "com.example.pp") {
                            Log.d(TAG, "📱 Periodic check (getRunningTasks): $packageName")
                            checkAndBlockApp(packageName)
                            return
                        }
                    }
                } catch (_: Throwable) { }
            }

            // 2) Надёжный способ: UsageStatsManager (требует PACKAGE_USAGE_STATS)
            try {
                val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val end = System.currentTimeMillis()
                val start = end - 10_000 // последние 10 секунд
                val events: UsageEvents = usm.queryEvents(start, end)
                var lastPkg: String? = null
                val usageEvent = UsageEvents.Event()
                while (events.hasNextEvent()) {
                    events.getNextEvent(usageEvent)
                    if (usageEvent.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                        usageEvent.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                        lastPkg = usageEvent.packageName
                    }
                }
                if (!lastPkg.isNullOrBlank() && lastPkg != "com.example.pp") {
                    Log.d(TAG, "📱 Periodic check (UsageStats): $lastPkg")
                    checkAndBlockApp(lastPkg!!)
                    // сбрасываем таймеры для неактивных, чтобы время не тратилось в фоне
                    resetInactiveTimers(lastPkg!!)
                }
            } catch (e: Exception) {
                Log.d(TAG, "⚠️ UsageStats check failed: ${e.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in checkRunningApps: ${e.message}", e)
        }
    }
    
    private fun checkAndBlockApp(packageName: String) {
        // Проверяем, не наше ли это приложение
        if (packageName == "com.example.pp" || packageName.isBlank() || packageName == "android") {
            return
        }
        
        // Предотвращаем частые проверки одного и того же приложения (но чаще проверяем)
        val now = System.currentTimeMillis()
        if (packageName == lastCheckedPackage && now - lastCheckTime < 100) {
            return
        }
        
        lastCheckedPackage = packageName
        lastCheckTime = now
        
        Log.d(TAG, "🔍 Checking app: $packageName")
        
        val blockedApps = getBlockedApps(this)
        Log.d(TAG, "📋 Blocked apps list: $blockedApps (size=${blockedApps.size})")
        
        if (blockedApps.isEmpty()) {
            Log.w(TAG, "⚠️ WARNING: Blocked apps list is EMPTY!")
            return
        }
        
        if (blockedApps.contains(packageName)) {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val unlockedSeconds = getUnlockedSeconds(this, packageName)
            Log.d(TAG, "🎯 App $packageName IS BLOCKED! Unlocked seconds: $unlockedSeconds")

            if (unlockedSeconds <= 0) {
                // Время нет — немедленно блокируем
                Log.e(TAG, "🚫🚫🚫 BLOCKING app RIGHT NOW: $packageName 🚫🚫🚫")
                clearUnlockStartTs(this, packageName)
                blockAppImmediately()
            } else {
                // Считаем расход времени на НАТИВЕ, чтобы Flutter в фоне не мешал
                val now = System.currentTimeMillis()
                var startTs = getUnlockStartTs(this, packageName)
                if (startTs == 0L) {
                    startTs = now
                    setUnlockStartTs(this, packageName, startTs)
                }
                val elapsedSec = ((now - startTs) / 1000).toInt().coerceAtLeast(0)
                val remaining = unlockedSeconds - elapsedSec
                if (remaining <= 0) {
                    prefs.edit().putInt("unlocked_seconds_$packageName", 0).apply()
                    clearUnlockStartTs(this, packageName)
                    Log.e(TAG, "⏳ Time exhausted for $packageName → blocking")
                    blockAppImmediately()
                } else {
                    // Обновляем остаток в префсах, чтобы Dart видел актуальное значение
                    prefs.edit().putInt("unlocked_seconds_$packageName", remaining).apply()
                    Log.d(TAG, "⏱ Remaining for $packageName: $remaining s")
                }
            }
        } else {
            Log.d(TAG, "✓ App $packageName is NOT in blocked list")
        }
    }

    // Сбрасываем таймеры расхода для всех приложений, которые сейчас не в фокусе
    private fun resetInactiveTimers(activePackage: String) {
        val blocked = getBlockedApps(this)
        for (pkg in blocked) {
            if (pkg != activePackage) {
                clearUnlockStartTs(this, pkg)
            }
        }
    }
    
    private fun blockAppImmediately() {
        Log.w(TAG, "🚫 Executing block sequence...")
        
        // Сначала выполняем действие "Назад" для закрытия приложения
        val backResult = performGlobalAction(GLOBAL_ACTION_BACK)
        Log.d(TAG, "Back action result: $backResult")
        
        // Затем сразу возвращаем на главный экран (без задержки для мгновенной блокировки)
        handler.post {
            goToHome()
        }
        
        // Запускаем системный оверлей для блокировки поверх
        handler.postDelayed({
            try {
                val intent = Intent(this, OverlayBlockerService::class.java)
                intent.putExtra("blockedAppName", "Приложение")
                startService(intent)
            } catch (_: Exception) {}
        }, 150)
    }
    
    private fun goToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        startActivity(homeIntent)
    }
    
    private fun showBlockerApp() {
        try {
            val intent = packageManager.getLaunchIntentForPackage("com.example.pp")
            
            intent?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }?.let {
                startActivity(it)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error showing blocker app", e)
        }
    }
    
    override fun onInterrupt() {
        // Не требуется
    }
    
    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        Log.d(TAG, "AppBlockerService destroyed")
    }
}

