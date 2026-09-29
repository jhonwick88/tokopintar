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

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsNotifierProvider);
    final features = ref.watch(licenseProvider).features;
    final hasStockMovement = features?['stock_movement'] == true;
    final hasStockOpname = features?['stock_opname'] == true;

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
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(itemsNotifierProvider.notifier).loadItems(refresh: true);
              },
              tooltip: 'Refresh Data',
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'download_template') {
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
                    value: 'download_template',
                    child: Text('Download Template Excel'),
                  ),
                  const PopupMenuItem(
                    value: 'import_excel',
                    child: Text('Import Produk dari Excel'),
                  ),
                ],
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
              const SizedBox(height: 16),
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
                              ];

                              if (isDesktop) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  child: ListTile(
                                    title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'SKU: ${item.itemNo} | Barcode: ${item.itemUPC}\nStok: ${item.obQuantity} | Harga: ${currencyFormatter.format(item.price)}',
                                    ),
                                    isThreeLine: true,
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
                                        title: Text(
                                          item.itemName, 
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'SKU: ${item.itemNo} | Barcode: ${item.itemUPC}\nStok: ${item.obQuantity} | Harga: ${currencyFormatter.format(item.price)}',
                                        ),
                                        isThreeLine: true,
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
}
