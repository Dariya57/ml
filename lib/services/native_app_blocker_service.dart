import 'package:flutter/services.dart';

class NativeAppBlockerService {
  static const MethodChannel _channel = MethodChannel('com.example.pp/app_blocker');

  /// Установить список заблокированных приложений
  static Future<bool> setBlockedApps(List<String> packageNames) async {
    try {
      final result = await _channel.invokeMethod<bool>('setBlockedApps', packageNames);
      return result ?? false;
    } catch (e) {
      print('Error setting blocked apps: $e');
      return false;
    }
  }

  /// Установить количество разблокированных секунд для приложения
  static Future<bool> setUnlockedSeconds(String packageName, int seconds) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setUnlockedSeconds',
        {
          'packageName': packageName,
          'seconds': seconds,
        },
      );
      return result ?? false;
    } catch (e) {
      print('Error setting unlocked seconds: $e');
      return false;
    }
  }

  /// Проверить, включена ли Accessibility Service
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      print('Error checking accessibility: $e');
      return false;
    }
  }

  /// Открыть настройки Accessibility
  static Future<bool> openAccessibilitySettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return result ?? false;
    } catch (e) {
      print('Error opening accessibility settings: $e');
      return false;
    }
  }

  /// Тест - получить список заблокированных приложений из нативного кода
  static Future<List<String>> testBlockedApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('testBlockedApps');
      return result?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      print('Error testing blocked apps: $e');
      return [];
    }
  }

  static Future<bool> isOverlayGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayGranted');
      return result ?? false;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  static Future<bool> openOverlaySettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openOverlaySettings');
      return result ?? false;
    } catch (e) {
      print('Error opening overlay settings: $e');
      return false;
    }
  }

  static Future<String> getForegroundApp() async {
    try {
      final result = await _channel.invokeMethod<String>('getForegroundApp');
      return result ?? '';
    } catch (e) {
      print('Error getting foreground app: $e');
      return '';
    }
  }
}

