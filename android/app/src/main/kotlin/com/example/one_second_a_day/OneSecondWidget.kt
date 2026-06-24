package com.example.one_second_a_day

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

class OneSecondWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("home_widget_prefs", Context.MODE_PRIVATE)
            val streak = prefs.getInt("streak", 0)
            val capturedToday = prefs.getBoolean("captured_today", false)

            val views = RemoteViews(context.packageName, R.layout.one_second_widget)

            views.setTextViewText(R.id.streak_text, streak.toString())
            views.setTextViewText(R.id.streak_label, if (streak == 1) "DAY STREAK" else "DAY STREAK")
            views.setTextViewText(
                R.id.status_text,
                if (capturedToday) "TODAY: CAPTURED" else "TODAY: NOT YET"
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
