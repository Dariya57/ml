import 'dart:io'; // <-- ВОТ ГДЕ БЫЛА ОШИБКА
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../models/data_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late UserProfile _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profile = context.watch<WorkoutProvider>().userProfile;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profile.imagePath = image.path;
      });
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      context.read<WorkoutProvider>().saveProfile(_profile);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль сохранен!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: _profile.imagePath != null ? FileImage(File(_profile.imagePath!)) : null,
                  child: _profile.imagePath == null ? const Icon(Icons.person, size: 60) : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _profile.name,
              decoration: const InputDecoration(labelText: 'Имя'),
              onSaved: (value) => _profile.name = value ?? 'Спортсмен',
            ),
            TextFormField(
              initialValue: _profile.age.toString(),
              decoration: const InputDecoration(labelText: 'Возраст'),
              keyboardType: TextInputType.number,
              onSaved: (value) => _profile.age = int.tryParse(value ?? '20') ?? 20,
            ),
            TextFormField(
              initialValue: _profile.weight.toString(),
              decoration: const InputDecoration(labelText: 'Вес (кг)'),
              keyboardType: TextInputType.number,
              onSaved: (value) => _profile.weight = int.tryParse(value ?? '70') ?? 70,
            ),
            TextFormField(
              initialValue: _profile.height.toString(),
              decoration: const InputDecoration(labelText: 'Рост (см)'),
              keyboardType: TextInputType.number,
              onSaved: (value) => _profile.height = int.tryParse(value ?? '175') ?? 175,
            ),
            DropdownButtonFormField<String>(
              value: _profile.gender,
              items: ['Мужской', 'Женский'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (newValue) {
                setState(() => _profile.gender = newValue!);
              },
              decoration: const InputDecoration(labelText: 'Пол'),
            ),
            DropdownButtonFormField<UserGoal>(
              value: _profile.goal,
              items: UserGoal.values.map((UserGoal goal) {
                String text;
                switch (goal) {
                  case UserGoal.burnFat: text = 'Сжечь жир'; break;
                  case UserGoal.buildMuscle: text = 'Накачать мышцы'; break;
                  case UserGoal.maintain: text = 'Поддерживать форму'; break;
                }
                return DropdownMenuItem<UserGoal>(value: goal, child: Text(text));
              }).toList(),
              onChanged: (newValue) {
                setState(() => _profile.goal = newValue!);
              },
              decoration: const InputDecoration(labelText: 'Цель'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saveProfile, child: const Text('Сохранить'))
          ],
        ),
      ),
    );
  }
}