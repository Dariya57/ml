package com.example.pp

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class OverlayBlockerService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!canDrawOverlays(this)) {
            openOverlaySettings()
            stopSelf()
            return START_NOT_STICKY
        }

        val blockedAppName = intent?.getStringExtra("blockedAppName") ?: "Приложение"

        if (overlayView == null) {
            showOverlay(blockedAppName)
        }
        return START_STICKY
    }

    private fun showOverlay(blockedAppName: String) {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val root = inflater.inflate(R.layout.overlay_blocker, null)
        val title = root.findViewById<TextView>(R.id.title)
        val subtitle = root.findViewById<TextView>(R.id.subtitle)
        val closeButton = root.findViewById<Button>(R.id.close_button)
        val openFitai = root.findViewById<Button>(R.id.open_fitai)

        // Try to use in-app language from FlutterSharedPreferences; fallback to system resources
        val sp = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lang = sp.getString("flutter.app_locale", null)
        when (lang) {
            "ru" -> {
                title.text = "Доступ запрещён"
                subtitle.text = "$blockedAppName заблокировано FitAI"
                openFitai.text = "Открыть FitAI"
                closeButton.text = "На главный экран"
            }
            "kk" -> {
                title.text = "Қол жеткізу шектелді"
                subtitle.text = "$blockedAppName FitAI арқылы бұғатталған"
                openFitai.text = "FitAI ашу"
                closeButton.text = "Басты бетке"
            }
            else -> {
                title.setText(R.string.overlay_blocked_title)
                subtitle.text = getString(R.string.overlay_blocked_subtitle)
                openFitai.setText(R.string.overlay_open_fitai)
                closeButton.setText(R.string.overlay_go_home)
            }
        }

        closeButton.setOnClickListener {
            removeOverlay()
            val home = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(home)
            stopSelf()
        }

        openFitai.setOnClickListener {
            try {
                val intent = packageManager.getLaunchIntentForPackage("com.example.pp")
                intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                removeOverlay()
                stopSelf()
                if (intent != null) startActivity(intent)
            } catch (_: Exception) {}
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }

        overlayView = root
        windowManager?.addView(overlayView, params)

        // Скрываем системные панели для настоящего полноэкрана
        overlayView?.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        // Перехватываем касания
        overlayView?.setOnTouchListener { _, _ -> true }
    }

    private fun removeOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
        }
        overlayView = null
    }

    private fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(context) else true
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
