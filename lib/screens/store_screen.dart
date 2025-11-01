import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_blocker_provider.dart';
import '../providers/workout_provider.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ВЫЗЫВАЕМ ЗАГРУЗКУ ПРИЛОЖЕНИЙ ПРИ ПЕРВОМ ОТКРЫТИИ ЭКРАНА
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppBlockerProvider>().fetchAppsIfNeeded();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Настройка блокировки',
            onPressed: () {
              Navigator.pushNamed(context, '/blocker-setup');
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '💎 ${workoutProvider.currency}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Все приложения'),
            Tab(text: 'Заблокированные'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllAppsTab(),
          _buildBlockedAppsTab(),
        ],
      ),
    );
  }

  Widget _buildAllAppsTab() {
    // Используем Consumer для автоматического обновления UI
    return Consumer<AppBlockerProvider>(
      builder: (context, appBlockerProvider, child) {
        if (appBlockerProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (appBlockerProvider.installedApps.isEmpty) {
          return const Center(child: Text('Приложения не найдены'));
        }

        return ListView.builder(
          itemCount: appBlockerProvider.installedApps.length,
          itemBuilder: (context, index) {
            final app = appBlockerProvider.installedApps[index];
            if (app.packageName == 'com.example.fitai') return const SizedBox.shrink();
            
            final isBlocked = appBlockerProvider.isAppBlocked(app.packageName!);

            return ListTile(
              leading: app.icon != null ? Image.memory(app.icon!, width: 40, height: 40) : const Icon(Icons.apps),
              title: Text(app.name!),
              subtitle: Text(app.packageName!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: Switch(
                value: isBlocked,
                onChanged: (value) {
                  appBlockerProvider.toggleAppBlock(app.packageName!, app.name!);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlockedAppsTab() {
    return Consumer<AppBlockerProvider>(
      builder: (context, appBlockerProvider, child) {
        final workoutProvider = context.watch<WorkoutProvider>();

        if (appBlockerProvider.blockedApps.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Здесь будут отображаться заблокированные приложения.\n\nПерейдите на вкладку "Все приложения", чтобы выбрать приложения для блокировки.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: appBlockerProvider.blockedApps.length,
          itemBuilder: (context, index) {
            final blockedApp = appBlockerProvider.blockedApps[index];
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
              child: ExpansionTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: Text(blockedApp.appName),
                subtitle: Text('Разблокировано: ${blockedApp.unlockedMinutes} мин'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Купить минуты разблокировки:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPurchaseButton(workoutProvider, appBlockerProvider, blockedApp.packageName, 15, 10),
                            _buildPurchaseButton(workoutProvider, appBlockerProvider, blockedApp.packageName, 30, 15),
                            _buildPurchaseButton(workoutProvider, appBlockerProvider, blockedApp.packageName, 60, 25),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPurchaseButton(
    WorkoutProvider workoutProvider,
    AppBlockerProvider appBlockerProvider,
    String packageName,
    int minutes,
    int cost,
  ) {
    final canAfford = workoutProvider.currency >= cost;
    return ElevatedButton(
      onPressed: canAfford ? () {
        workoutProvider.spendCurrency(cost);
        appBlockerProvider.addMinutesToApp(packageName, minutes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Куплено $minutes мин за $cost 💎')),
        );
      } : null,
      child: Text('$minutes мин\n$cost 💎', textAlign: TextAlign.center),
    );
  }
}