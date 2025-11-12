import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  static const _kLocaleKey = 'app_locale';

  Locale _locale = const Locale('en');

  LocaleProvider() {
    _load();
  }

  Locale get locale => _locale;
  List<Locale> get supportedLocales => const [Locale('en'), Locale('ru'), Locale('kk')];

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null && ['en','ru','kk'].contains(code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }
}


