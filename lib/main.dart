// ════════════════════════════════════════════════════
// main.dart — точка входа
// ════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'services/notifications.dart' as notif;
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics: ловим все Flutter-ошибки ────────────────────
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Ловим необработанные async-ошибки вне Flutter-фреймворка
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await notif.initNotifications();
  await notif.scheduleNotifications();

  runApp(const MindfulDiaryApp());
}
