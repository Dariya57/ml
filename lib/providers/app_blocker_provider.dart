import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../services/native_app_blocker_service.dart';

class BlockedApp {
  final String packageName;
  final String appName;
  int unlockedSeconds; // Храним в секундах для точности
  DateTime? unlockStartTime; // Время начала разблокировки (null если не активна)
  String? currentActiveApp; // Какое приложение сейчас активно и расходует время

  BlockedApp({
    required this.packageName,
    required this.appName,
    this.unlockedSeconds = 0,
    this.unlockStartTime,
    this.currentActiveApp,
  });

  // Получить оставшиеся секунды с учетом активного использования
  int getRemainingSeconds() {
    if (unlockedSeconds <= 0) {
      return 0;
    }
    
    if (currentActiveApp == packageName && unlockStartTime != null) {
      // Если приложение активно, вычитаем прошедшее время
      final elapsed = DateTime.now().difference(unlockStartTime!).inSeconds;
      final remaining = unlockedSeconds - elapsed;
      return remaining > 0 ? remaining : 0;
    }
    
    return unlockedSeconds;
  }

  bool get isUnlocked => getRemainingSeconds() > 0;

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'unlockedSeconds': unlockedSeconds,
        'unlockStartTime': unlockStartTime?.toIso8601String(),
      };

  factory BlockedApp.fromJson(Map<String, dynamic> json) => BlockedApp(
        packageName: json['packageName'],
        appName: json['appName'],
        unlockedSeconds: json['unlockedSeconds'] ?? (json['unlockedMinutes'] != null ? (json['unlockedMinutes'] as int) * 60 : 0),
        unlockStartTime: json['unlockStartTime'] != null ? DateTime.parse(json['unlockStartTime']) : null,
      );
}

class AppBlockerProvider with ChangeNotifier {
  List<AppInfo> _installedApps = [];
  List<BlockedApp> _blockedApps = [];
  bool _isLoading = true;
  bool _appsFetched = false; // Флаг, чтобы не загружать список дважды
  Timer? _countdownTimer;

  List<AppInfo> get installedApps => _installedApps;
  List<BlockedApp> get blockedApps => _blockedApps;
  bool get isLoading => _isLoading;

  AppBlockerProvider() {
    // При старте загружаем ТОЛЬКО сохраненные заблокированные приложения
    _loadBlockedAppsFromPrefs();
    _startCountdownTimer();
    // Синхронизируем с нативным сервисом после загрузки (асинхронно)
    _loadBlockedAppsFromPrefs().then((_) => _syncBlockedAppsToNative());
  }

