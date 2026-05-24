package ru.modo.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class PlannerWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(android.content.ComponentName(context, PlannerWidget::class.java))

        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                for (id in ids) updateWidget(context, mgr, id)
            }
            ACTION_PREV_DAY -> {
                val wid = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                if (wid != -1) { shiftDay(context, wid, -1); updateWidget(context, mgr, wid) }
            }
            ACTION_NEXT_DAY -> {
                val wid = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                if (wid != -1) { shiftDay(context, wid, +1); updateWidget(context, mgr, wid) }
            }
            ACTION_TOGGLE_DONE -> {
                val planId  = intent.getStringExtra(EXTRA_PLAN_ID) ?: return
                val wid     = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                val dateKey = if (wid != -1) getSelectedDate(context, wid) else todayKey()
                togglePlanDone(context, planId, dateKey)
                for (id in ids) updateWidget(context, mgr, id)
            }
            ACTION_DELETE -> {
                val planId  = intent.getStringExtra(EXTRA_PLAN_ID) ?: return
                val wid     = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                val dateKey = if (wid != -1) getSelectedDate(context, wid) else todayKey()
                deletePlan(context, planId, dateKey)
                for (id in ids) updateWidget(context, mgr, id)
            }
        }
    }

    companion object {
        const val ACTION_TOGGLE_DONE  = "ru.modo.app.TOGGLE_DONE"
        const val ACTION_PREV_DAY     = "ru.modo.app.PREV_DAY"
        const val ACTION_NEXT_DAY     = "ru.modo.app.NEXT_DAY"
        const val ACTION_DELETE       = "ru.modo.app.DELETE_PLAN"
        const val EXTRA_PLAN_ID       = "plan_id"
        const val EXTRA_SELECTED_DATE = "selected_date"
        const val MAX_ROWS            = 7

        private val ACCENT_COLORS = intArrayOf(
            0xFFE8927C.toInt(), 0xFF5B8CDB.toInt(),
            0xFF9B59B6.toInt(), 0xFF2ECC71.toInt()
        )

        private val ROW_IDS   = intArrayOf(R.id.widget_row_0, R.id.widget_row_1, R.id.widget_row_2, R.id.widget_row_3, R.id.widget_row_4, R.id.widget_row_5, R.id.widget_row_6)
        private val CHECK_IDS = intArrayOf(R.id.widget_check_0, R.id.widget_check_1, R.id.widget_check_2, R.id.widget_check_3, R.id.widget_check_4, R.id.widget_check_5, R.id.widget_check_6)
        private val TEXT_IDS  = intArrayOf(R.id.widget_text_0, R.id.widget_text_1, R.id.widget_text_2, R.id.widget_text_3, R.id.widget_text_4, R.id.widget_text_5, R.id.widget_text_6)
        private val TIME_IDS  = intArrayOf(R.id.widget_time_0, R.id.widget_time_1, R.id.widget_time_2, R.id.widget_time_3, R.id.widget_time_4, R.id.widget_time_5, R.id.widget_time_6)
        private val DEL_IDS   = intArrayOf(R.id.widget_del_0, R.id.widget_del_1, R.id.widget_del_2, R.id.widget_del_3, R.id.widget_del_4, R.id.widget_del_5, R.id.widget_del_6)

        // ── Выбранный день ────────────────────────────────────────
        private fun prefKey(wid: Int) = "widget_day_$wid"

        fun getSelectedDate(context: Context, wid: Int): String {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            return prefs.getString(prefKey(wid), null) ?: todayKey()
        }

        private fun setSelectedDate(context: Context, wid: Int, key: String) {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit().putString(prefKey(wid), key).apply()
        }

        private fun shiftDay(context: Context, wid: Int, delta: Int) {
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val cal = Calendar.getInstance().apply {
                time = sdf.parse(getSelectedDate(context, wid)) ?: Date()
            }
            cal.add(Calendar.DAY_OF_YEAR, delta)
            setSelectedDate(context, wid, sdf.format(cal.time))
        }

        fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        private fun formatHeader(dateKey: String): String {
            return try {
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val cal = Calendar.getInstance()
                val today     = todayKey()
                val yesterday = run { cal.add(Calendar.DAY_OF_YEAR, -1); sdf.format(cal.time).also { cal.add(Calendar.DAY_OF_YEAR, 1) } }
                val tomorrow  = run { cal.add(Calendar.DAY_OF_YEAR, 1);  sdf.format(cal.time).also { cal.add(Calendar.DAY_OF_YEAR, -1) } }
                when (dateKey) {
                    today     -> "Сегодня"
                    yesterday -> "Вчера"
                    tomorrow  -> "Завтра"
                    else      -> SimpleDateFormat("d MMM", Locale("ru")).format(sdf.parse(dateKey) ?: Date())
                }
            } catch (e: Exception) { dateKey }
        }

        fun updateWidget(context: Context, mgr: AppWidgetManager, wid: Int) {
            val views = RemoteViews(context.packageName, R.layout.planner_widget)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val accentIdx = try {
                val v = prefs.getLong("flutter.accentIndex", -1L)
                if (v >= 0L) v.toInt() else prefs.getInt("accentIndex", 0)
            } catch (e: Exception) { 0 }.coerceIn(0, ACCENT_COLORS.lastIndex)
            val accent = ACCENT_COLORS[accentIdx]

            views.setInt(R.id.widget_add_bg,  "setColorFilter", accent)
            views.setInt(R.id.widget_add_btn, "setColorFilter", 0xFFFFFFFF.toInt())

            val dateKey = getSelectedDate(context, wid)
            views.setTextViewText(R.id.widget_title, formatHeader(dateKey))
            views.setTextColor(R.id.widget_title,
                if (dateKey == todayKey()) accent else 0xFFFFFFFF.toInt())

            val mutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE

            views.setOnClickPendingIntent(R.id.widget_btn_prev,
                PendingIntent.getBroadcast(context, wid * 10 + 1,
                    Intent(context, PlannerWidget::class.java).apply {
                        action = ACTION_PREV_DAY
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, wid)
                    }, mutable))

            views.setOnClickPendingIntent(R.id.widget_btn_next,
                PendingIntent.getBroadcast(context, wid * 10 + 2,
                    Intent(context, PlannerWidget::class.java).apply {
                        action = ACTION_NEXT_DAY
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, wid)
                    }, mutable))

            views.setOnClickPendingIntent(R.id.widget_add_btn_frame,
                PendingIntent.getActivity(context, wid * 10 + 3,
                    Intent(context, AddPlanActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra(EXTRA_SELECTED_DATE, dateKey)
                    }, mutable))

            data class Plan(val id: String, val text: String, val time: String?,
                            val done: Boolean, val isShopping: Boolean)

            val plansJson = prefs.getString("flutter.plans", null) ?: prefs.getString("plans", "{}") ?: "{}"
            val allPlans = try {
                val arr = JSONObject(plansJson).optJSONArray(dateKey)
                if (arr == null) emptyList()
                else (0 until arr.length()).map { i ->
                    val o = arr.getJSONObject(i)
                    Plan(
                        id         = o.optString("id", i.toString()),
                        text       = o.optString("text", ""),
                        time       = o.optString("time").takeIf { it.isNotEmpty() && it != "null" },
                        done       = o.optBoolean("done", false),
                        isShopping = o.optString("type") == "shopping"
                    )
                }
            } catch (e: Exception) { emptyList() }

            val sorted = allPlans.sortedWith(compareBy(
                { it.done },
                { !(it.isShopping && !it.done) },
                { it.time == null },
                { it.time ?: "" }
            ))

            val visible = sorted.take(MAX_ROWS)
            val extra   = sorted.size - visible.size

            views.setViewVisibility(R.id.widget_empty, if (visible.isEmpty()) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_more,  if (extra > 0) View.VISIBLE else View.GONE)
            if (extra > 0) {
                views.setTextViewText(R.id.widget_more, "+ ещё $extra")
                views.setTextColor(R.id.widget_more, accent)
            }

            for (i in 0 until MAX_ROWS) {
                if (i < visible.size) {
                    val plan = visible[i]
                    views.setViewVisibility(ROW_IDS[i], View.VISIBLE)

                    when {
                        plan.isShopping && !plan.done -> {
                            views.setTextViewText(CHECK_IDS[i], "🛒")
                            views.setTextColor(CHECK_IDS[i], accent)
                            views.setInt(TEXT_IDS[i], "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
                            views.setTextColor(TEXT_IDS[i], 0xFFFFFFFF.toInt())
                        }
                        plan.done -> {
                            views.setTextViewText(CHECK_IDS[i], "✓")
                            views.setTextColor(CHECK_IDS[i], accent)
                            views.setInt(TEXT_IDS[i], "setPaintFlags",
                                Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                            views.setTextColor(TEXT_IDS[i], 0x55FFFFFF)
                        }
                        else -> {
                            views.setTextViewText(CHECK_IDS[i], "○")
                            views.setTextColor(CHECK_IDS[i], 0x4DFFFFFF)
                            views.setInt(TEXT_IDS[i], "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
                            views.setTextColor(TEXT_IDS[i], 0xFFFFFFFF.toInt())
                        }
                    }

                    views.setTextViewText(TEXT_IDS[i], plan.text)

                    if (!plan.time.isNullOrEmpty()) {
                        views.setViewVisibility(TIME_IDS[i], View.VISIBLE)
                        views.setTextViewText(TIME_IDS[i], plan.time)
                        views.setTextColor(TIME_IDS[i], accent)
                    } else {
                        views.setViewVisibility(TIME_IDS[i], View.GONE)
                    }

                    // Toggle (тап на строку кроме кнопки удаления)
                    views.setOnClickPendingIntent(ROW_IDS[i],
                        PendingIntent.getBroadcast(context, wid * 100 + i,
                            Intent(context, PlannerWidget::class.java).apply {
                                action = ACTION_TOGGLE_DONE
                                putExtra(EXTRA_PLAN_ID, plan.id)
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, wid)
                            }, mutable))

                    // Кнопка удаления 🗑
                    views.setViewVisibility(DEL_IDS[i], View.VISIBLE)
                    views.setOnClickPendingIntent(DEL_IDS[i],
                        PendingIntent.getBroadcast(context, wid * 1000 + i,
                            Intent(context, PlannerWidget::class.java).apply {
                                action = ACTION_DELETE
                                putExtra(EXTRA_PLAN_ID, plan.id)
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, wid)
                            }, mutable))

                } else {
                    views.setViewVisibility(ROW_IDS[i], View.GONE)
                }
            }

            mgr.updateAppWidget(wid, views)
        }

        fun togglePlanDone(context: Context, planId: String, dateKey: String) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json  = prefs.getString("flutter.plans", null)
                ?: prefs.getString("plans", "{}") ?: return
            try {
                val allPlans = JSONObject(json)
                val dayArr   = allPlans.optJSONArray(dateKey) ?: return
                for (i in 0 until dayArr.length()) {
                    val plan = dayArr.getJSONObject(i)
                    if (plan.optString("id") == planId) {
                        plan.put("done", !plan.optBoolean("done", false))
                        allPlans.put(dateKey, dayArr)
                        prefs.edit().putString("flutter.plans", allPlans.toString()).apply()
                        break
                    }
                }
            } catch (e: Exception) { e.printStackTrace() }
        }

        fun deletePlan(context: Context, planId: String, dateKey: String) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json  = prefs.getString("flutter.plans", null)
                ?: prefs.getString("plans", "{}") ?: return
            try {
                val allPlans = JSONObject(json)
                val dayArr   = allPlans.optJSONArray(dateKey) ?: return
                val newArr   = org.json.JSONArray()
                for (i in 0 until dayArr.length()) {
                    val plan = dayArr.getJSONObject(i)
                    if (plan.optString("id") != planId) newArr.put(plan)
                }
                allPlans.put(dateKey, newArr)
                prefs.edit().putString("flutter.plans", allPlans.toString()).apply()
            } catch (e: Exception) { e.printStackTrace() }
        }
    }
}
