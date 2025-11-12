import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/workout_provider.dart';
import 'workout_screen.dart';
import '../models/data_models.dart';
import '../utils/strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    
    final exerciseWidgets = provider.todayPlan.entries
        .where((entry) => entry.key != 'Пресс')
        .map((entry) {
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

      final S = AppStrings.of(context);
      final localizedName = () {
        if (exerciseName == 'Приседания') return S.squats;
        if (exerciseName == 'Отжимания') return S.pushups;
        if (exerciseName == 'Пресс') return S.crunches;
        return exerciseName;
      }();

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          title: Text(localizedName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          subtitle: Text(AppStrings.of(context).goalReps(targetReps)),
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

    final S = AppStrings.of(context);
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
          Text(
            {
              'en': "Today's workout:",
              'ru': 'Тренировка на сегодня:',
              'kk': 'Бүгінгі жаттығу:',
            }[Localizations.localeOf(context).languageCode]!,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (exerciseWidgets.isNotEmpty)
            ...exerciseWidgets
          else
            Center(child: Text({
              'en': "Great job! Today's plan is done.",
              'ru': 'Вы отлично поработали! План на сегодня выполнен.',
              'kk': 'Жақсы жұмыс! Бүгінгі жоспар орындалды.',
            }[Localizations.localeOf(context).languageCode]!)),
          const SizedBox(height: 32),
          Text({
            'en': 'Weekly statistics',
            'ru': 'Статистика за неделю',
            'kk': 'Апталық статистика',
          }[Localizations.localeOf(context).languageCode]!, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RotatedBox(
                quarterTurns: 3,
                child: Text(AppStrings.of(context).axisReps, style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: provider.history.isEmpty
                      ? Center(child: Text({
                          'en': 'No chart data yet',
                          'ru': 'Данных для графика пока нет',
                          'kk': 'График үшін деректер жоқ',
                        }[Localizations.localeOf(context).languageCode]!))
                      : LineChart(mainData(provider.history, context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(child: Text(AppStrings.of(context).axisDays, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }

  LineChartData mainData(List<WorkoutSession> history, BuildContext context) {
    // Берём последние 7 сессий для недели
    final recent = history.length <= 7 ? history : history.sublist(history.length - 7);
    final spots = recent.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.reps.toDouble())).toList();
    final avg = spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a,b)=>a+b) / spots.length;
    final labels = recent.map((s){
      final wd = s.date.weekday; // 1..7
      return AppStrings.of(context).weekdayShort(wd);
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _niceInterval(spots.map((s)=>s.y).toList()),
        getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.outline.withOpacity(0.2), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(labels[i], style: const TextStyle(fontSize: 10)),
            );
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2))),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(
          y: avg,
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
          strokeWidth: 1,
          dashArray: [6,4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
            labelResolver: (line) => {
              'en': 'Avg: ${avg.toStringAsFixed(0)}',
              'ru': 'Среднее: ${avg.toStringAsFixed(0)}',
              'kk': 'Орташа: ${avg.toStringAsFixed(0)}',
            }[Localizations.localeOf(context).languageCode]!,
          ),
        )
      ]),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.primary,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withOpacity(0.20)),
        ),
      ],
    );
  }

  double _niceInterval(List<double> values) {
    if (values.isEmpty) return 10;
    final maxVal = values.reduce((a,b)=>a>b?a:b);
    final rough = (maxVal/4).clamp(5, 50);
    return rough.toDouble();
  }
}