import 'dart:io'; // <-- ВОТ ГДЕ БЫЛА ОШИБКА
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/strings.dart';
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
    // Normalize legacy gender values saved in different languages to stable codes
    _profile.gender = _normalizeGender(_profile.gender);
  }

  String _normalizeGender(String? value) {
    final v = (value ?? '').toLowerCase();
    if (v == 'male' || v == 'мужской' || v == 'ер') return 'male';
    if (v == 'female' || v == 'женский' || v == 'әйел') return 'female';
    return 'male';
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
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final S = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.settingsTitle)),
      body: Form(
        key: _formKey,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
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
              decoration: InputDecoration(labelText: S.name),
              onSaved: (value) => _profile.name = value ?? 'Athlete',
            ),
            TextFormField(
              initialValue: _profile.lastName,
              decoration: InputDecoration(labelText: S.lastName),
              onSaved: (value) => _profile.lastName = value ?? '',
            ),
            TextFormField(
              initialValue: _profile.age.toString(),
              decoration: InputDecoration(labelText: S.age),
              keyboardType: TextInputType.number,
              onSaved: (value) => _profile.age = int.tryParse(value ?? '20') ?? 20,
            ),
            TextFormField(
              initialValue: _profile.weight.toString(),
              decoration: InputDecoration(labelText: S.weight),
              keyboardType: TextInputType.number,
              onSaved: (value) => _profile.weight = int.tryParse(value ?? '70') ?? 70,
            ),
            TextFormField(
              initialValue: _profile.height.toString(),
              decoration: InputDecoration(labelText: S.height),
              keyboardType: TextInputType.number,
              onSaved: (value) => _profile.height = int.tryParse(value ?? '175') ?? 175,
            ),
            DropdownButtonFormField<String>(
              value: _profile.gender,
              items: [
                DropdownMenuItem<String>(value: 'male', child: Text(S.male)),
                DropdownMenuItem<String>(value: 'female', child: Text(S.female)),
              ],
              onChanged: (newValue) {
                setState(() => _profile.gender = newValue ?? 'male');
              },
              decoration: InputDecoration(labelText: S.gender),
            ),
            DropdownButtonFormField<UserGoal>(
              value: _profile.goal,
              items: UserGoal.values.map((UserGoal goal) {
                String text;
                switch (goal) {
                  case UserGoal.burnFat: text = S.goalBurnFat; break;
                  case UserGoal.buildMuscle: text = S.goalBuildMuscle; break;
                  case UserGoal.maintain: text = S.goalMaintain; break;
                }
                return DropdownMenuItem<UserGoal>(value: goal, child: Text(text));
              }).toList(),
              onChanged: (newValue) {
                setState(() => _profile.goal = newValue!);
              },
              decoration: InputDecoration(labelText: S.goal),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(S.appearance, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(S.theme),
                const Spacer(),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {themeProvider.themeMode},
                  onSelectionChanged: (set) => themeProvider.setThemeMode(set.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(S.accentColor),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in [
                  const Color(0xFF448AFF),
                  const Color(0xFF7C4DFF),
                  const Color(0xFFFF5252),
                  const Color(0xFFFF9800),
                  const Color(0xFF4CAF50),
                ])
                  GestureDetector(
                    onTap: () => themeProvider.setSeedColor(c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeProvider.seedColor == c ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(S.language),
                const Spacer(),
                DropdownButton<Locale>(
                  value: localeProvider.locale,
                  items: [
                    const Locale('en'),
                    const Locale('ru'),
                    const Locale('kk'),
                  ].map((loc) {
                    final text = {
                      'en':'English','ru':'Русский','kk':'Қазақша',
                    }[loc.languageCode]!;
                    return DropdownMenuItem(value: loc, child: Text(text));
                  }).toList(),
                  onChanged: (loc) { if (loc!=null) localeProvider.setLocale(loc); },
                )
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saveProfile, child: Text(S.saveProfile))
          ],
        ),
        ),
      ),
    );
  }
}