import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final authState = ref.watch(authNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);

    final cashierName = authState.currentUser?.fullname ?? 'Admin';
    final cashierRole = authState.currentUser?.role.toUpperCase() ?? 'ADMIN';

    final navItems = [
      _NavItem(icon: Icons.point_of_sale, label: 'POS Kasir', route: '/pos'),
      _NavItem(icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      _NavItem(icon: Icons.history, label: 'Riwayat Penjualan', route: '/history'),
      _NavItem(icon: Icons.settings, label: 'Pengaturan', route: '/settings'),
    ];

    if (isDesktop) {
      // Desktop Sidebar Layout
      return Scaffold(
        body: Row(
          children: [
            // Sidebar Navigation
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.08),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Shop branding header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.store,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.shopName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Multiplatform POS',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Navigation Links
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: navItems.length,
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        final isActive = currentRoute == item.route;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            selected: isActive,
                            selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                            iconColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            selectedColor: Theme.of(context).colorScheme.primary,
                            leading: Icon(item.icon),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: () => context.go(item.route),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Cashier info and toggles
                  Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.08)),
                  
                  // Theme Mode & Logged Cashier Profile
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              themeMode == ThemeMode.dark ? 'Dark Mode' : 'Light Mode',
                              style: const TextStyle(fontSize: 14),
                            ),
                            IconButton(
                              onPressed: () {
                                ref.read(themeModeProvider.notifier).state =
                                    themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                              },
                              icon: Icon(
                                themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Text(
                                cashierName[0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cashierName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    cashierRole,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                ref.read(authNotifierProvider.notifier).logout();
                              },
                              icon: const Icon(Icons.logout, size: 20),
                              tooltip: 'Keluar',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Pane
            Expanded(child: child),
          ],
        ),
      );
    } else {
      // Mobile Layout (AppBar + Bottom Nav)
      int activeIndex = navItems.indexWhere((i) => currentRoute == i.route);
      if (activeIndex < 0) activeIndex = 0;

      return Scaffold(
        appBar: AppBar(
          title: Text(settings.shopName),
          actions: [
            IconButton(
              onPressed: () {
                ref.read(themeModeProvider.notifier).state =
                    themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
              icon: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
            ),
            IconButton(
              onPressed: () {
                ref.read(authNotifierProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: activeIndex,
          onDestinationSelected: (idx) {
            context.go(navItems[idx].route);
          },
          destinations: navItems.map((item) {
            return NavigationDestination(
              icon: Icon(item.icon),
              label: item.label,
            );
          }).toList(),
        ),
      );
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
