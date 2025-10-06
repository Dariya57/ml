import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/workout_provider.dart';
import 'workout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Jarys'),
            actions: [
              Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('🔥 ${provider.streak}'))),
              Center(child: Padding(padding: const EdgeInsets.only(right: 16.0), child: Text('💎 ${provider.currency}'))),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тренировка на сегодня:', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: Text(provider.todayPlan.keys.first, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Цель: ${provider.todayPlan.values.first} повторений'),
                    trailing: const Icon(Icons.fitness_center),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutScreen(targetReps: provider.todayPlan.values.first)));
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text('Прогресс за неделю:', style: Theme.of(context).textTheme.headlineSmall),
                Expanded(
                  child: provider.history.isEmpty
                      ? const Center(child: Text('Вы еще не тренировались'))
                      : LineChart(mainData(provider.history)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  LineChartData mainData(List<dynamic> history) {
    // Логика для создания графика
    return LineChartData(/* ... */);
  }
}