import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:permission_handler/permission_handler.dart';

class BlockerSetupScreen extends StatefulWidget {
  const BlockerSetupScreen({super.key});

  @override
  State<BlockerSetupScreen> createState() => _BlockerSetupScreenState();
}

class _BlockerSetupScreenState extends State<BlockerSetupScreen> {
  bool _hasUsagePermission = false;
  bool _checking = false;

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
      await AppUsage().getAppUsage(
        now.subtract(const Duration(seconds: 1)),
        now,
      );
      setState(() => _hasUsagePermission = true);
    } catch (e) {
      setState(() => _hasUsagePermission = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка блокировки'),
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
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.lightBlueAccent, size: 30),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Как работает блокировка',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'FitAI отслеживает использование заблокированных приложений и показывает предупреждение, когда вы пытаетесь их открыть.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Для работы требуется разрешение "Доступ к статистике использования".',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                            Expanded(
                              child: Text(
                                _hasUsagePermission
                                    ? 'Разрешение предоставлено'
                                    : 'Требуется разрешение',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _hasUsagePermission
                              ? 'Блокировка приложений работает! ✓'
                              : 'Для блокировки нужен доступ к статистике',
                        ),
                        if (!_hasUsagePermission) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _requestUsagePermission,
                            icon: const Icon(Icons.settings),
                            label: const Text('Открыть настройки'),
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
                        const Text(
                          '📝 Инструкция',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStep('1', 'Нажмите "Открыть настройки"'),
                        _buildStep('2',
                            'Найдите FitAI в списке приложений'),
                        _buildStep('3',
                            'Включите разрешение "Доступ к статистике использования"'),
                        _buildStep('4', 'Вернитесь в приложение'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  color: Colors.orangeAccent),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Это стандартное Android разрешение для отслеживания использования приложений.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
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
                  child: const Text('Проверить снова'),
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