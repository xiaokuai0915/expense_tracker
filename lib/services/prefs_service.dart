import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const String _keyMonthlyBudget = 'monthly_budget';
  static const String _keyCurrency = 'currency';
  static const String _keyIsFirstLaunch = 'isFirstLaunch';
  static const String _keyIsDarkMode = 'is_dark_mode';

  static Future<void> saveInitialSettings({
    required double budget,
    required String currency,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMonthlyBudget, budget);
    await prefs.setString(_keyCurrency, currency);
    await prefs.setBool(_keyIsFirstLaunch, false);
    await prefs.setBool(_keyIsDarkMode, true);
  }

  static Future<double> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMonthlyBudget) ?? 1000.0;
  }

  static Future<void> setMonthlyBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMonthlyBudget, budget);
  }

  static Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrency) ?? 'RM';
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsDarkMode) ?? true;
  }

  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDarkMode, isDark);
  }
}