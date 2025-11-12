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
  String? _lastActiveApp;

  void startMonitoring(AppBlockerProvider provider, BuildContext context) {
    // Отключено: блокировку и таймер теперь обрабатывают нативный сервис + Provider
    debugPrint('ℹ️ AppBlockerService (Dart) отключен — используется нативный сервис и Provider');
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    // Останавливаем использование последнего приложения
    if (_lastActiveApp != null) {
      // Это будет вызвано через provider, который уже не доступен
      // Но это нормально, так как dispose вызывается при закрытии приложения
    }
    debugPrint('🔓 Остановка мониторинга');
  }

  Future<void> _checkRunningApps(AppBlockerProvider provider, BuildContext context) async {}

  void _showBlockedDialog(BuildContext context, String packageName, AppBlockerProvider provider) {}

  void dispose() {
    stopMonitoring();
  }
}