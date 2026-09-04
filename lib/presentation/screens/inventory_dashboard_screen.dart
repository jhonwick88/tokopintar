import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/license_provider.dart';
import '../widgets/main_layout.dart';

class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(licenseProvider).features;
    final hasStockOpname = features?['stock_opname'] == true;
    final hasSupplierManagement = features?['supplier_management'] == true;
    final hasSalesAnalytics = features?['sales_analytics'] == true;

    return MainLayout(
      currentRoute: '/inventory',
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Master Inventori'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adjust max width for grid items based on screen size
            final isDesktop = constraints.maxWidth > 600;
            
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
                  children: [
                    _buildInventoryCard(
                      context: context,
                      title: 'Manajemen Produk',
                      description: 'Tambah, edit, atau hapus data produk, barcode, dan harga',
                      icon: Icons.inventory_2,
                      color: Colors.blue,
                      route: '/products',
                      isDesktop: isDesktop,
                    ),
                    _buildInventoryCard(
                      context: context,
                      title: 'Master Satuan',
                      description: 'Kelola data satuan produk (pcs, box, lusin, dll)',
                      icon: Icons.straighten,
                      color: Colors.purple,
                      route: '/units',
                      isDesktop: isDesktop,
                    ),
                    if (hasStockOpname)
                      _buildInventoryCard(
                        context: context,
                        title: 'Stok Opname',
                        description: 'Perbarui jumlah stok fisik dengan mudah dan cepat',
                        icon: Icons.inventory_outlined,
                        color: Colors.orange,
                        route: '/stock-opname',
                        isDesktop: isDesktop,
                      ),
                    if (hasSupplierManagement)
                      _buildInventoryCard(
                        context: context,
                        title: 'Supplier',
                        description: 'Kelola data pemasok barang untuk toko Anda',
                        icon: Icons.local_shipping,
                        color: Colors.teal,
                        route: '/suppliers',
                        isDesktop: isDesktop,
                      ),
                    if (hasSalesAnalytics)
                      _buildInventoryCard(
                        context: context,
                        title: 'Analisis Kas',
                        description: 'Rekonsiliasi arus kas dan laporan shift kasir',
                        icon: Icons.analytics_outlined,
                        color: Colors.green,
                        route: '/reconciliation-analysis',
                        isDesktop: isDesktop,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ));
  }

  Widget _buildInventoryCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String route,
    required bool isDesktop,
  }) {
    final width = isDesktop ? 300.0 : MediaQuery.of(context).size.width - 32;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
