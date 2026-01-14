package com.ufine.foresee

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.PendingIntent
import java.util.Random

class AppUsageTrackerService : Service() {

    private val scheduler = Executors.newSingleThreadScheduledExecutor()
    private val COOLDOWN_PERIOD_MS = 20 * 60 * 1000 // 20 minutes
    private val LEVEL_1_THRESHOLD_MS = 90 * 60 * 1000L
    private val LEVEL_2_THRESHOLD_MS = 130 * 60 * 1000L

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        scheduler.scheduleAtFixedRate({
            checkAppUsage()
        }, 0, 15, TimeUnit.MINUTES)

        return START_STICKY
    }

    private fun checkAppUsage() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val prefs = getSharedPreferences("UsageTrackerPrefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()

        val endTime = System.currentTimeMillis()
        val startTime = endTime - (3 * 60 * 60 * 1000) // Check last 3 hours to be safe

        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)

        stats?.forEach { stat ->
            val packageName = stat.packageName
            val lastUsed = stat.lastTimeUsed
            val totalTime = stat.totalTimeInForeground

            val lastNotifiedTime = prefs.getLong("${packageName}_lastNotifiedTime", 0)
            val notificationLevel = prefs.getInt("${packageName}_notificationLevel", 0)

            // Cooldown check: If app hasn't been used for 20 mins, reset notification level
            if (endTime - lastUsed > COOLDOWN_PERIOD_MS && notificationLevel > 0) {
                editor.putInt("${packageName}_notificationLevel", 0)
            }

            // Tiered notification logic
            if (totalTime > LEVEL_2_THRESHOLD_MS && notificationLevel < 2) {
                sendNotification(packageName, 2)
                editor.putInt("${packageName}_notificationLevel", 2)
                editor.putLong("${packageName}_lastNotifiedTime", endTime)
            } else if (totalTime > LEVEL_1_THRESHOLD_MS && notificationLevel < 1) {
                sendNotification(packageName, 1)
                editor.putInt("${packageName}_notificationLevel", 1)
                editor.putLong("${packageName}_lastNotifiedTime", endTime)
            }
        }
        editor.apply()
    }

    private fun sendNotification(packageName: String, level: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "usage_alerts"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Uygulama Kullanım Uyarıları", NotificationManager.IMPORTANCE_DEFAULT)
            notificationManager.createNotificationChannel(channel)
        }

        val message = getPersonalizedMessage(packageName, level)

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Dijital Denge Uyarısı")
            .setContentText(message)
            .setSmallIcon(R.mipmap.ic_launcher)
            .addAction(createSnoozeAction(packageName))
            .build()

        notificationManager.notify(packageName.hashCode() + level, notification)
    }

    private fun createSnoozeAction(packageName: String): NotificationCompat.Action {
        val snoozeIntent = Intent(this, NotificationActionReceiver::class.java).apply {
            putExtra("packageName", packageName)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(this, packageName.hashCode(), snoozeIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Action.Builder(0, "Bugünlük Sus", snoozePendingIntent).build()
    }

    private fun getPersonalizedMessage(packageName: String, level: Int): String {
        val socialMediaMessages = listOf(
            "Akışta kaybolmak kolay, biraz mola verip gerçek dünyadaki akışa katılmaya ne dersin?",
            "Paylaşımlar harika, ama en güzel anlar paylaşılmayanlardır. Gözlerini ekrandan ayırıp etrafına bak.",
            "Sosyal medyada 90 dakikayı devirdin. Bir arkadaşını aramaya ne dersin?",
            "Beğeniler ve yorumlar bir yere kadar, gerçek hayattaki etkileşim gibisi yok.",
            "Dijital dünyada maraton koştun. Şimdi bir esneme ve mola zamanı."
        )

        val browserMessages = listOf(
            "İnternetin derinliklerinde bir mola zamanı geldi. Gözlerini dinlendir.",
            "Sekmeler arasında kaybolmadan önce kısa bir ara verelim mi?",
            "Bilgi okyanusunda 90 dakika... Zihnini biraz dinlendirme vakti.",
            "Araştırmaların arasına bir kahve molası sıkıştırmak harika fikir olabilir.",
            "Web'de sörf yapmak yorucu olabilir. Gerçek hayatta bir yürüyüşe ne dersin?"
        )

        val genericMessages = listOf(
            "Bu uygulamada epey zaman geçirdin. Kısa bir mola harikalar yaratabilir.",
            "Ekran süresi hedeflerini hatırlatma zamanı. Küçük bir ara vermeye ne dersin?",
            "Dijital bir mola, zihnini tazelemek için en iyi yollardan biridir.",
            "Bugün kendine ayırdığın zamanı hatırlıyor musun? İşte şimdi tam sırası.",
            "Gözlerin yorulmuş olabilir. 20 saniye uzağa bakarak onları dinlendirebilirsin."
        )

        val random = Random()
        val messages = when {
            packageName.contains("instagram", true) || 
            packageName.contains("facebook", true) || 
            packageName.contains("twitter", true) || 
            packageName.contains("tiktok", true) || 
            packageName.contains("snapchat", true) -> socialMediaMessages
            packageName.contains("chrome", true) || 
            packageName.contains("firefox", true) || 
            packageName.contains("browser", true) -> browserMessages
            else -> genericMessages
        }

        return messages[random.nextInt(messages.size)]
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        scheduler.shutdown()
        super.onDestroy()
    }
}
