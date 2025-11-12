import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_blocker_provider.dart';
import '../providers/workout_provider.dart';
import '../utils/strings.dart';

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

    final S = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.navStore),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: S.blockingSetup,
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
          tabs: [Tab(text: S.allApps), Tab(text: S.blockedApps)],
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
          return Center(child: Text(AppStrings.of(context).appsNotFound));
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(AppStrings.of(context).emptyBlockedTitle, textAlign: TextAlign.center),
            ),
          );
        }

        return ListView.builder(
          itemCount: appBlockerProvider.blockedApps.length,
          itemBuilder: (context, index) {
            final blockedApp = appBlockerProvider.blockedApps[index];
            final remainingSeconds = blockedApp.getRemainingSeconds();
            final minutes = remainingSeconds ~/ 60;
            final seconds = remainingSeconds % 60;
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
              child: ExpansionTile(
                leading: Icon(
                  remainingSeconds > 0 ? Icons.lock_open : Icons.block,
                  color: remainingSeconds > 0 ? Colors.green : Colors.redAccent,
                ),
                title: Text(blockedApp.appName),
                subtitle: remainingSeconds > 0
                    ? Text(
                        '${AppStrings.of(context).unlocked}: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Text(AppStrings.of(context).blocked),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (remainingSeconds > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(
                                  '${AppStrings.of(context).timeLeft}: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(AppStrings.of(context).buyUnlockMinutes, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).buyMinutes(minutes, cost))));
      } : null,
      child: Text(AppStrings.of(context).minutesPriceLabel(minutes, cost), textAlign: TextAlign.center),
    );
  }
}