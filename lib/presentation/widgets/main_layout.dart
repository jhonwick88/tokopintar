import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/mobile_cart_screen.dart';
import '../widgets/camera_scanner_dialog.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final query = ref.read(itemsNotifierProvider).searchQuery;
    _searchController = TextEditingController(text: query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCameraScanner(BuildContext context, WidgetRef ref) async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => const CameraScannerDialog(),
    );
    if (barcode != null) {
      ref.read(scannedBarcodeProvider.notifier).state = barcode;
    }
  }

  void _openResumeDialog(BuildContext context, WidgetRef ref) {
    final posState = ref.read(posNotifierProvider);
    if (posState.heldCarts.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada transaksi yang ditangguhkan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Daftar Transaksi Ditahan (Resume)'),
          content: SizedBox(
            width: 450,
            height: 300,
            child: ListView.builder(
              itemCount: posState.heldCarts.length,
              itemBuilder: (context, index) {
                final held = posState.heldCarts[index];
                return ListTile(
                  title: Text(held.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Items: ${held.cartItems.length}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          ref.read(posNotifierProvider.notifier).voidHeldTransaction(held.id);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaksi ditangguhkan dihapus'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(posNotifierProvider.notifier).resumeHeldTransaction(held.id);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Lanjutkan'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sync external query reset
    final searchVal = ref.watch(itemsNotifierProvider.select((s) => s.searchQuery));
    if (searchVal.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.text = '';
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final authState = ref.watch(authNotifierProvider);

    final navItems = [
      _NavItem(icon: Icons.point_of_sale, label: 'POS', route: '/pos'),
      _NavItem(icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      _NavItem(icon: Icons.history, label: 'Riwayat', route: '/history'),
      _NavItem(icon: Icons.settings, label: 'Pengaturan', route: '/settings'),
    ];

    int activeIndex = navItems.indexWhere((i) => widget.currentRoute == i.route);
    if (activeIndex < 0) activeIndex = 0;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar Navigation
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.12))),
              ),
              child: Column(
                children: [
                  // App Brand Logo
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.storefront_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'TokoPintar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Nav Options
                  Expanded(
                    child: ListView.builder(
                      itemCount: navItems.length,
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        final isSelected = activeIndex == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              item.icon,
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Theme.of(context).colorScheme.primary : null,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onTap: () {
                              context.go(item.route);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Cashier Info Footer
                  const Divider(height: 1),
                  if (authState.currentUser != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            child: Text(
                              authState.currentUser!.fullname[0].toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authState.currentUser!.fullname,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  authState.currentUser!.role.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, size: 18),
                            onPressed: () {
                              ref.read(authNotifierProvider.notifier).logout();
                              context.go('/login');
                            },
                            tooltip: 'Keluar Akun',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Content Pane
            Expanded(child: widget.child),
          ],
        ),
      );
    } else {
      // Mobile Layout (AppBar + Bottom Nav)
      final showOuterAppBar = widget.currentRoute == '/pos';

      return Scaffold(
        appBar: showOuterAppBar
            ? AppBar(
                title: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari produk... (F3)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchVal.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(itemsNotifierProvider.notifier).search('');
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          onPressed: () => _openCameraScanner(context, ref),
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(itemsNotifierProvider.notifier).search(val.trim());
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.hourglass_empty_rounded, color: Colors.orange),
                    onPressed: () => _openResumeDialog(context, ref),
                    tooltip: 'Lanjutkan Transaksi Ditahan',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final posState = ref.watch(posNotifierProvider);
                        final itemCount = posState.cartItems.fold<int>(0, (sum, item) => sum + item.qty);
                        return Badge(
                          label: Text('$itemCount'),
                          isLabelVisible: itemCount > 0,
                          child: IconButton(
                            icon: const Icon(Icons.shopping_cart),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const MobileCartScreen()),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : null,
        body: widget.child,
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
