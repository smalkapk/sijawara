package com.smalka.sijawara

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import java.util.Calendar
import kotlin.math.max

class PrayerRecapWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val ACTION_REFRESH_WIDGET = "com.smalka.sijawara.action.REFRESH_PRAYER_WIDGET"
        private const val EXTRA_LAUNCH_ACTION = "launch_action"
        private const val OPEN_PRAYER_RECAP = "open_prayer_recap"

        private data class PrayerTime(
            val name: String,
            val hour: Int,
            val minute: Int,
        )

        private val prayers = listOf(
            PrayerTime("Subuh", 4, 38),
            PrayerTime("Dzuhur", 12, 15),
            PrayerTime("Ashar", 15, 30),
            PrayerTime("Maghrib", 18, 5),
            PrayerTime("Isya", 19, 18),
        )
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextRefresh(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        scheduleNextRefresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_REFRESH_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PrayerRecapWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            appWidgetIds.forEach { appWidgetId ->
                updateWidget(context, appWidgetManager, appWidgetId)
            }
            scheduleNextRefresh(context)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val remoteViews = RemoteViews(context.packageName, R.layout.prayer_recap_widget)
        val nextPrayer = calculateNextPrayer()
        val countdown = formatRemaining(nextPrayer.time.timeInMillis - System.currentTimeMillis())

        remoteViews.setTextViewText(R.id.widgetPrayerLabel, "Menuju ${nextPrayer.prayerName}")
        remoteViews.setTextViewText(R.id.widgetCountdownValue, countdown)
        remoteViews.setOnClickPendingIntent(R.id.widgetRekapButton, buildOpenAppPendingIntent(context))

        appWidgetManager.updateAppWidget(appWidgetId, remoteViews)
    }

    private fun buildOpenAppPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_LAUNCH_ACTION, OPEN_PRAYER_RECAP)
        }

        return PendingIntent.getActivity(
            context,
            1002,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun scheduleNextRefresh(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, PrayerRecapWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        if (appWidgetIds.isEmpty()) return

        val intent = Intent(context, PrayerRecapWidgetProvider::class.java).apply {
            action = ACTION_REFRESH_WIDGET
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis = System.currentTimeMillis() + 60_000L

        // On Android 12+ (S), exact alarm requires SCHEDULE_EXACT_ALARM permission.
        // Fall back to inexact alarm if not granted.
        val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        if (canScheduleExact) {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC,
                        triggerAtMillis,
                        pendingIntent,
                    )
                }

                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager.setExact(
                        AlarmManager.RTC,
                        triggerAtMillis,
                        pendingIntent,
                    )
                }

                else -> {
                    alarmManager.set(
                        AlarmManager.RTC,
                        triggerAtMillis,
                        pendingIntent,
                    )
                }
            }
        } else {
            // Fallback: inexact alarm (may be delayed slightly by the OS)
            alarmManager.set(
                AlarmManager.RTC,
                triggerAtMillis,
                pendingIntent,
            )
        }
    }

    private fun calculateNextPrayer(): NextPrayer {
        val now = Calendar.getInstance()

        prayers.forEach { prayer ->
            val prayerCalendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, prayer.hour)
                set(Calendar.MINUTE, prayer.minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            if (prayerCalendar.after(now)) {
                return NextPrayer(prayer.name, prayerCalendar)
            }
        }

        val tomorrowSubuh = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, prayers.first().hour)
            set(Calendar.MINUTE, prayers.first().minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        return NextPrayer(prayers.first().name, tomorrowSubuh)
    }

    private fun formatRemaining(diffMillis: Long): String {
        val totalMinutes = max(0L, (diffMillis + 59_999L) / 60_000L)
        val hours = totalMinutes / 60L
        val minutes = totalMinutes % 60L
        return String.format("%02dj %02dm", hours, minutes)
    }

    private data class NextPrayer(
        val prayerName: String,
        val time: Calendar,
    )
}