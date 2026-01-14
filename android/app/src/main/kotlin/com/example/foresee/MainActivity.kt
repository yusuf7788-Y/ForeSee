package com.ufine.foresee

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.app.AppOpsManager
import android.content.Context
import android.os.Build

class MainActivity: FlutterActivity() {
    private val USAGE_TRACKER_CHANNEL = "com.example.foresee/usage_tracker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_TRACKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startUsageTracker" -> {
                    val timeThreshold = call.argument<Long>("timeThreshold")
                    val intent = Intent(this, AppUsageTrackerService::class.java)
                    intent.putExtra("timeThreshold", timeThreshold)
                    startService(intent)
                    result.success(null)
                }
                "stopUsageTracker" -> {
                    stopService(Intent(this, AppUsageTrackerService::class.java))
                    result.success(null)
                }
                "requestUsageStatsPermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
