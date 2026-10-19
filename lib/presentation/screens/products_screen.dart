import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/item_model.dart';
import '../providers/items_provider.dart';
import '../widgets/main_layout.dart';
import 'package:intl/intl.dart';
import 'product_form_screen.dart';
import 'stock_ledger_screen.dart';
import '../providers/license_provider.dart';
import '../providers/auth_provider.dart';
import '../../core/utils/excel_service.dart';
import '../../data/models/unit_model.dart';
import '../providers/unit_provider.dart';
import '../../core/utils/unit_helper.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itemsNotifierProvider.notifier).clearFiltersAndReload();
      ref.read(itemsNotifierProvider.notifier).loadBarcodeStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(ItemModel item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Produk'),
          content: Text('Apakah Anda yakin ingin menghapus produk "${item.itemName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(itemsNotifierProvider.notifier).deleteItem(item.itemNo);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produk berhasil dihapus'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menghapus produk: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showStockOpnameDialog(ItemModel item) {
    final stockController = TextEditingController(text: item.obQuantity.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Stok Opname'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Produk: ${item.itemName}'),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Jumlah Stok Baru',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newStock = double.tryParse(stockController.text);
                if (newStock != null) {
                  Navigator.of(context).pop();
                  try {
                    await ref.read(itemsNotifierProvider.notifier).updateStock(item.itemNo, newStock);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stok berhasil diperbarui'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal memperbarui stok: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importExcel() async {
    try {
      final itemsToImport = await ExcelService.importProductsFromExcel();
      if (itemsToImport.isEmpty) return; // cancelled or empty

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Mengimpor produk...'),
            ],
          ),
        ),
      );

      int successCount = 0;
      String? errorMessage;

      for (var item in itemsToImport) {
        try {
          await ref.read(itemsNotifierProvider.notifier).createItem(item);
          successCount++;
        } catch (e) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          break; // stop on error (e.g., duplicate or license limit)
        }
      }

      if (mounted) Navigator.pop(context); // close dialog

      if (errorMessage != null && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Import Terhenti'),
            content: Text('Berhasil mengimpor $successCount produk.\n\nBerhenti karena:\n$errorMessage'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
            ],
          ),
        );
      } else if (successCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil mengimpor $successCount produk'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Menyiapkan data produk ke Excel...')),
            ],
          ),
        ),
      );

      final items = await ref.read(itemsNotifierProvider.notifier).getAllItemsForExport();
      final categories = ref.read(itemsNotifierProvider).categories;
      final categoryMap = {for (var c in categories) c.id: c.name};
      final currentFilter = ref.read(itemsNotifierProvider).barcodeFilter;
      final filterLabel = currentFilter == 'has_barcode'
          ? 'Ada Barcode'
          : (currentFilter == 'no_barcode' ? 'Belum Ada Barcode' : 'Semua Produk');

      final success = await ExcelService.exportProductsToExcel(
        items: items,
        categoryNames: categoryMap,
        filterName: filterLabel,
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // close dialog

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil mengekspor ${items.length} produk ke Excel'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ekspor dibatalkan atau gagal disimpan'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQuickBarcodeDialog(ItemModel item) {
    final barcodeController = TextEditingController(text: item.itemUPC);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.blue),
              SizedBox(width: 8),
              Text('Input Barcode Cepat'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                'SKU: ${item.itemNo}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: barcodeController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Kode Barcode / UPC',
                  hintText: 'Scan atau ketik barcode...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                onSubmitted: (val) {
                  Navigator.of(ctx).pop();
                  _saveBarcode(item, val.trim());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _saveBarcode(item, barcodeController.text.trim());
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveBarcode(ItemModel item, String barcode) async {
    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode barcode tidak boleh kosong'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      await ref.read(itemsNotifierProvider.notifier).updateItemBarcode(item.itemNo, barcode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode produk "${item.itemName}" berhasil disimpan ($barcode)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan barcode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBarcodeFilterChips(ItemsState itemsState) {
    final currentFilter = itemsState.barcodeFilter;
    final totalCount = itemsState.totalCount > 0 ? itemsState.totalCount : itemsState.items.length;
    final withCount = itemsState.withBarcodeCount;
    final withoutCount = itemsState.withoutBarcodeCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Semua',
            count: totalCount,
            isSelected: currentFilter == 'all',
            color: Colors.blue,
            icon: Icons.all_inbox,
            onSelected: () => ref.read(itemsNotifierProvider.notifier).setBarcodeFilter('all'),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Ada Barcode',
            count: withCount,
            isSelected: currentFilter == 'has_barcode',
            color: Colors.green,
            icon: Icons.qr_code_2,
            onSelected: () => ref.read(itemsNotifierProvider.notifier).setBarcodeFilter('has_barcode'),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Belum Barcode',
            count: withoutCount,
            isSelected: currentFilter == 'no_barcode',
            color: Colors.orange,
            icon: Icons.qr_code_scanner,
            onSelected: () => ref.read(itemsNotifierProvider.notifier).setBarcodeFilter('no_barcode'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required MaterialColor color,
    required IconData icon,
    required VoidCallback onSelected,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color[700] : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color[900] : Colors.grey[800],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsNotifierProvider);
    final features = ref.watch(licenseProvider).features;
    final hasStockMovement = features['stock_movement'] == true;
    final hasStockOpname = features['stock_opname'] == true;
    final unitsState = ref.watch(unitsProvider);

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    
    final isAdmin = ref.watch(authNotifierProvider).currentUser?.role == 'admin';
    
    return MainLayout(
      currentRoute: '/products',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Produk', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export ke Excel',
              onPressed: _exportExcel,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(itemsNotifierProvider.notifier).loadItems(refresh: true);
                ref.read(itemsNotifierProvider.notifier).loadBarcodeStats();
              },
              tooltip: 'Refresh Data',
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'export_excel') {
                  _exportExcel();
                } else if (value == 'download_template') {
                  final success = await ExcelService.generateProductTemplate();
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Template berhasil diunduh'), backgroundColor: Colors.green),
                    );
                  }
                } else if (value == 'import_excel') {
                  _importExcel();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_excel',
                  child: Row(
                    children: [
                      Icon(Icons.table_view, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Export ke Excel'),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const PopupMenuItem(
                    value: 'download_template',
                    child: Text('Download Template Excel'),
                  ),
                  const PopupMenuItem(
                    value: 'import_excel',
                    child: Text('Import Produk dari Excel'),
                  ),
                ],
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Cari nama produk, SKU, atau Barcode...',
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(itemsNotifierProvider.notifier).search('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {});
                  ref.read(itemsNotifierProvider.notifier).search(val.trim());
                },
              ),
              const SizedBox(height: 12),
              _buildBarcodeFilterChips(itemsState),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(itemsNotifierProvider.notifier).loadItems(refresh: true);
                  },
                  child: itemsState.isLoading && itemsState.items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : itemsState.items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 100),
                                Center(child: Text('Tidak ada produk ditemukan')),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: itemsState.sortedItems.length + (itemsState.hasReachedMax ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (index >= itemsState.sortedItems.length) {
                                // Reached the end, load more
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  ref.read(itemsNotifierProvider.notifier).loadItems();
                                });
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }

                              final item = itemsState.sortedItems[index];
                              final isDesktop = MediaQuery.of(context).size.width > 600;

                              final actionButtons = <Widget>[
                                if (hasStockMovement)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => StockLedgerScreen(itemNo: item.itemNo, itemName: item.itemName),
                                      ));
                                    },
                                    icon: const Icon(Icons.list_alt, size: 16),
                                    label: const Text('Kartu Stok'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      backgroundColor: Colors.blue[50],
                                    ),
                                  ),
                                ElevatedButton.icon(
                                  onPressed: hasStockOpname ? () => _showStockOpnameDialog(item) : () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber),
                                            const SizedBox(width: 8),
                                            const Text('Fitur PRO'),
                                          ],
                                        ),
                                        content: const Text('Fitur Stok Opname hanya tersedia di versi PRO. Harap kontak penjual untuk upgrade lisensi Anda.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Tutup'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.inventory, size: 16),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Stok Opname'),
                                      if (!hasStockOpname) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('PRO', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ]
                                    ],
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ProductFormScreen(existingItem: item)
                                    ));
                                  },
                                  tooltip: 'Edit Produk',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _showDeleteDialog(item),
                                  tooltip: 'Hapus Produk',
                                ),
                                if (item.itemUPC.trim().isEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => _showQuickBarcodeDialog(item),
                                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                                    label: const Text('Input Barcode'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      backgroundColor: Colors.orange[50],
                                      foregroundColor: Colors.deepOrange[800],
                                    ),
                                  ),
                              ];

                                final unit1Name = item.unit1.isNotEmpty ? getUnitName(item.unit1, unitsState) : 'PCS';
                                final stockQtyStr = item.obQuantity % 1 == 0 ? item.obQuantity.toInt().toString() : item.obQuantity.toString();
                                final stockColor = item.obQuantity <= 0
                                    ? Colors.red
                                    : (item.obQuantity <= 5 ? Colors.orange[800] : Colors.grey[700]);

                                final subtitleContent = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'SKU: ${item.itemNo}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                        if (item.itemUPC.trim().isNotEmpty) ...[
                                          Text('•', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                          Text(
                                            'Barcode: ${item.itemUPC}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                        ] else ...[
                                          Text('•', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.orange.shade300, width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange[800]),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Belum Ada Barcode',
                                                  style: TextStyle(fontSize: 10.5, color: Colors.deepOrange[800], fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        Text('•', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                        Text(
                                          'Stok: $stockQtyStr $unit1Name',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: stockColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    _buildMultiUnitBadges(context, item, currencyFormatter, unitsState),
                                    const SizedBox(height: 2),
                                  ],
                                );

                                if (isDesktop) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                                      title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                                      subtitle: subtitleContent,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: actionButtons.map((btn) => Padding(padding: const EdgeInsets.only(left: 8.0), child: btn)).toList(),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                                          title: Text(
                                            item.itemName, 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                          ),
                                          subtitle: subtitleContent,
                                        ),
                                        const Divider(height: 1),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Wrap(
                                              alignment: WrapAlignment.end,
                                              spacing: 8.0,
                                              runSpacing: 8.0,
                                              children: actionButtons,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
            },
            tooltip: 'Tambah Produk Baru',
            child: const Icon(Icons.add),
          ),
        ),
      );
    }

  Widget _buildMultiUnitBadges(
    BuildContext context,
    ItemModel item,
    NumberFormat currencyFormatter,
    AsyncValue<List<UnitModel>> unitsState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unit1Name = item.unit1.isNotEmpty ? getUnitName(item.unit1, unitsState) : 'PCS';
    final hasUnit2 = item.unit2.isNotEmpty && item.ratio2 > 0 && item.defUnitPrice2 > 0;
    final hasUnit3 = item.unit3.isNotEmpty && item.ratio3 > 0 && item.defUnitPrice3 > 0;

    final unit2Name = hasUnit2 ? getUnitName(item.unit2, unitsState) : '';
    final unit3Name = hasUnit3 ? getUnitName(item.unit3, unitsState) : '';

    final ratio2Str = item.ratio2 % 1 == 0 ? item.ratio2.toInt().toString() : item.ratio2.toString();
    final ratio3Str = item.ratio3 % 1 == 0 ? item.ratio3.toInt().toString() : item.ratio3.toString();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // Unit 1 (Satuan Dasar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.withValues(alpha: 0.18) : Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.3),
            ),
          ),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey[200] : Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$unit1Name: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.blue[300] : Colors.blue[800],
                  ),
                ),
                TextSpan(
                  text: currencyFormatter.format(item.price),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[100] : Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Unit 2 (Satuan Menengah)
        if (hasUnit2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? Colors.purple.withValues(alpha: 0.18) : Colors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? Colors.purple.withValues(alpha: 0.4) : Colors.purple.withValues(alpha: 0.3),
              ),
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$unit2Name ($ratio2Str $unit1Name): ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.purple[300] : Colors.purple[800],
                    ),
                  ),
                  TextSpan(
                    text: currencyFormatter.format(item.defUnitPrice2),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.purple[100] : Colors.purple[900],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Unit 3 (Satuan Besar)
        if (hasUnit3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? Colors.teal.withValues(alpha: 0.18) : Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? Colors.teal.withValues(alpha: 0.4) : Colors.teal.withValues(alpha: 0.3),
              ),
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$unit3Name ($ratio3Str $unit1Name): ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.teal[300] : Colors.teal[800],
                    ),
                  ),
                  TextSpan(
                    text: currencyFormatter.format(item.defUnitPrice3),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.teal[100] : Colors.teal[900],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
