import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  final int reps;
  final double avgQuality;
  const ResultsScreen({super.key, required this.reps, required this.avgQuality});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Отлично!', style: TextStyle(fontSize: 48)),
            Text('Выполнено: $reps повторений'),
            Text('Среднее качество: ${avgQuality.toStringAsFixed(0)}%'),
            const Text('+10 💎 заработано!'),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Готово'),
            )
          ],
        ),
      ),
    );
  }
}