import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

const List<String> motivationMessages = [
  'Телефон подождёт. Твои цели — нет. 🎯',
  'Каждая минута на себя — это инвестиция. ⚡',
  'Встань. Подвигайся. Сделай хоть что-нибудь. 💪',
  'Маленькие действия каждый день — большие результаты через год. 💰',
  'Запиши день — это займёт 3 минуты. Потом будешь рад что сделал. 🔥',
  'Через год ты скажешь спасибо себе сегодняшнему. Или нет. 🌅',
  'Выключи телефон. Сделай одно дело. Вернись победителем. ✅',
  'Стабильность важнее интенсивности. Маленький шаг сегодня. 📈',
  'Запиши как прошёл день — это твоя история. 📝',
  'Сегодняшние действия — завтрашние результаты. 🎯',
  'Хватит готовиться. Начни делать. 💡',
  'Маленький шаг каждый день = огромный результат через год. 🌱',
  'Дисциплина — это мост между целями и достижениями.',
  'Не желай чтобы было легче — желай чтобы ты был лучше.',
  'Если тебе не нравится где ты находишься — двигайся. Ты не дерево.',
];

String _getReturnMessage(int daysMissed, String goal) {
  if (daysMissed == 1) {
    return 'Вчера не было записи. Сегодня — другой день. Modo ждёт. 📝';
  } else if (daysMissed == 2) {
    return '2 дня без дневника. Маленький шаг сегодня? Займёт 3 минуты. ⏱️';
  } else if (daysMissed == 3) {
    return '3 дня тишины. Стрик потерян. Но всё можно начать заново — прямо сейчас. 🔥';
  } else if (daysMissed == 4) {
    return '4 дня. Твоя цель "$goal" никуда не делась. Она ждёт пока ты листаешь. 👀';
  } else if (daysMissed == 5) {
    return '5 дней без записи. Именно сейчас важно не останавливаться. Открой Modo. 💪';
  } else if (daysMissed == 7) {
    return 'Неделя прошла. Ты доволен? Если нет — время что-то менять. Modo поможет. 📊';
  } else if (daysMissed == 10) {
    return '10 дней. Цель "$goal" стала дальше. Вернись — пока не стало ещё дальше. 🎯';
  } else {
    return '$daysMissed дней без записи. "$goal" — это всё ещё твоя цель? Докажи. 🔥';
  }
}

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await notifications.initialize(settings: initSettings);
}

Future<bool> requestNotificationPermission() async {
  try {
    final androidPlugin = notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  } catch (_) {
    return false;
  }
}

// ─── ВОЛНА 3: Адаптивное время нотификаций ──────────────────────
// Анализируем в какое время пользователь обычно сохраняет записи.
// Храним список часов записей в 'entry_hours' как JSON-список int.
// scheduleNotifications() читает его и выбирает оптимальное время.

/// Вызывается при каждом сохранении дня.
/// Сохраняет час записи для статистики адаптивного времени.
Future<void> recordEntryTime() async {
  final prefs = await SharedPreferences.getInstance();
  final hour  = DateTime.now().hour;
  final raw   = prefs.getString('entry_hours') ?? '[]';
  final List<int> hours;
  try {
    hours = List<int>.from(jsonDecode(raw) as List);
  } catch (_) {
    return;
  }
  hours.add(hour);
  // Храним только последние 30 записей
  if (hours.length > 30) hours.removeRange(0, hours.length - 30);
  await prefs.setString('entry_hours', jsonEncode(hours));
}

/// Возвращает адаптивный час для вечернего напоминания.
/// Если данных меньше 5 — возвращает дефолт (20).
/// Иначе — медиана часов минус 30 минут (напомним чуть раньше).
int _adaptiveEveningHour(List<int> hours) {
  if (hours.length < 5) return 20;
  final sorted = List<int>.from(hours)..sort();
  final median = sorted[sorted.length ~/ 2];
  // Напоминаем за 30 минут до обычного времени записи,
  // но не раньше 18:00 и не позже 22:00
  return (median - 1).clamp(18, 22);
}

int _adaptiveEveningMinute(List<int> hours) {
  if (hours.length < 5) return 0;
  // Чередуем минуты чтобы не бить всегда ровно в час
  final seed = DateTime.now().weekday;
  return [0, 15, 30][seed % 3];
}

