package ru.modo.app

import android.app.Activity
import android.app.TimePickerDialog
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.graphics.PorterDuff
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class AddPlanActivity : Activity() {

    private var selectedHour:   Int = -1
    private var selectedMinute: Int = -1
    private var targetDateKey: String = ""

    private val accentColors = intArrayOf(
        0xFFE8927C.toInt(), 0xFF5B8CDB.toInt(),
        0xFF9B59B6.toInt(), 0xFF2ECC71.toInt()
    )

    private fun getAccentColor(): Int {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val index = try {
            val v = prefs.getLong("flutter.accentIndex", -1L)
            if (v >= 0L) v.toInt() else prefs.getInt("accentIndex", 0)
        } catch (e: Exception) { 0 }.coerceIn(0, accentColors.lastIndex)
        return accentColors[index]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        targetDateKey = intent.getStringExtra(PlannerWidget.EXTRA_SELECTED_DATE)
            ?: SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.attributes.dimAmount = 0.55f
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        )

        setContentView(R.layout.widget_add_overlay)

        val input     = findViewById<EditText>(R.id.overlay_input)
        val timeRow   = findViewById<LinearLayout>(R.id.overlay_time_row)
        val timeLabel = findViewById<TextView>(R.id.overlay_time_label)
        val timeClear = findViewById<TextView>(R.id.overlay_time_clear)
        val btnSave   = findViewById<Button>(R.id.overlay_save)
        val btnCancel = findViewById<Button>(R.id.overlay_cancel)

        val accentColor = getAccentColor()
        btnSave.background.mutate().setColorFilter(accentColor, PorterDuff.Mode.SRC_IN)
        input.setHintTextColor(0x55FFFFFF)
        input.requestFocus()

        timeRow.setOnClickListener {
            val calendar   = Calendar.getInstance()
            val initHour   = if (selectedHour   >= 0) selectedHour   else calendar.get(Calendar.HOUR_OF_DAY)
            val initMinute = if (selectedMinute >= 0) selectedMinute else calendar.get(Calendar.MINUTE)
            val dialog = TimePickerDialog(
                createThemedContext(accentColor),
                { _, hour, minute ->
                    selectedHour   = hour
                    selectedMinute = minute
                    timeLabel.text = "%02d:%02d".format(hour, minute)
                    timeLabel.setTextColor(0xFFFFFFFF.toInt())
                    timeClear.visibility = View.VISIBLE
                },
                initHour, initMinute, true
            )
            dialog.show()
            dialog.getButton(android.app.AlertDialog.BUTTON_POSITIVE)?.setTextColor(accentColor)
            dialog.getButton(android.app.AlertDialog.BUTTON_NEGATIVE)?.setTextColor(0xFFAAAAAA.toInt())
        }

        timeClear.setOnClickListener {
            selectedHour   = -1
            selectedMinute = -1
            timeLabel.text = "Добавить время (необязательно)"
            timeLabel.setTextColor(0x55FFFFFF)
            timeClear.visibility = View.GONE
        }

        btnCancel.setOnClickListener { finish() }

        btnSave.setOnClickListener {
            val text = input.text.toString().trim()
            if (text.isEmpty()) {
                input.hint = "Напиши хоть что-нибудь..."
                input.setHintTextColor(accentColor)
                return@setOnClickListener
            }
            val timeStr = if (selectedHour >= 0) "%02d:%02d".format(selectedHour, selectedMinute) else null
            savePlan(text, timeStr)
            updateWidget()
            finish()
        }
    }

    private fun createThemedContext(accentColor: Int): android.view.ContextThemeWrapper {
        val themeResId = when (accentColor) {
            0xFF5B8CDB.toInt() -> R.style.TimePickerThemeBlue
            0xFF9B59B6.toInt() -> R.style.TimePickerThemePurple
            0xFF2ECC71.toInt() -> R.style.TimePickerThemeGreen
            else               -> R.style.TimePickerTheme
        }
        return android.view.ContextThemeWrapper(this, themeResId)
    }

    private fun savePlan(text: String, time: String?) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val plansJson = prefs.getString("flutter.plans", null) ?: prefs.getString("plans", "{}") ?: "{}"
        val allPlans = try { JSONObject(plansJson) } catch (e: Exception) { JSONObject() }
        val dayArr = allPlans.optJSONArray(targetDateKey) ?: JSONArray()
        val plan = JSONObject().apply {
            put("id",   System.currentTimeMillis().toString())
            put("text", text)
            if (time != null) put("time", time) else put("time", JSONObject.NULL)
            put("done", false)
        }
        dayArr.put(plan)
        allPlans.put(targetDateKey, dayArr)
        val json = allPlans.toString()

        // FIX SYNC: пишем только в flutter.plans — это единственный ключ
        // который читает Flutter через widgetPull. Если писать в оба ключа
        // одновременно — widgetPull видит их равными и возвращает null.
        // MainActivity.prefsListener слушает flutter.plans и триггерит sync.
        prefs.edit()
            .putString("flutter.plans", json)
            .apply()
    }

    private fun updateWidget() {
        val mgr = AppWidgetManager.getInstance(this)
        val ids = mgr.getAppWidgetIds(ComponentName(this, PlannerWidget::class.java))
        for (id in ids) PlannerWidget.updateWidget(this, mgr, id)
    }
}
