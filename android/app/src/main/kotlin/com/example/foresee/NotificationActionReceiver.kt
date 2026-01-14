package com.ufine.foresee

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val packageName = intent.getStringExtra("packageName")
        if (packageName != null) {
            val prefs = context.getSharedPreferences("UsageTrackerPrefs", Context.MODE_PRIVATE)
            prefs.edit().putInt("${packageName}_notificationLevel", 2).apply() // Set to max level to prevent further notifications for the day
        }
    }
}
