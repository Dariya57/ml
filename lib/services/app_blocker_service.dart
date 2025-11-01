import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import '../providers/app_blocker_provider.dart';

class AppBlockerService {
  static final AppBlockerService _instance = AppBlockerService._internal();
  factory AppBlockerService() => _instance;
  AppBlockerService._internal();

  Timer? _monitoringTimer;
  String? _lastShownDialog;

  void startMonitoring(AppBlockerProvider provider, BuildContext context) {
    if (_monitoringTimer != null && _monitoringTimer!.isActive) return;
    
    debugPrint('🔒 Запуск мониторинга блокировки приложений');
    _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkRunningApps(provider, context);
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    debugPrint('🔓 Остановка мониторинга');
  }

  Future<void> _checkRunningApps(AppBlockerProvider provider, BuildContext context) async {
    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(hours: 1));
      List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);

      // Фильтруем и находим самое последнее использованное приложение
      infoList.sort((a, b) => b.lastForeground.compareTo(a.lastForeground));
      AppUsageInfo? topApp = infoList.isNotEmpty ? infoList.first : null;

      if (topApp != null && topApp.packageName != 'com.example.fitai') { // Замените на ваш package name
        if (provider.isAppBlocked(topApp.packageName) && provider.getUnlockedMinutes(topApp.packageName) <= 0) {
          if (_lastShownDialog != topApp.packageName && context.mounted) {
            _lastShownDialog = topApp.packageName;
            _showBlockedDialog(context, topApp.packageName, provider);
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибку, если разрешение еще не дано
    }
  }

  void _showBlockedDialog(BuildContext context, String packageName, AppBlockerProvider provider) {
    final blockedApp = provider.blockedApps.firstWhere((app) => app.packageName == packageName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Приложение заблокировано'),
            ],
          ),
          content: Text('${blockedApp.appName} заблокировано. Потренируйтесь, чтобы заработать минуты доступа.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _lastShownDialog = null;
              },
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  void dispose() {
    stopMonitoring();
  }
}