// android/app/src/main/kotlin/ru/modo/app/MainActivity.kt
//
// Pay SDK инициализируется автоматически через AndroidManifest.xml.
// MainActivity нужен только для нативных каналов приложения
// (виджет, sync). Billing полностью на стороне Flutter через
// flutter_rustore_pay пакет.

package ru.modo.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
