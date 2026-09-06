import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/license_provider.dart';
import '../../presentation/screens/activation_screen.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/pos_screen.dart';
import '../../presentation/screens/sales_history_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/reconciliation_analysis_screen.dart';
import '../../presentation/screens/products_screen.dart';
import '../../presentation/screens/categories_screen.dart';
import '../../presentation/screens/category_form_screen.dart';
import '../../presentation/screens/unit_screen.dart';
import '../../presentation/screens/stock_opname_screen.dart';
import '../../presentation/screens/inventory_dashboard_screen.dart';
import '../../presentation/screens/suppliers_screen.dart';
import '../../presentation/screens/developer_contact_screen.dart';
import '../../data/models/category_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final licenseState = ref.watch(licenseProvider);

  return GoRouter(
    initialLocation: '/activation',
    redirect: (context, state) {
      if (!licenseState.hasInitialized) {
        return null;
      }

      final isActivated = licenseState.isActivated;
      final isActivating = state.matchedLocation == '/activation';

      if (!isActivated && !isActivating) {
        return '/activation';
      }

      if (isActivated && isActivating) {
        return '/login';
      }

      final isLoggedIn = authState.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (isActivated) {
        if (!isLoggedIn && !isLoggingIn && !isActivating) {
          return '/login';
        }
        if (isLoggedIn && isLoggingIn) {
          return '/pos'; 
        }
      }

      final adminRoutes = ['/reconciliation-analysis', '/inventory', '/products', '/categories', '/categories/new', '/categories/edit', '/units', '/stock-opname', '/suppliers'];
      if (adminRoutes.contains(state.matchedLocation) && authState.currentUser?.role != 'admin') {
        return '/pos';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryDashboardScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/categories/new',
        builder: (context, state) => const CategoryFormScreen(),
      ),
      GoRoute(
        path: '/categories/edit',
        builder: (context, state) {
          final category = state.extra as CategoryModel?;
          return CategoryFormScreen(category: category);
        },
      ),
      GoRoute(
        path: '/stock-opname',
        builder: (context, state) => const StockOpnameScreen(),
      ),
      GoRoute(
        path: '/units',
        builder: (context, state) => const UnitScreen(),
      ),
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
      ),
      GoRoute(
        path: '/activation',
        builder: (context, state) => const ActivationScreen(),
      ),
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
        path: '/products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/reconciliation-analysis',
        builder: (context, state) => const ReconciliationAnalysisScreen(),
      ),
      GoRoute(
        path: '/developer-contact',
        builder: (context, state) => const DeveloperContactScreen(),
      ),
    ],
  );
});