  void _startCountdownTimer() {
    // Обновляем UI каждую секунду для countdown
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Перед обновлением секунд выясняем текущее foreground-приложение из нативной части
      String fg = await NativeAppBlockerService.getForegroundApp();
      if (fg.isNotEmpty) {
        // Если foreground в списке заблокированных и есть секунды — включаем расход
        if (isAppBlocked(fg)) {
          final secs = getUnlockedSeconds(fg);
          if (secs > 0) {
            startUsingApp(fg);
          }
        }
        // Для всех остальных активных приложений — стопаем расход
        for (final app in _blockedApps) {
          if (app.currentActiveApp == app.packageName && app.packageName != fg) {
            stopUsingApp(app.packageName);
          }
        }
      }
      // Обновляем состояние для UI - просто уведомляем слушателей
      bool needsUpdate = false;
      for (var app in _blockedApps) {
        if (app.unlockStartTime != null && app.currentActiveApp == app.packageName) {
          // Приложение активно используется - обновляем секунды в реальном времени
          final elapsed = DateTime.now().difference(app.unlockStartTime!).inSeconds;
          final remaining = app.unlockedSeconds - elapsed;
          
          if (remaining <= 0) {
            // Время истекло
            app.unlockedSeconds = 0;
            app.unlockStartTime = null;
            app.currentActiveApp = null;
            needsUpdate = true;
            _saveBlockedAppsToPrefs();
            // Синхронизируем с нативным сервисом
            await NativeAppBlockerService.setUnlockedSeconds(app.packageName, 0);
          } else {
            needsUpdate = true; // Обновляем UI для показа countdown
            // Синхронизируем текущие секунды
            await NativeAppBlockerService.setUnlockedSeconds(
              app.packageName,
              app.getRemainingSeconds(),
            );
          }
        } else if (app.unlockStartTime != null && app.getRemainingSeconds() <= 0) {
          // Время истекло для неактивного приложения
          app.unlockedSeconds = 0;
          app.unlockStartTime = null;
          app.currentActiveApp = null;
          needsUpdate = true;
          await NativeAppBlockerService.setUnlockedSeconds(app.packageName, 0);
        }
      }
      if (needsUpdate) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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

  void toggleAppBlock(String packageName, String appName) async {
    if (isAppBlocked(packageName)) {
      _blockedApps.removeWhere((app) => app.packageName == packageName);
    } else {
      _blockedApps.add(BlockedApp(packageName: packageName, appName: appName));
    }
    _saveBlockedAppsToPrefs();
    await _syncBlockedAppsToNative();
    notifyListeners();
  }
  
  Future<void> _syncBlockedAppsToNative() async {
    // Синхронизируем список заблокированных приложений с нативным сервисом
    final blockedPackageNames = _blockedApps.map((app) => app.packageName).toList();
    debugPrint("📤 Syncing blocked apps to native: $blockedPackageNames");
    final success = await NativeAppBlockerService.setBlockedApps(blockedPackageNames);
    debugPrint("✅ Sync result: $success");
    
    // Проверяем что действительно сохранилось (для отладки)
    final testApps = await NativeAppBlockerService.testBlockedApps();
    debugPrint("🔍 Test: Native blocked apps = $testApps");
    
    // Синхронизируем разблокированные секунды для каждого приложения
    for (var app in _blockedApps) {
      await NativeAppBlockerService.setUnlockedSeconds(
        app.packageName,
        app.getRemainingSeconds(),
      );
    }
  }

  void addMinutesToApp(String packageName, int minutes) async {
    try {
      final app = _blockedApps.firstWhere((app) => app.packageName == packageName);
      final secondsToAdd = minutes * 60;
      app.unlockedSeconds += secondsToAdd;
      
      // Отсчет начинается только когда приложение реально используется
      // unlockStartTime будет установлен в startUsingApp
      
      _saveBlockedAppsToPrefs();
      await _syncBlockedAppsToNative();
      notifyListeners();
    } catch (e) {
      debugPrint("Приложение для добавления минут не найдено: $packageName");
    }
  }
  
  int getUnlockedSeconds(String packageName) {
    try {
      final app = _blockedApps.firstWhere((app) => app.packageName == packageName);
      return app.getRemainingSeconds();
    } catch (e) {
      return 0;
    }
  }

  // Начать расходование времени для приложения
  void startUsingApp(String packageName) async {
    try {
      final app = _blockedApps.firstWhere((app) => app.packageName == packageName);
      if (app.getRemainingSeconds() > 0 && app.currentActiveApp != packageName) {
        app.currentActiveApp = packageName;
        app.unlockStartTime = DateTime.now();
        _saveBlockedAppsToPrefs();
        await NativeAppBlockerService.setUnlockedSeconds(
          packageName,
          app.getRemainingSeconds(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Приложение не найдено для начала использования: $packageName");
    }
  }

  // Остановить расходование времени для приложения
  void stopUsingApp(String packageName) async {
    try {
      final app = _blockedApps.firstWhere((app) => app.packageName == packageName);
      if (app.currentActiveApp == packageName && app.unlockStartTime != null) {
        // Обновляем оставшиеся секунды на основе реально использованного времени
        final elapsed = DateTime.now().difference(app.unlockStartTime!).inSeconds;
        app.unlockedSeconds = (app.unlockedSeconds - elapsed).clamp(0, double.infinity).toInt();
        
        // Сбрасываем активное использование
        app.unlockStartTime = null;
        app.currentActiveApp = null;
        
        _saveBlockedAppsToPrefs();
        await NativeAppBlockerService.setUnlockedSeconds(
          packageName,
          app.getRemainingSeconds(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Приложение не найдено для остановки использования: $packageName");
    }
  }
}