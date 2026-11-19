package com.cidevelop.robinhood_options_mobile

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    companion object {
        private const val BACKGROUND_CHANNEL = "com.realizealpha.background_execution"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.renderer.addIsDisplayingFlutterUiListener(object : FlutterUiDisplayListener {
            override fun onFlutterUiDisplayed() {
                // Once Flutter UI renders its first frame, clear the window background
                // so it does not remain in memory or flash behind any transparent routes.
                window.setBackgroundDrawable(null)
            }

            override fun onFlutterUiNoLongerDisplayed() {}
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPlatformReadiness" -> result.success(inspectBackgroundReadiness())
                    "openBatteryOptimizationSettings", "openBackgroundSettings" -> {
                        result.success(openBatteryOptimizationSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun inspectBackgroundReadiness(): Map<String, Any> {
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager

        val ignoringBatteryOptimizations =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && powerManager != null) {
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } else {
                true
            }
        val powerSaveMode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && powerManager != null) {
                powerManager.isPowerSaveMode
            } else {
                false
            }
        val backgroundRestricted =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && activityManager != null) {
                activityManager.isBackgroundRestricted
            } else {
                false
            }

        return mapOf(
            "platform" to "android",
            "ignoringBatteryOptimizations" to ignoringBatteryOptimizations,
            "powerSaveMode" to powerSaveMode,
            "backgroundRestricted" to backgroundRestricted,
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "model" to (Build.MODEL ?: ""),
            "canOpenSettings" to true
        )
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        val packageUri = Uri.fromParts("package", packageName, null)
        val candidates = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }
            add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri))
        }
        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Fall through to application details settings.
            }
        }
        return false
    }
}
