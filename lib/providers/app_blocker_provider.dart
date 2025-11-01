import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class BlockedApp {
  final String packageName;
  final String appName;
  int unlockedMinutes;

  BlockedApp({
    required this.packageName,
    required this.appName,
    this.unlockedMinutes = 0,
  });

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'unlockedMinutes': unlockedMinutes,
      };

  factory BlockedApp.fromJson(Map<String, dynamic> json) => BlockedApp(
        packageName: json['packageName'],
        appName: json['appName'],
        unlockedMinutes: json['unlockedMinutes'] ?? 0,
      );
}

class AppBlockerProvider with ChangeNotifier {
  List<AppInfo> _installedApps = [];
  List<BlockedApp> _blockedApps = [];
  bool _isLoading = true;
  bool _appsFetched = false; // Флаг, чтобы не загружать список дважды

  List<AppInfo> get installedApps => _installedApps;
  List<BlockedApp> get blockedApps => _blockedApps;
  bool get isLoading => _isLoading;

  AppBlockerProvider() {
    // При старте загружаем ТОЛЬКО сохраненные заблокированные приложения
    _loadBlockedAppsFromPrefs();
  }

  // НОВЫЙ МЕТОД: Загружает список приложений, только если он еще не был загружен
  Future<void> fetchAppsIfNeeded() async {
    if (_appsFetched) return;

    _isLoading = true;
    notifyListeners();

    await _fetchInstalledApps();
    _appsFetched = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchInstalledApps() async {
    try {
      _installedApps = await InstalledApps.getInstalledApps(true, true);
      _installedApps.sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));
    } catch (e) {
      debugPrint("Ошибка получения установленных приложений: $e");
    }
  }

  Future<void> _loadBlockedAppsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedAppsJson = prefs.getStringList('blockedApps') ?? [];
    _blockedApps = blockedAppsJson
        .map((jsonString) => BlockedApp.fromJson(jsonDecode(jsonString)))
        .toList();
    notifyListeners(); // Уведомляем об изменениях
  }

  Future<void> _saveBlockedAppsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedAppsJson =
        _blockedApps.map((app) => jsonEncode(app.toJson())).toList();
    await prefs.setStringList('blockedApps', blockedAppsJson);
  }

  bool isAppBlocked(String packageName) {
    return _blockedApps.any((app) => app.packageName == packageName);
  }

  void toggleAppBlock(String packageName, String appName) {
    if (isAppBlocked(packageName)) {
      _blockedApps.removeWhere((app) => app.packageName == packageName);
    } else {
      _blockedApps.add(BlockedApp(packageName: packageName, appName: appName));
    }
    _saveBlockedAppsToPrefs();
    notifyListeners();
  }

  void addMinutesToApp(String packageName, int minutes) {
    try {
      final app = _blockedApps.firstWhere((app) => app.packageName == packageName);
      app.unlockedMinutes += minutes;
      _saveBlockedAppsToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint("Приложение для добавления минут не найдено: $packageName");
    }
  }
  
  int getUnlockedMinutes(String packageName) {
    try {
      return _blockedApps.firstWhere((app) => app.packageName == packageName).unlockedMinutes;
    } catch (e) {
      return 0;
    }
  }
}