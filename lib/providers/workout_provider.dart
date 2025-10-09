import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/data_models.dart';

class WorkoutProvider with ChangeNotifier {
  int _streak = 0;
  int _currency = 0;
  DateTime? _lastWorkoutDate;
  List<WorkoutSession> _history = [];
  Map<String, int> _todayPlan = {};
  UserProfile _userProfile = UserProfile();

  int get streak => _streak;
  int get currency => _currency;
  List<WorkoutSession> get history => _history;
  Map<String, int> get todayPlan => _todayPlan;
  UserProfile get userProfile => _userProfile;

  WorkoutProvider() {
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt('streak') ?? 0;
    _currency = prefs.getInt('currency') ?? 0;
    final lastDateString = prefs.getString('lastWorkoutDate');
    if (lastDateString != null) _lastWorkoutDate = DateTime.parse(lastDateString);
    
    final historyString = prefs.getString('history');
    if (historyString != null) {
      _history = (jsonDecode(historyString) as List).map((i) => WorkoutSession.fromJson(i)).toList();
    }
    
    _userProfile.name = prefs.getString('name') ?? 'Спортсмен';
    _userProfile.age = prefs.getInt('age') ?? 20;
    _userProfile.weight = prefs.getInt('weight') ?? 70;
    _userProfile.height = prefs.getInt('height') ?? 175;
    _userProfile.gender = prefs.getString('gender') ?? 'Мужской';
    _userProfile.goal = UserGoal.values[prefs.getInt('goal') ?? 0];
    _userProfile.imagePath = prefs.getString('imagePath');
    
    _generatePlanForToday();
    _checkStreak();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _userProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', profile.name);
    await prefs.setInt('age', profile.age);
    await prefs.setInt('weight', profile.weight);
    await prefs.setInt('height', profile.height);
    await prefs.setString('gender', profile.gender);
    await prefs.setInt('goal', profile.goal.index);
    if (profile.imagePath != null) await prefs.setString('imagePath', profile.imagePath!);
    
    _generatePlanForToday();
    notifyListeners();
  }

  void completeWorkout(String exercise, int reps, double avgQuality) {
    if (reps == 0) return;
    _history.add(WorkoutSession(date: DateTime.now(), exercise: exercise, reps: reps, avgQuality: avgQuality));
    _updateStreak();
    if (reps >= (_todayPlan[exercise] ?? 0)) {
      _currency += 10;
    }
    _generatePlanForToday();
    saveData();
    notifyListeners();
  }

  void _updateStreak() {
    final now = DateTime.now();
    if (_lastWorkoutDate == null || now.day != _lastWorkoutDate!.day) {
      if (_lastWorkoutDate != null && now.difference(_lastWorkoutDate!).inDays == 1) {
        _streak++;
      } else {
        _streak = 1;
      }
      _lastWorkoutDate = now;
    }
  }

  void _checkStreak() {
    if (_lastWorkoutDate != null) {
      if (DateTime.now().difference(_lastWorkoutDate!).inDays > 1) {
        _streak = 0;
        saveData();
      }
    }
  }

  void _generatePlanForToday() {
    double baseMultiplier = 1.0;
    switch (_userProfile.goal) {
      case UserGoal.burnFat: baseMultiplier = 1.2; break;
      case UserGoal.buildMuscle: baseMultiplier = 1.5; break;
      case UserGoal.maintain: baseMultiplier = 1.0; break;
    }

    int baseSquats = (_userProfile.weight / 7.0 * baseMultiplier).round();
    int basePushups = (_userProfile.weight / 10.0 * baseMultiplier / 2).round();
    int baseCrunches = (_userProfile.weight / 5.0 * baseMultiplier).round();

    _todayPlan = {
      'Приседания': _calculateNextReps('Приседания', baseSquats),
      'Отжимания': _calculateNextReps('Отжимания', basePushups),
      'Пресс': _calculateNextReps('Пресс', baseCrunches),
    };
    saveData();
  }

  int _calculateNextReps(String exercise, int baseReps) {
    final lastSession = _history.where((s) => s.exercise == exercise).lastOrNull;
    if (lastSession == null) return baseReps;
    
    if (DateTime.now().difference(lastSession.date).inDays > 7) {
      return (lastSession.reps * 0.8).round(); // Откат после долгого перерыва
    }
    
    if (lastSession.avgQuality > 70) {
      return (lastSession.reps * 1.1).round(); // Прогрессивная перегрузка
    }
    
    return lastSession.reps; // Повторяем, если техника хромает
  }

  Future<void> saveData() async {
    // Сохраняем все данные
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak', _streak);
    await prefs.setInt('currency', _currency);
    if (_lastWorkoutDate != null) await prefs.setString('lastWorkoutDate', _lastWorkoutDate!.toIso8601String());
    final historyString = jsonEncode(_history.map((s) => s.toJson()).toList());
    await prefs.setString('history', historyString);
  }
}