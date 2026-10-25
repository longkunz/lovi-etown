package com.lovisoft.etown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget (T15, native exception D7): renders the first
 * favorite camera's latest snapshot, which the Dart side keeps fresh via
 * HomeWidgetSyncService (keys: cameraName, imagePath, updatedAt).
 * Tapping the widget opens the app.
 */
class LoviWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.lovi_widget_layout)

            val name = widgetData.getString("cameraName", null)
            val imagePath = widgetData.getString("imagePath", null)
            val updatedAt = widgetData.getString("updatedAt", null)

            views.setTextViewText(
                R.id.widget_camera_name,
                if (name.isNullOrEmpty()) "Lovi Etown" else name
            )
            views.setTextViewText(
                R.id.widget_updated_at,
                if (updatedAt.isNullOrEmpty()) "Thêm camera Quan tâm trong app" else "Cập nhật $updatedAt"
            )
            if (!imagePath.isNullOrEmpty()) {
                val bitmap = BitmapFactory.decodeFile(imagePath)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                }
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
