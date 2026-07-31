import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppVisualStyle { material, uix }

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  static const _themeKey = 'app_theme_mode';
  static const _styleKey = 'app_visual_style';
  static const _showMessKey = 'show_mess';
  static const _floatingNavigationKey = 'floating_navigation';
  static const _glassNavigationKey = 'glass_navigation';
  static const _chromeBlurKey = 'chrome_blur';
  static const _predictiveBackKey = 'predictive_back';

  ThemeMode _themeMode = ThemeMode.system;
  AppVisualStyle _visualStyle = AppVisualStyle.material;
  bool _showMess = false;
  bool _floatingNavigation = false;
  bool _glassNavigation = false;
  bool _chromeBlur = false;
  bool _predictiveBack = true;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  AppVisualStyle get visualStyle => _visualStyle;
  bool get showMess => _showMess;
  bool get floatingNavigation => _floatingNavigation;
  bool get glassNavigation => _glassNavigation;
  bool get chromeBlur => _chromeBlur;
  bool get predictiveBack => _predictiveBack;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == preferences.getString(_themeKey),
      orElse: () => ThemeMode.system,
    );
    final storedStyle = preferences.getString(_styleKey);
    _visualStyle = AppVisualStyle.values.firstWhere(
      (style) => style.name == (storedStyle == 'miui' ? 'uix' : storedStyle),
      orElse: () => AppVisualStyle.material,
    );
    _showMess = preferences.getBool(_showMessKey) ?? false;
    _floatingNavigation = preferences.getBool(_floatingNavigationKey) ?? false;
    _glassNavigation = preferences.getBool(_glassNavigationKey) ?? false;
    _chromeBlur = preferences.getBool(_chromeBlurKey) ?? false;
    _predictiveBack = preferences.getBool(_predictiveBackKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, mode.name);
  }

  Future<void> setVisualStyle(AppVisualStyle style) async {
    if (_visualStyle == style) return;
    _visualStyle = style;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_styleKey, style.name);
  }

  Future<void> setShowMess(bool value) => _setBool(
    value: value,
    current: _showMess,
    key: _showMessKey,
    update: (next) => _showMess = next,
  );

  Future<void> setFloatingNavigation(bool value) => _setBool(
    value: value,
    current: _floatingNavigation,
    key: _floatingNavigationKey,
    update: (next) => _floatingNavigation = next,
  );

  Future<void> setGlassNavigation(bool value) => _setBool(
    value: value,
    current: _glassNavigation,
    key: _glassNavigationKey,
    update: (next) => _glassNavigation = next,
  );

  Future<void> setChromeBlur(bool value) => _setBool(
    value: value,
    current: _chromeBlur,
    key: _chromeBlurKey,
    update: (next) => _chromeBlur = next,
  );

  Future<void> setPredictiveBack(bool value) => _setBool(
    value: value,
    current: _predictiveBack,
    key: _predictiveBackKey,
    update: (next) => _predictiveBack = next,
  );

  Future<void> _setBool({
    required bool value,
    required bool current,
    required String key,
    required ValueChanged<bool> update,
  }) async {
    if (value == current) return;
    update(value);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }
}
