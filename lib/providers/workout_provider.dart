import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/exercise_data.dart';

class WorkoutProvider with ChangeNotifier {
  int _streak = 0;
  int _currency = 0;
  DateTime? _lastWorkoutDate;
  List<WorkoutSession> _history = [];
  Map<String, int> _todayPlan = {'Приседания': 10};

  int get streak => _streak;
  int get currency => _currency;
  List<WorkoutSession> get history => _history;
  Map<String, int> get todayPlan => _todayPlan;

  WorkoutProvider() {
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt('streak') ?? 0;
    _currency = prefs.getInt('currency') ?? 0;
    final lastDateString = prefs.getString('lastWorkoutDate');
    if (lastDateString != null) {
      _lastWorkoutDate = DateTime.parse(lastDateString);
    }
    final historyString = prefs.getString('history');
    if (historyString != null) {
      final List<dynamic> historyJson = jsonDecode(historyString);
      _history = historyJson.map((json) => WorkoutSession.fromJson(json)).toList();
    }
    _todayPlan['Приседания'] = prefs.getInt('plan_squats') ?? 10;
    
    _checkStreak();
    notifyListeners();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak', _streak);
    await prefs.setInt('currency', _currency);
    if (_lastWorkoutDate != null) {
      await prefs.setString('lastWorkoutDate', _lastWorkoutDate!.toIso8601String());
    }
    final historyString = jsonEncode(_history.map((session) => session.toJson()).toList());
    await prefs.setString('history', historyString);
    await prefs.setInt('plan_squats', _todayPlan['Приседания'] ?? 10);
  }

  void completeWorkout(String exercise, int reps, double avgQuality) {
    _history.add(WorkoutSession(date: DateTime.now(), exercise: exercise, reps: reps, avgQuality: avgQuality));
    _updateStreak();
    _currency += 10;
    if (reps >= (_todayPlan[exercise] ?? 0) && avgQuality > 70) {
      _generateNextPlan(exercise);
    }
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
      final difference = DateTime.now().difference(_lastWorkoutDate!).inDays;
      if (difference > 1) {
        _streak = 0;
        saveData();
      }
    }
  }

  void _generateNextPlan(String exercise) {
    final lastReps = _todayPlan[exercise] ?? 10;
    _todayPlan[exercise] = lastReps + 1;
    notifyListeners();
  }
}