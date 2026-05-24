package ru.modo.app

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class PlannerWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        PlannerRemoteViewsFactory(applicationContext, intent)
}

class PlannerRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    data class PlanItem(
        val id: String,
        val text: String,
        val time: String?,
        val done: Boolean,
        val isShopping: Boolean
    )

    private var plans: List<PlanItem> = emptyList()
    private var accentColor: Int = 0xFFE8927C.toInt()

    private val accentColors = intArrayOf(
        0xFFE8927C.toInt(),
        0xFF5B8CDB.toInt(),
        0xFF9B59B6.toInt(),
        0xFF2ECC71.toInt()
    )

    override fun onCreate()         { load() }
    override fun onDataSetChanged() { load() } // вызывается при notifyAppWidgetViewDataChanged
    override fun onDestroy()        {}

    private fun load() {
        // Всегда читаем свежие данные — без кэша
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        // Акцентный цвет
        accentColor = try {
            val v = prefs.getLong("flutter.accentIndex", -1L)
            val idx = (if (v >= 0L) v.toInt() else prefs.getInt("accentIndex", 0))
                .coerceIn(0, accentColors.lastIndex)
            accentColors[idx]
        } catch (e: Exception) { 0xFFE8927C.toInt() }

        val plansJson = prefs.getString("flutter.plans", null)
            ?: prefs.getString("plans", "{}") ?: "{}"

        val hideDoneKey = "widget_hide_done_$today"
        val hiddenIds = try {
            prefs.getString(hideDoneKey, "")!!
                .split(",").filter { it.isNotEmpty() }.toSet()
        } catch (e: Exception) { emptySet() }

        val all = try {
            val allPlans = JSONObject(plansJson)
            val todayArr = allPlans.optJSONArray(today) ?: JSONArray()
            (0 until todayArr.length()).map { i ->
                val obj = todayArr.getJSONObject(i)
                PlanItem(
                    id         = obj.optString("id", i.toString()),
                    text       = obj.optString("text", ""),
                    time       = obj.optString("time").takeIf { it.isNotEmpty() && it != "null" },
                    done       = obj.optBoolean("done", false),
                    isShopping = obj.optString("type") == "shopping"
                )
            }
        } catch (e: Exception) { emptyList() }

        // Фильтр: скрываем выполненные из hiddenIds
        val visible = all.filter { !(it.done && hiddenIds.contains(it.id)) }

        // Сортировка: покупки (невыполненные) → обычные → выполненные
        // Внутри групп: с временем первыми
        plans = visible.sortedWith(compareBy(
            { it.done },
            { !it.isShopping || it.done }, // невыполненные покупки первыми
            { it.time == null },
            { it.time ?: "" }
        ))
    }

    override fun getCount() = plans.size
    override fun getViewTypeCount() = 1

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= plans.size)
            return RemoteViews(context.packageName, R.layout.widget_plan_item)

        val plan  = plans[position]
        val views = RemoteViews(context.packageName, R.layout.widget_plan_item)

        when {
            plan.isShopping && !plan.done -> {
                // Покупка — иконка корзины, акцентный цвет
                views.setTextViewText(R.id.widget_item_check, "🛒")
                views.setTextColor(R.id.widget_item_check, accentColor)
                views.setInt(R.id.widget_item_text, "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
                views.setTextColor(R.id.widget_item_text, 0xFFFFFFFF.toInt())
                views.setTextViewText(R.id.widget_item_text, plan.text)
            }
            plan.done -> {
                // Выполнено — ✓ акцентный, текст зачёркнут серый
                views.setTextViewText(R.id.widget_item_check, "✓")
                views.setTextColor(R.id.widget_item_check, accentColor)
                views.setInt(R.id.widget_item_text, "setPaintFlags",
                    Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                views.setTextColor(R.id.widget_item_text, 0x66FFFFFF)
                views.setTextViewText(R.id.widget_item_text, plan.text)
            }
            else -> {
                // Обычный план — ○ серый
                views.setTextViewText(R.id.widget_item_check, "○")
                views.setTextColor(R.id.widget_item_check, 0xFFAAAAAA.toInt())
                views.setInt(R.id.widget_item_text, "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
                views.setTextColor(R.id.widget_item_text, 0xFFFFFFFF.toInt())
                views.setTextViewText(R.id.widget_item_text, plan.text)
            }
        }

        // Время
        if (!plan.time.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_item_time, View.VISIBLE)
            views.setTextViewText(R.id.widget_item_time, plan.time)
            views.setTextColor(R.id.widget_item_time, accentColor and 0x00FFFFFF or 0x88000000.toInt())
        } else {
            views.setViewVisibility(R.id.widget_item_time, View.GONE)
        }

        // fillInIntent для toggle done
        val fillIntent = Intent().apply {
            putExtra(PlannerWidget.EXTRA_PLAN_ID, plan.id)
        }
        views.setOnClickFillInIntent(R.id.widget_item_root, fillIntent)

        return views
    }

    override fun getLoadingView() = null
    override fun hasStableIds()   = true
    override fun getItemId(position: Int) =
        if (position < plans.size) plans[position].id.hashCode().toLong()
        else position.toLong()
}
