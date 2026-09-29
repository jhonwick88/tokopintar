import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/items_provider.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/app_permissions_dialog.dart';
import '../widgets/main_layout.dart';

class StockOpnameScreen extends ConsumerStatefulWidget {
  const StockOpnameScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StockOpnameScreen> createState() => _StockOpnameScreenState();
}

class _StockOpnameScreenState extends ConsumerState<StockOpnameScreen> {
  final _searchController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};

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
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String itemNo, double currentStock) {
    if (!_controllers.containsKey(itemNo)) {
      _controllers[itemNo] = TextEditingController(text: currentStock.toString());
    }
    return _controllers[itemNo]!;
  }

  void _saveStock(String itemNo, String itemName, String textValue) async {
    final newStock = double.tryParse(textValue);
    if (newStock != null) {
      final notesController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Simpan Stok Opname'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Masukkan penyesuaian stok untuk $itemName menjadi $newStock.'),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Catatan Penyesuaian (Opsional)',
                  border: OutlineInputBorder(),
                  hintText: 'Misal: Salah hitung, rusak, dll',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(itemsNotifierProvider.notifier).updateStock(itemNo, newStock, notes: notesController.text.trim());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stok $itemName berhasil diperbarui'), backgroundColor: Colors.green),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsNotifierProvider);

    return MainLayout(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stok Opname'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(itemsNotifierProvider.notifier).loadItems(refresh: true);
              },
              tooltip: 'Refresh Data',
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
                labelText: 'Cari Produk (SKU / Nama / Barcode)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(itemsNotifierProvider.notifier).search('');
                          setState(() {});
                        },
                      ),
                    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                      IconButton(
                        icon: const Icon(Icons.camera_alt_rounded),
                        onPressed: () async {
                          var status = await Permission.camera.status;
                          if (status != PermissionStatus.granted) {
                            if (context.mounted) {
                              await AppPermissionsDialog.show(context);
                            }
                            status = await Permission.camera.status;
                            if (status != PermissionStatus.granted) return;
                          }
                          
                          if (!context.mounted) return;
                          final barcode = await showDialog<String>(
                            context: context,
                            builder: (context) => const CameraScannerDialog(),
                          );
                          if (barcode != null) {
                            _searchController.text = barcode;
                            ref.read(itemsNotifierProvider.notifier).search(barcode);
                            setState(() {});
                          }
                        },
                        tooltip: 'Scan Barcode',
                      ),
                  ],
                ),
              ),
              onChanged: (val) {
                setState(() {});
                ref.read(itemsNotifierProvider.notifier).search(val.trim());
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: itemsState.isLoading && itemsState.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : itemsState.items.isEmpty
                      ? const Center(child: Text('Tidak ada produk ditemukan'))
                      : ListView.builder(
                          itemCount: itemsState.sortedItems.length + (itemsState.hasReachedMax ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (index >= itemsState.sortedItems.length) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(itemsNotifierProvider.notifier).loadItems();
                              });
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final item = itemsState.sortedItems[index];
                            final controller = _getController(item.itemNo, item.obQuantity);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('SKU: ${item.itemNo} | Barcode: ${item.itemUPC}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: controller,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Stok Baru',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _saveStock(item.itemNo, item.itemName, controller.text),
                                      child: const Text('Simpan'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
