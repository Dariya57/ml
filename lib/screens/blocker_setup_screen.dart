import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/native_app_blocker_service.dart';
import '../utils/strings.dart';

class BlockerSetupScreen extends StatefulWidget {
  const BlockerSetupScreen({super.key});

  @override
  State<BlockerSetupScreen> createState() => _BlockerSetupScreenState();
}

class _BlockerSetupScreenState extends State<BlockerSetupScreen> {
  bool _hasUsagePermission = false;
  bool _hasAccessibilityService = false;
  bool _checking = false;
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checking = true);
    
    try {
      // Проверяем разрешение на статистику использования
      final now = DateTime.now();
      try {
        await AppUsage().getAppUsage(
          now.subtract(const Duration(seconds: 1)),
          now,
        );
        setState(() => _hasUsagePermission = true);
      } catch (e) {
        setState(() => _hasUsagePermission = false);
      }
      
      // Проверяем Accessibility Service
      final accessibilityEnabled = await NativeAppBlockerService.isAccessibilityEnabled();
      setState(() => _hasAccessibilityService = accessibilityEnabled);

      // Проверяем Overlay permission
      final overlayGranted = await NativeAppBlockerService.isOverlayGranted();
      setState(() => _hasOverlayPermission = overlayGranted);
    } catch (e) {
      setState(() => _hasUsagePermission = false);
      setState(() => _hasAccessibilityService = false);
    }
    
    setState(() => _checking = false);
  }

  Future<void> _requestUsagePermission() async {
    try {
      // Открываем настройки для предоставления разрешения
      await openAppSettings();
      
      // Ждем и проверяем снова
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _requestAccessibilityService() async {
    try {
      // Открываем настройки Accessibility
      await NativeAppBlockerService.openAccessibilitySettings();
      
      // Ждем и проверяем снова
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final S = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.blockingSetup),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.lightBlueAccent, size: 30),
                            SizedBox(width: 12),
                            Expanded(child: Text({
                              'en':'How blocking works',
                              'ru':'Как работает блокировка',
                              'kk':'Блоктау қалай жұмыс істейді',
                            }[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text({
                          'en':'FitAI blocks selected apps and prevents launching them without unlock.',
                          'ru':'FitAI блокирует выбранные приложения и не позволяет их запускать без разблокировки.',
                          'kk':'FitAI таңдалған қолданбаларды бұғаттайды және ашуға жол бермейді.',
                        }[Localizations.localeOf(context).languageCode]!),
                        const SizedBox(height: 12),
                        Text({
                          'en':'Requires:',
                          'ru':'Для работы требуется:',
                          'kk':'Қажет:',
                        }[Localizations.localeOf(context).languageCode]!),
                        const SizedBox(height: 8),
                        Text({
                          'en':'• Usage Access permission',
                          'ru':'• Разрешение "Доступ к статистике использования"',
                          'kk':'• Пайдалану статистикасына қолжетімділік',
                        }[Localizations.localeOf(context).languageCode]!),
                        Text({
                          'en':'• Accessibility Service enabled',
                          'ru':'• Включенная служба специальных возможностей',
                          'kk':'• Арнайы мүмкіндіктер қызметі қосулы',
                        }[Localizations.localeOf(context).languageCode]!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Статистика использования
                Card(
                  color: _hasUsagePermission
                      ? Colors.green.shade900.withOpacity(0.3)
                      : Colors.red.shade900.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _hasUsagePermission
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _hasUsagePermission
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text({
                              'en':'Usage Access',
                              'ru':'Доступ к статистике использования',
                              'kk':'Пайдалану статистикасы',
                            }[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(_hasUsagePermission
                            ? ({'en':'Permission granted ✓','ru':'Разрешение предоставлено ✓','kk':'Рұқсат берілді ✓'}[Localizations.localeOf(context).languageCode]!)
                            : ({'en':'Required to track app usage','ru':'Требуется для отслеживания использования приложений','kk':'Қолданбаларды пайдалануын бақылау үшін қажет'}[Localizations.localeOf(context).languageCode]!)),
                        if (!_hasUsagePermission) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _requestUsagePermission,
                            icon: const Icon(Icons.settings),
                            label: Text({'en':'Open settings','ru':'Открыть настройки','kk':'Баптауларды ашу'}[Localizations.localeOf(context).languageCode]!),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Overlay permission
                Card(
                  color: _hasOverlayPermission
                      ? Colors.green.shade900.withOpacity(0.3)
                      : Colors.red.shade900.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _hasOverlayPermission
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _hasOverlayPermission
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text({
                              'en':'Draw over other apps',
                              'ru':'Показ поверх других приложений',
                              'kk':'Басқа қолданбалардың үстінен көрсету',
                            }[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(_hasOverlayPermission
                            ? ({'en':'Permission granted ✓','ru':'Разрешение выдано ✓','kk':'Рұқсат берілді ✓'}[Localizations.localeOf(context).languageCode]!)
                            : ({'en':'Needed to show blocking overlay','ru':'Нужно для показа блокирующего экрана','kk':'Блоктау қабатын көрсету үшін қажет'}[Localizations.localeOf(context).languageCode]!)),
                        if (!_hasOverlayPermission) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await NativeAppBlockerService.openOverlaySettings();
                              await Future.delayed(const Duration(seconds: 2));
                              await _checkPermissions();
                            },
                            icon: const Icon(Icons.layers),
                            label: Text({'en':'Grant permission','ru':'Выдать разрешение','kk':'Рұқсат беру'}[Localizations.localeOf(context).languageCode]!),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Accessibility Service
                Card(
                  color: _hasAccessibilityService
                      ? Colors.green.shade900.withOpacity(0.3)
                      : Colors.red.shade900.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _hasAccessibilityService
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _hasAccessibilityService
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text({
                              'en':'Accessibility Service',
                              'ru':'Служба специальных возможностей',
                              'kk':'Арнайы мүмкіндіктер қызметі',
                            }[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _hasAccessibilityService
                              ? ({'en':'Service enabled ✓','ru':'Служба включена ✓','kk':'Қызмет қосулы ✓'}[Localizations.localeOf(context).languageCode]!)
                              : ({'en':'Required for real app blocking','ru':'Требуется для реальной блокировки приложений','kk':'Қолданбаларды нақты бұғаттау үшін қажет'}[Localizations.localeOf(context).languageCode]!),
                          style: TextStyle(color: _hasAccessibilityService ? Colors.greenAccent : Colors.redAccent),
                        ),
                        if (!_hasAccessibilityService) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _requestAccessibilityService,
                            icon: const Icon(Icons.accessibility_new),
                            label: Text({'en':'Enable service','ru':'Включить службу','kk':'Қызметті қосу'}[Localizations.localeOf(context).languageCode]!),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text({'en':'📝 Instructions','ru':'📝 Инструкция','kk':'📝 Нұсқаулық'}[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text({'en':'For "Usage Access":','ru':'Для "Доступа к статистике использования":','kk':'"Пайдалану статистикасы" үшін:'}[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildStep('1', {'en':'Tap "Open settings"','ru':'Нажмите "Открыть настройки"','kk':'"Баптауларды ашу" батырмасын басыңыз'}[Localizations.localeOf(context).languageCode]!),
                        _buildStep('2', {'en':'Find FitAI in the list','ru':'Найдите FitAI в списке приложений','kk':'Тізімнен FitAI табыңыз'}[Localizations.localeOf(context).languageCode]!),
                        _buildStep('3', {'en':'Enable "Usage Access"','ru':'Включите "Доступ к статистике использования"','kk':'"Пайдалану статистикасына" рұқсат беріңіз'}[Localizations.localeOf(context).languageCode]!),
                        const SizedBox(height: 16),
                        Text({'en':'For "Accessibility Service":','ru':'Для "Службы специальных возможностей":','kk':'"Арнайы мүмкіндіктер қызметі" үшін:'}[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildStep('1', {'en':'Tap "Enable service"','ru':'Нажмите "Включить службу"','kk':'"Қызметті қосу" түймесін басыңыз'}[Localizations.localeOf(context).languageCode]!),
                        _buildStep('2', {'en':'Find FitAI in the services list','ru':'Найдите FitAI в списке служб','kk':'Қызметтер тізімінен FitAI табыңыз'}[Localizations.localeOf(context).languageCode]!),
                        _buildStep('3', {'en':'Enable the switch for FitAI','ru':'Включите переключатель для FitAI','kk':'FitAI үшін ауыстырғышты қосыңыз'}[Localizations.localeOf(context).languageCode]!),
                        _buildStep('4', {'en':'Confirm in the dialog','ru':'Подтвердите во всплывающем окне','kk':'Диалогта растаңыз'}[Localizations.localeOf(context).languageCode]!),
                        _buildStep('5', {'en':'Return to the app','ru':'Вернитесь в приложение','kk':'Қолданбаға оралыңыз'}[Localizations.localeOf(context).languageCode]!),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  color: Colors.orangeAccent),
                              SizedBox(width: 8),
                              Expanded(child: Text({
                                'en':'This is a standard Android permission for app usage tracking.',
                                'ru':'Это стандартное Android разрешение для отслеживания использования приложений.',
                                'kk':'Бұл қолданбаларды пайдалануын бақылауға арналған стандартты Android рұқсаты.',
                              }[Localizations.localeOf(context).languageCode]!, style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checkPermissions,
                  child: Text({'en':'Check again','ru':'Проверить снова','kk':'Қайта тексеру'}[Localizations.localeOf(context).languageCode]!),
                ),
              ],
            ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}