Future<void> scheduleNotifications() async {
  final prefs = await SharedPreferences.getInstance();

  final today = DateTime.now();
  final todayKey =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final lastScheduled = prefs.getString('notif_scheduled_date') ?? '';
  if (lastScheduled == todayKey) return;

  final goal     = prefs.getString('goal')     ?? 'твоя цель';
  final userName = prefs.getString('userName') ?? '';

  final Map entries;
  final diaryRaw = prefs.getString('diary');
  if (diaryRaw != null) {
    try { entries = jsonDecode(diaryRaw) as Map; }
    catch (_) { return; }
  } else {
    entries = jsonDecode(prefs.getString('entries') ?? '{}') as Map;
  }

  // Адаптивное время: читаем историю часов записей
  final hoursRaw = prefs.getString('entry_hours') ?? '[]';
  List<int> entryHours;
  try {
    entryHours = List<int>.from(jsonDecode(hoursRaw) as List);
  } catch (_) {
    entryHours = [];
  }

  await notifications.cancelAll();

  final now  = tz.TZDateTime.now(tz.local);
  final seed = today.year * 10000 + today.month * 100 + today.day;

  // Считаем пропущенные дни
  int daysMissed = 0;
  DateTime checkDay = DateTime.now().subtract(const Duration(days: 1));
  for (int i = 0; i < 30; i++) {
    final key =
        '${checkDay.year}-${checkDay.month.toString().padLeft(2, '0')}-${checkDay.day.toString().padLeft(2, '0')}';
    if (entries.containsKey(key)) break;
    daysMissed++;
    checkDay = checkDay.subtract(const Duration(days: 1));
  }

  // ── Утреннее уведомление — ручное время или 8:30 ─────────────
  final manualMorningH = prefs.getInt('notif_morning_hour') ?? 8;
  final manualMorningM = prefs.getInt('notif_morning_minute') ?? 30;
  var morning = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, manualMorningH, manualMorningM);
  if (morning.isBefore(now)) morning = morning.add(const Duration(days: 1));

  final morningBody = daysMissed == 0
      ? '${userName.isNotEmpty ? '$userName, не' : 'Не'} забудь записать день — займёт меньше 3 минут. Не теряй стрик! 🔥'
      : _getReturnMessage(daysMissed, goal);

  await notifications.zonedSchedule(
    id: 1,
    title: daysMissed == 0
        ? '🔥 ${userName.isNotEmpty ? userName : 'Modo'}'
        : '👀 ${userName.isNotEmpty ? '$userName, Modo скучает' : 'Modo скучает'}',
    body: morningBody,
    scheduledDate: morning,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'streak_channel', 'Стрик',
        channelDescription: 'Напоминание о дневнике',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );

  // ── Вечернее уведомление — АДАПТИВНОЕ время ─────────────────
  // Если пользователь обычно пишет в 21:30 — напомним в 20:30.
  // Если данных нет — дефолт 20:00.
  // Ручное время имеет приоритет над адаптивным
  final int eveningHour;
  final int eveningMinute;
  if (prefs.containsKey('notif_evening_hour')) {
    eveningHour   = prefs.getInt('notif_evening_hour')!;
    eveningMinute = prefs.getInt('notif_evening_minute') ?? 0;
  } else {
    eveningHour   = _adaptiveEveningHour(entryHours);
    eveningMinute = _adaptiveEveningMinute(entryHours);
  }

  var evening = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, eveningHour, eveningMinute);
  if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));

  final eveningBody = daysMissed >= 3
      ? _getReturnMessage(daysMissed, goal)
      : motivationMessages[seed % motivationMessages.length];

  await notifications.zonedSchedule(
    id: 2,
    title: daysMissed >= 3 ? '⚡ Modo' : 'Modo',
    body: eveningBody,
    scheduledDate: evening,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'motivation_channel', 'Мотивация',
        channelDescription: 'Мотивационные сообщения',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );

  await prefs.setString('notif_scheduled_date', todayKey);
}

/// Принудительно пересчитывает расписание (при изменении времени в настройках).
Future<void> forceReschedule() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('notif_scheduled_date'); // сбрасываем кеш
  await scheduleNotifications();
}

Future<void> schedulePlanReminder(String id, String text, DateTime when) async {
  if (when.isBefore(DateTime.now())) return;
  await notifications.zonedSchedule(
    id: id.hashCode,
    title: '📋 Modo',
    body: text,
    scheduledDate: tz.TZDateTime.from(when, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'plans_channel', 'Планы',
        channelDescription: 'Напоминания о планах',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}
