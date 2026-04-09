import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'screens/dashboard_page.dart';
import 'screens/measurements_page.dart';
import 'screens/nutrition_page.dart';
import 'screens/workout_page.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Birdle Fit Tracker',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const _RootShell(),
      ),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppState>().isLoading;

    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: IndexedStack(
                index: index,
                children: [
                  const DashboardPage(),
                  NutritionPage(isActive: index == 1),
                  const MeasurementsPage(),
                  const WorkoutPage(),
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (newIndex) => setState(() => index = newIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            selectedIcon: Icon(Icons.restaurant_rounded),
            label: 'Meals',
          ),
          NavigationDestination(
            icon: Icon(Icons.straighten_rounded),
            selectedIcon: Icon(Icons.monitor_weight_rounded),
            label: 'Body',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded),
            label: 'Gym',
          ),
        ],
      ),
    );
  }
}
