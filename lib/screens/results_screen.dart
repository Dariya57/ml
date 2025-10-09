import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  final int reps;
  final double avgQuality;
  final Map<String, int> errorCounts;
  
  const ResultsScreen({super.key, required this.reps, required this.avgQuality, required this.errorCounts});

  @override
  Widget build(BuildContext context) {
    final errorWidgets = errorCounts.entries.map((entry) {
      return Text('"${entry.key}" - ${entry.value} раз(а)', style: const TextStyle(color: Colors.redAccent));
    }).toList();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 100),
              const SizedBox(height: 24),
              const Text('Отлично!', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Выполнено: $reps повторений'),
              Text('Среднее качество: ${avgQuality.toStringAsFixed(0)}%'),
              const SizedBox(height: 16),
              if (errorWidgets.isNotEmpty) ...[
                const Text('Основные ошибки:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...errorWidgets,
              ],
              const SizedBox(height: 16),
              const Text('+10 💎 заработано!'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Готово'),
              )
            ],
          ),
        ),
      ),
    );
  }
}