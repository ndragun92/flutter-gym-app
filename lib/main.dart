import 'dart:ui';

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

  Widget _buildDecorativeBackground(ThemeData theme) {
    final colors = theme.colorScheme;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.background,
                  colors.surface.withOpacity(0.92),
                  colors.background,
                ],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-1.1, -1.0),
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withOpacity(0.22),
                    colors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(1.15, -0.2),
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.tertiary.withOpacity(0.16),
                    colors.tertiary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.2, 1.05),
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.secondary.withOpacity(0.14),
                    colors.secondary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    final colors = theme.colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colors.outlineVariant.withOpacity(0.55),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                indicatorColor: colors.primary.withOpacity(0.24),
                labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
                  (states) => TextStyle(
                    fontSize: 12,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? colors.onSurface
                        : colors.onSurface.withOpacity(0.74),
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
                  (states) => IconThemeData(
                    size: states.contains(WidgetState.selected) ? 26 : 23,
                    color: states.contains(WidgetState.selected)
                        ? colors.primary
                        : colors.onSurface.withOpacity(0.78),
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (newIndex) =>
                    setState(() => index = newIndex),
                height: 70,
                elevation: 0,
                backgroundColor: colors.surface.withOpacity(0.72),
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppState>().isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _buildDecorativeBackground(theme),
          loading
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
        ],
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }
}
