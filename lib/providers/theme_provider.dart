// theme_provider.dart
//
// App 層級的外觀設定狀態：深淺色模式（themeMode）+ 筆記字級（textScale）。
// mobile 與 web 兩個 entry 共用同一個 ThemeProvider，設定 Tab 改它、MaterialApp
// 讀它。
//
// 持久化：用 shared_preferences 存（mobile 走原生、web 走 localStorage）。
// 為什麼在建構式非同步載入而非 main() 先 await：
// - 不必把 main() 改成 async、也不必把 prefs 一路傳進 widget tree
// - getInstance() 很快，第一幀本來就是 loading 畫面，載入完 notifyListeners 即更新
// - _load() 包 try/catch：測試環境沒有 plugin 時不會丟出未捕捉的非同步錯誤

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _load();
  }

  static const _kThemeModeKey = 'settings.themeMode';
  static const _kTextScaleKey = 'settings.textScale';

  // 字級段階：小 / 標準 / 大 / 特大。設定 Tab 與這裡共用同一組值，
  // SegmentedButton 的 selected 才能精準對上其中一個。
  static const List<double> textScaleSteps = [0.9, 1.0, 1.15, 1.3];
  static const double defaultTextScale = 1.0;

  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = defaultTextScale;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_kThemeModeKey);
      if (modeIndex != null &&
          modeIndex >= 0 &&
          modeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[modeIndex];
      }
      final scale = prefs.getDouble(_kTextScaleKey);
      if (scale != null && textScaleSteps.contains(scale)) {
        _textScale = scale;
      }
      notifyListeners();
    } catch (_) {
      // 讀取失敗（如測試環境無 plugin）就維持預設值，不影響 App 運作
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kThemeModeKey, mode.index);
    } catch (_) {
      // 持久化失敗不影響當前 session 的切換效果
    }
  }

  Future<void> setTextScale(double scale) async {
    if (scale == _textScale) return;
    _textScale = scale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kTextScaleKey, scale);
    } catch (_) {
      // 同上
    }
  }
}
