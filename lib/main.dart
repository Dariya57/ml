import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <-- ВОТ ИСПРАВЛЕНИЕ (была точка вместо двоеточия)
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/workout_provider.dart';
import 'providers/app_blocker_provider.dart';
import 'services/app_blocker_service.dart';
import 'screens/home_screen.dart';
import 'screens/store_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/blocker_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => WorkoutProvider()),
        ChangeNotifierProvider(create: (context) => AppBlockerProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Color(0xFF1F1F1F),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1F1F1F),
            selectedItemColor: Colors.lightBlueAccent,
            unselectedItemColor: Colors.grey,
          ),
        ),
        routes: {
          '/': (context) => seenOnboarding ? const MainScreen() : const OnboardingScreen(),
          '/blocker-setup': (context) => const BlockerSetupScreen(),
        },
        initialRoute: '/',
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final AppBlockerService _appBlockerService = AppBlockerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppBlocker();
    });
  }

  void _initializeAppBlocker() {
    final appBlockerProvider = context.read<AppBlockerProvider>();
    _appBlockerService.startMonitoring(appBlockerProvider, context);
  }

  @override
  void dispose() {
    _appBlockerService.dispose();
    super.dispose();
  }

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    StoreScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: 'Магазин',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}