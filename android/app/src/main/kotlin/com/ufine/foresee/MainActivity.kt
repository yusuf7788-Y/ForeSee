package com.ufine.foresee

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.app.AppOpsManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity: FlutterActivity() {
    private val USAGE_TRACKER_CHANNEL = "com.example.foresee/usage_tracker"
    private val PROCESS_TEXT_CHANNEL = "com.example.foresee/process_text"
    private var processTextChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        processTextChannel = MethodChannel(messenger, PROCESS_TEXT_CHANNEL)

        MethodChannel(messenger, USAGE_TRACKER_CHANNEL).setMethodCallHandler { call, result ->
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

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action == Intent.ACTION_PROCESS_TEXT) {
            val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            if (text != null) {
                // Flutter'a gönder (yüklenme tamamlanmamışsa gecikmeli gönderim gerekebilir ama genellikle singleTop'ta kanal hazırdır)
                processTextChannel?.invokeMethod("processText", text)
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
