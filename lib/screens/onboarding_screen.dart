import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../models/data_models.dart';
import '../utils/strings.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final ImagePicker _picker = ImagePicker();
  XFile? _photo;
  final _formKey = GlobalKey<FormState>();
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    final wp = context.read<WorkoutProvider>();
    _profile = UserProfile(
      name: wp.userProfile.name,
      lastName: wp.userProfile.lastName,
      age: wp.userProfile.age,
      weight: wp.userProfile.weight,
      height: wp.userProfile.height,
      gender: wp.userProfile.gender,
      goal: wp.userProfile.goal,
      imagePath: wp.userProfile.imagePath,
    );
  }

  Future<void> _finish() async {
    await context.read<WorkoutProvider>().saveProfile(_profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final S = AppStrings.of(context);
    final locale = context.watch<LocaleProvider>();
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(S.welcomeTitle)),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const ClampingScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                // Step 1: Language
                _buildCard(
                  context,
                  title: S.chooseLanguage,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<Locale>(
                        value: locale.locale,
                        items: const [Locale('en'), Locale('ru'), Locale('kk')]
                            .map((l) => DropdownMenuItem(value: l, child: Text({'en':'English','ru':'Русский','kk':'Қазақша'}[l.languageCode]!)))
                            .toList(),
                        onChanged: (l) { if (l!=null) locale.setLocale(l); },
                      ),
                    ],
                  ),
                ),
                // Step 2: Theme/Color
                _buildCard(
                  context,
                  title: S.chooseTheme,
                  child: Column(
                    children: [
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('System')),
                          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                        ],
                        selected: {theme.themeMode},
                        onSelectionChanged: (set) => theme.setThemeMode(set.first),
                      ),
                      const SizedBox(height: 16),
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
                              onTap: () => theme.setSeedColor(c),
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.seedColor == c ? Colors.white : Colors.transparent, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Step 3: Photo
                _buildCard(
                  context,
                  title: S.addPhoto,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _photo != null
                            ? FileImage(File(_photo!.path))
                            : (_profile.imagePath != null ? FileImage(File(_profile.imagePath!)) : null) as ImageProvider<Object>?,
                        child: (_photo == null && _profile.imagePath == null) ? const Icon(Icons.person, size: 60) : null,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final p = await _picker.pickImage(source: ImageSource.gallery);
                          if (p != null) {
                            setState(() { _photo = p; _profile.imagePath = p.path; });
                          }
                        },
                        child: const Text('Choose'),
                      ),
                    ],
                  ),
                ),
                // Step 4: Name/Surname
                _buildCard(
                  context,
                  title: S.enterName,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: _profile.name,
                          decoration: InputDecoration(labelText: S.name),
                          onSaved: (v) => _profile.name = v?.trim().isNotEmpty == true ? v!.trim() : _profile.name,
                        ),
                        TextFormField(
                          initialValue: _profile.lastName,
                          decoration: InputDecoration(labelText: S.lastName),
                          onSaved: (v) => _profile.lastName = v?.trim() ?? '',
                        ),
                      ],
                    ),
                  ),
                ),
                // Step 5: Body params
                _buildCard(
                  context,
                  title: S.bodyParams,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: _profile.age.toString(),
                        decoration: InputDecoration(labelText: S.age),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _profile.age = int.tryParse(v) ?? _profile.age,
                      ),
                      TextFormField(
                        initialValue: _profile.height.toString(),
                        decoration: InputDecoration(labelText: S.height),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _profile.height = int.tryParse(v) ?? _profile.height,
                      ),
                      TextFormField(
                        initialValue: _profile.weight.toString(),
                        decoration: InputDecoration(labelText: S.weight),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _profile.weight = int.tryParse(v) ?? _profile.weight,
                      ),
                    ],
                  ),
                ),
                // Step 6: Gender
                _buildCard(
                  context,
                  title: S.selectGender,
                  child: DropdownButtonFormField<String>(
                    value: _normalizeGender(_profile.gender),
                    items: [
                      DropdownMenuItem<String>(value: 'male', child: Text(S.male)),
                      DropdownMenuItem<String>(value: 'female', child: Text(S.female)),
                    ],
                    onChanged: (v) => _profile.gender = v ?? 'male',
                  ),
                ),
                // Step 7: Goal
                _buildCard(
                  context,
                  title: S.selectGoal,
                  child: DropdownButtonFormField<UserGoal>(
                    value: _profile.goal,
                    items: [
                      DropdownMenuItem<UserGoal>(value: UserGoal.burnFat, child: Text(S.goalBurnFat)),
                      DropdownMenuItem<UserGoal>(value: UserGoal.buildMuscle, child: Text(S.goalBuildMuscle)),
                      DropdownMenuItem<UserGoal>(value: UserGoal.maintain, child: Text(S.goalMaintain)),
                    ],
                    onChanged: (v) => _profile.goal = v ?? UserGoal.maintain,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (_index > 0)
                  TextButton(
                    onPressed: () => _controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    if (_index == 3) { _formKey.currentState?.save(); }
                    if (_index < 6) {
                      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                    } else {
                      await _finish();
                    }
                  },
                  child: Text(_index < 6 ? S.next : S.finish),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _normalizeGender(String? value) {
    final v = (value ?? '').toLowerCase();
    if (v == 'male' || v == 'мужской' || v == 'ер') return 'male';
    if (v == 'female' || v == 'женский' || v == 'әйел') return 'female';
    return 'male';
  }

  Widget _buildCard(BuildContext context, {required String title, required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}