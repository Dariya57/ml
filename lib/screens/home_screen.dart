import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/workout_provider.dart';
import 'workout_screen.dart';
import '../models/data_models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    
    final exerciseWidgets = provider.todayPlan.entries.map((entry) {
      final exerciseName = entry.key;
      final targetReps = entry.value;
      ExerciseType exerciseType;
      IconData icon;

      switch (exerciseName) {
        case 'Отжимания':
          exerciseType = ExerciseType.pushups;
          icon = Icons.fitness_center;
          break;
        case 'Пресс':
          exerciseType = ExerciseType.crunches;
          icon = Icons.self_improvement;
          break;
        default:
          exerciseType = ExerciseType.squats;
          icon = Icons.sports_gymnastics_rounded;
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          title: Text(exerciseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          subtitle: Text('Цель: $targetReps повторений'),
          trailing: const Icon(Icons.play_circle_outline, size: 30),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutScreen(
                  targetReps: targetReps,
                  exerciseType: exerciseType,
                  exerciseName: exerciseName,
                ),
              ),
            );
          },
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitAI'),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('🔥 ${provider.streak}', style: const TextStyle(fontSize: 18)))),
          Center(child: Padding(padding: const EdgeInsets.only(right: 16.0), child: Text('💎 ${provider.currency}', style: const TextStyle(fontSize: 18)))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Тренировка на сегодня:', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (exerciseWidgets.isNotEmpty)
            ...exerciseWidgets
          else
            const Center(child: Text('Вы отлично поработали! План на сегодня выполнен.')),
          const SizedBox(height: 32),
          Text('Прогресс за неделю (повторения):', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: provider.history.isEmpty
                ? const Center(child: Text('Данных для графика пока нет'))
                : LineChart(mainData(provider.history, context)),
          ),
        ],
      ),
    );
  }

  LineChartData mainData(List<WorkoutSession> history, BuildContext context) {
    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.reps.toDouble());
    }).toList();

    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.primary,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}