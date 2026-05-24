// ════════════════════════════════════════════════════
// screens/ratings_screen.dart — оценка дня по 5 метрикам
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../utils/ui_helpers.dart';

class RatingsScreen extends StatefulWidget {
  final List<String> answers;
  const RatingsScreen({super.key, required this.answers});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  double _energy       = 5;
  double _productivity = 5;
  double _mood         = 5;
  double _food         = 5;
  double _sleep        = 5;

  // Запоминаем предыдущее значение чтобы вибрировать только при смене деления
  final Map<String, int> _prevRounded = {
    'energy': 5, 'productivity': 5, 'mood': 5, 'food': 5, 'sleep': 5,
  };

  void _done() {
    hapticSuccess(); // ← сохранение дня
    Navigator.pop(context, {
      'answers': widget.answers,
      'ratings': {
        'energy':       _energy.round(),
        'productivity': _productivity.round(),
        'mood':         _mood.round(),
        'food':         _food.round(),
        'sleep':        _sleep.round(),
      },
    });
  }

  void _onSliderChanged(String key, double value, void Function(double) setter) {
    final rounded = value.round();
    if (rounded != _prevRounded[key]) {
      hapticLight(); // ← вибрация при смене деления слайдера
      _prevRounded[key] = rounded;
    }
    setState(() => setter(value));
  }

  Widget _slider(
    String emoji,
    String label,
    String key,
    double value,
    Color metricColor,
    void Function(double) setter,
  ) {
    final isDark    = Theme.of(context).brightness == Brightness.dark; // FIX UI-1
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final rounded   = value.round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w600, color: textColor)),
              ]),
              // Значение в цветном бейдже
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: metricColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$rounded',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: metricColor,
              inactiveTrackColor: metricColor.withValues(alpha: 0.15),
              thumbColor: metricColor,
              overlayColor: metricColor.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 0, max: 10, divisions: 10,
              onChanged: (v) => _onSliderChanged(key, v, setter),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark; // FIX UI-1
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent    = AppSettings.of(context).accent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          // SCREEN FIX 3: SingleChildScrollView + Column без Spacer спасает от overflow
          // на устройствах с маленькой высотой (landscape, Galaxy Fold внешний экран,
          // Pixel 4a 5G в режиме split-screen).
          // Кнопка «Сохранить» прилипает к низу через MediaQuery.padding.bottom.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Оцени день',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                      color: textColor)),
              const SizedBox(height: 4),
              Text('Сдвигай до нужного деления',
                  style: TextStyle(fontSize: 14,
                      color: textColor.withValues(alpha: 0.4))),
              const SizedBox(height: 28),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _slider('😴', 'Энергия',       'energy',       _energy,
                          AppColors.metricEnergy,       (v) => _energy = v),
                      _slider('🎯', 'Продуктивность', 'productivity', _productivity,
                          AppColors.metricProductivity, (v) => _productivity = v),
                      _slider('🧠', 'Настроение',    'mood',         _mood,
                          AppColors.metricMood,         (v) => _mood = v),
                      _slider('🍎', 'Еда',           'food',         _food,
                          AppColors.metricFood,         (v) => _food = v),
                      _slider('💤', 'Сон',           'sleep',        _sleep,
                          AppColors.metricSleep,        (v) => _sleep = v),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text('Сохранить день ✓',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
