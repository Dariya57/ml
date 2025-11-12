import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <-- ВОТ ИСПРАВЛЕНИЕ (была точка вместо двоеточия)
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/workout_provider.dart';
import 'providers/app_blocker_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'utils/strings.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(builder: (context, theme, locale, _) {
        return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.lightTheme,
        darkTheme: theme.darkTheme,
        themeMode: theme.themeMode,
        locale: locale.locale,
        supportedLocales: locale.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routes: {
          '/': (context) => seenOnboarding ? const MainScreen() : const OnboardingScreen(),
          '/blocker-setup': (context) => const BlockerSetupScreen(),
        },
        initialRoute: '/',
        );
      }),
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
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: AppStrings.of(context).navHome,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: AppStrings.of(context).navStore,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: AppStrings.of(context).navSettings,
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}