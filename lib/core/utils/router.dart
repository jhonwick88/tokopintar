import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/pos_screen.dart';
import '../../presentation/screens/sales_history_screen.dart';
import '../../presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/pos'; // Redirect to POS screen after successful login
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) => const PosScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const SalesHistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
