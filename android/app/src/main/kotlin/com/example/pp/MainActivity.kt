package com.example.pp

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pp/app_blocker"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBlockedApps" -> {
                    try {
                        val blockedApps = call.arguments as? List<String> ?: emptyList()
                        val blockedAppsSet = blockedApps.toSet()
                        AppBlockerService.setBlockedApps(applicationContext, blockedAppsSet)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error setting blocked apps", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "setUnlockedSeconds" -> {
                    try {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val seconds = call.argument<Int>("seconds") ?: 0
                        val prefs = applicationContext.getSharedPreferences("AppBlockerPrefs", Context.MODE_PRIVATE)
                        prefs.edit().putInt("unlocked_seconds_$packageName", seconds).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error setting unlocked seconds", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isOverlayGranted" -> {
                    try {
                        val granted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) Settings.canDrawOverlays(applicationContext) else true
                        result.success(granted)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openOverlaySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "testBlockedApps" -> {
                    try {
                        val blockedApps = AppBlockerService.getBlockedApps(applicationContext)
                        Log.d("MainActivity", "TEST: Blocked apps from native: $blockedApps")
                        result.success(blockedApps.toList())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error testing blocked apps", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "getForegroundApp" -> {
                    try {
                        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                        val end = System.currentTimeMillis()
                        val start = end - 10_000
                        val events: UsageEvents = usm.queryEvents(start, end)
                        var lastPkg: String? = null
                        val ue = UsageEvents.Event()
                        while (events.hasNextEvent()) {
                            events.getNextEvent(ue)
                            if (ue.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND || ue.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                                lastPkg = ue.packageName
                            }
                        }
                        result.success(lastPkg ?: "")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error getForegroundApp", e)
                        result.success("")
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
        
        for (service in enabledServices) {
            if (service.resolveInfo.serviceInfo.packageName == packageName) {
                return true
            }
        }
        return false
    }
}
