package ru.modo.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "ru.modo.app/widget"
    private val ALARM_CHANNEL  = "ru.modo.app/alarm"
    private val SYNC_CHANNEL   = "ru.modo.app/sync"

    private var syncChannel: MethodChannel? = null

    // Слушаем ТОЛЬКО flutter.plans — именно в него пишут виджет и AddPlanActivity.
    // Когда Flutter сам меняет планы — он пишет через widgetPush который
    // обновляет оба ключа; нам не нужно реагировать на свои же записи.
    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == "flutter.plans") {
            // Обновляем виджет
            triggerWidgetUpdate()
            // Уведомляем Flutter — он подтянет новые данные через onPlansChanged
            runOnUiThread {
                syncChannel?.invokeMethod("onPlansChanged", null)
            }
        }
    }

    private fun triggerWidgetUpdate() {
        val mgr = AppWidgetManager.getInstance(this)
        val ids = mgr.getAppWidgetIds(ComponentName(this, PlannerWidget::class.java))
        for (id in ids) PlannerWidget.updateWidget(this, mgr, id)
    }

    override fun onResume() {
        super.onResume()
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .registerOnSharedPreferenceChangeListener(prefsListener)
        triggerWidgetUpdate()
    }

    override fun onPause() {
        super.onPause()
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .unregisterOnSharedPreferenceChangeListener(prefsListener)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        syncChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget"     -> { triggerWidgetUpdate(); result.success(null) }
                    "checkOpenPlanner" -> {
                        val open = intent.getBooleanExtra("open_planner", false)
                        if (open) intent.removeExtra("open_planner")
                        result.success(open)
                    }
                    "checkAddPlan"     -> {
                        val add = intent.getBooleanExtra("add_plan", false)
                        if (add) intent.removeExtra("add_plan")
                        result.success(add)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setAlarm") {
                    val hour    = call.argument<Int>("hour")       ?: 0
                    val minute  = call.argument<Int>("minute")     ?: 0
                    val message = call.argument<String>("message") ?: ""
                    val alarmIntent = android.content.Intent(
                        android.provider.AlarmClock.ACTION_SET_ALARM
                    ).apply {
                        putExtra(android.provider.AlarmClock.EXTRA_HOUR, hour)
                        putExtra(android.provider.AlarmClock.EXTRA_MINUTES, minute)
                        putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, message)
                        putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, false)
                        flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(alarmIntent)
                    result.success(null)
                } else result.notImplemented()
            }
    }
}
