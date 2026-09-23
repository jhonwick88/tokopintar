import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/item_model.dart';
import '../../data/models/category_model.dart';
import '../providers/items_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/unit_provider.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/app_permissions_dialog.dart';
import 'pos_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final ItemModel? existingItem;

  const ProductFormScreen({super.key, this.existingItem});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _skuController;
  late TextEditingController _nameController;
  late TextEditingController _nameShortController;
  late TextEditingController _upcController;
  late TextEditingController _priceController;
  late TextEditingController _obQuantityController;
  late TextEditingController _notesController;
  late TextEditingController _attributeController;

  int _categoryId = 0;

  String? _unit1;
  String? _unit2;
  String? _unit3;

  late TextEditingController _ratio2Controller;
  late TextEditingController _ratio3Controller;
  late TextEditingController _defUnitPrice2Controller;
  late TextEditingController _defUnitPrice3Controller;

  bool _isShortNameManuallyEdited = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _skuController = TextEditingController(text: item?.itemNo ?? '');
    _nameController = TextEditingController(text: item?.itemName ?? '');
    
    final initialShortName = item?.itemNameShort ?? '';
    _nameShortController = TextEditingController(text: initialShortName);
    
    _isShortNameManuallyEdited = initialShortName.isNotEmpty &&
        initialShortName != generateItemNameShort(item?.itemName ?? '');

    _nameController.addListener(() {
      if (!_isShortNameManuallyEdited) {
        final newShort = generateItemNameShort(_nameController.text);
        if (_nameShortController.text != newShort) {
          _nameShortController.text = newShort;
        }
      }
    });

    _upcController = TextEditingController(text: item?.itemUPC ?? '');
    _priceController = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(0) : '0',
    );
    _obQuantityController = TextEditingController(
      text: item != null ? item.obQuantity.toStringAsFixed(0) : '0',
    );
    _notesController = TextEditingController(text: item?.notes ?? '');
    _attributeController = TextEditingController(text: item?.attribute ?? '');

    _categoryId = item?.categoryId ?? 0;
    _unit1 = (item?.unit1.isNotEmpty == true) ? item!.unit1 : null;
    _unit2 = (item?.unit2.isNotEmpty == true) ? item!.unit2 : null;
    _unit3 = (item?.unit3.isNotEmpty == true) ? item!.unit3 : null;

    _ratio2Controller = TextEditingController(text: item?.ratio2.toString() ?? '0.0');
    _ratio3Controller = TextEditingController(text: item?.ratio3.toString() ?? '0.0');
    _defUnitPrice2Controller = TextEditingController(text: item?.defUnitPrice2.toString() ?? '0.0');
    _defUnitPrice3Controller = TextEditingController(text: item?.defUnitPrice3.toString() ?? '0.0');
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _nameShortController.dispose();
    _upcController.dispose();
    _priceController.dispose();
    _obQuantityController.dispose();
    _notesController.dispose();
    _attributeController.dispose();
    _ratio2Controller.dispose();
    _ratio3Controller.dispose();
    _defUnitPrice2Controller.dispose();
    _defUnitPrice3Controller.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    var status = await Permission.camera.status;
    if (status != PermissionStatus.granted) {
      if (mounted) {
        await AppPermissionsDialog.show(context);
      }
      status = await Permission.camera.status;
      if (status != PermissionStatus.granted) {
        return;
      }
    }

    if (!mounted) return;
    final scanned = await showDialog<String>(
      context: context,
      builder: (context) => const CameraScannerDialog(),
    );
    if (scanned != null && scanned.isNotEmpty) {
      setState(() {
        _upcController.text = scanned;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final price = double.tryParse(_priceController.text) ?? 0.0;
    final obQuantity = double.tryParse(_obQuantityController.text) ?? 0.0;
    final ratio2 = double.tryParse(_ratio2Controller.text) ?? 0.0;
    final ratio3 = double.tryParse(_ratio3Controller.text) ?? 0.0;
    final defUnitPrice2 = double.tryParse(_defUnitPrice2Controller.text) ?? 0.0;
    final defUnitPrice3 = double.tryParse(_defUnitPrice3Controller.text) ?? 0.0;

    final newItem = ItemModel(
      itemNo: _skuController.text.trim(),
      itemUPC: _upcController.text.trim(),
      itemName: _nameController.text.trim(),
      itemNameShort: _nameShortController.text.trim(),
      categoryId: _categoryId,
      price: price,
      obQuantity: obQuantity,
      notes: _notesController.text.trim(),
      attribute: _attributeController.text.trim(),
      unit1: _unit1 ?? '',
      unit2: _unit2 ?? '',
      unit3: _unit3 ?? '',
      ratio2: ratio2,
      ratio3: ratio3,
      defUnitPrice2: defUnitPrice2,
      defUnitPrice3: defUnitPrice3,
    );

    try {
      if (widget.existingItem == null) {
        await ref.read(itemsNotifierProvider.notifier).createItem(newItem);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil ditambahkan!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, newItem);
        }
      } else {
        await ref.read(itemsNotifierProvider.notifier).updateItem(widget.existingItem!.itemNo, newItem);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil diperbarui!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, newItem);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showQuickAddCategoryDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text('Tambah Kategori Cepat'),
                ],
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kategori',
                    hintText: 'Contoh: Minuman Dingin, Snack, dll',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama kategori wajib diisi' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          try {
                            final newCategory = CategoryModel(
                              id: 0,
                              name: nameController.text.trim(),
                            );
                            await ref.read(categoriesProvider.notifier).createCategory(newCategory);
                            await ref.read(itemsNotifierProvider.notifier).loadItems();

                            final updatedCategories = ref.read(categoriesProvider).categories;
                            final matched = updatedCategories.firstWhere(
                              (c) => c.name.toLowerCase() == nameController.text.trim().toLowerCase(),
                              orElse: () => updatedCategories.isNotEmpty ? updatedCategories.last : CategoryModel(id: 0, name: ''),
                            );
                            if (matched.id != 0) {
                              setState(() {
                                _categoryId = matched.id;
                              });
                            }

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kategori "${nameController.text.trim()}" berhasil ditambahkan!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Gagal menambah kategori: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(itemsNotifierProvider).categories;
    final unitsState = ref.watch(unitsProvider);

    final List<String> unitNames = [];
    if (unitsState.hasValue) {
      unitNames.addAll(unitsState.value!.map((e) => e.name).toList());
    }
    for (final u in [_unit1, _unit2, _unit3]) {
      if (u != null && u.isNotEmpty && !unitNames.contains(u)) {
        unitNames.add(u);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Tambah Produk' : 'Edit Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Simpan',
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBasicInfoCard(categories),
                        const SizedBox(height: 16),
                        _buildPriceStockCard(),
                        const SizedBox(height: 16),
                        _buildUnitsCard(unitNames),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            onPressed: _save,
                            label: Text(
                              widget.existingItem == null ? 'Simpan Produk Baru' : 'Simpan Perubahan',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBasicInfoCard(List<dynamic> categories) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('Informasi Dasar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 500) {
                  return Row(
                    children: [
                      Expanded(child: _buildSkuField()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildUpcField(isMobile)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildSkuField(),
                      const SizedBox(height: 14),
                      _buildUpcField(isMobile),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Produk *',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameShortController,
              onChanged: (_) {
                _isShortNameManuallyEdited = true;
              },
              decoration: const InputDecoration(
                labelText: 'Nama Singkat / Struk (Opsional)',
                prefixIcon: Icon(Icons.short_text),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Tanpa Kategori'),
                      ),
                      ...categories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _categoryId = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  tooltip: 'Tambah Kategori Cepat',
                  onPressed: _showQuickAddCategoryDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkuField() {
    return TextFormField(
      controller: _skuController,
      decoration: InputDecoration(
        labelText: 'SKU / Kode Item *',
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.blue),
              onPressed: () {
                final generated = generateSKUFromName(_nameController.text);
                if (generated.isNotEmpty) {
                  setState(() {
                    _skuController.text = generated;
                  });
                }
              },
              tooltip: 'Generate SKU Otomatis',
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.grey),
              onPressed: () => showSKUGuideDialog(context),
              tooltip: 'Panduan SKU',
            ),
          ],
        ),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU wajib diisi' : null,
    );
  }

  Widget _buildUpcField(bool isMobile) {
    return TextFormField(
      controller: _upcController,
      decoration: InputDecoration(
        labelText: 'Barcode (UPC)',
        prefixIcon: const Icon(Icons.qr_code),
        border: const OutlineInputBorder(),
        suffixIcon: isMobile
            ? IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
                tooltip: 'Scan Barcode Kamera',
              )
            : null,
      ),
    );
  }

  Widget _buildPriceStockCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monetization_on_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text('Harga & Stok Dasar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 500) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual Dasar (Rp) *',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Harga wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _obQuantityController,
                          decoration: const InputDecoration(
                            labelText: 'Stok Awal',
                            prefixIcon: Icon(Icons.warehouse_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual Dasar (Rp) *',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Harga wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _obQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Stok Awal',
                          prefixIcon: Icon(Icons.warehouse_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Produk',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsCard(List<String> unitNames) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.layers_outlined, color: Colors.orange),
                SizedBox(width: 8),
                Text('Pengaturan Multi Satuan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            
            // Unit 1
            const Text('Satuan Dasar (Unit 1)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _unit1,
              decoration: const InputDecoration(
                labelText: 'Nama Satuan 1 (e.g. PCS, BTL)',
                border: OutlineInputBorder(),
              ),
              items: _buildUnitItems(unitNames),
              onChanged: (val) => setState(() => _unit1 = val),
            ),
            const SizedBox(height: 24),
            
            // Unit 2
            const Text('Satuan Menengah (Unit 2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit2,
                    decoration: const InputDecoration(
                      labelText: 'Nama Satuan 2 (e.g. PACK)',
                      border: OutlineInputBorder(),
                    ),
                    items: _buildUnitItems(unitNames),
                    onChanged: (val) => setState(() => _unit2 = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _ratio2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Isi (Rasio)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _defUnitPrice2Controller,
              decoration: const InputDecoration(
                labelText: 'Harga Jual Satuan 2 (Rp)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),

            // Unit 3
            const Text('Satuan Besar (Unit 3)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit3,
                    decoration: const InputDecoration(
                      labelText: 'Nama Satuan 3 (e.g. DUS)',
                      border: OutlineInputBorder(),
                    ),
                    items: _buildUnitItems(unitNames),
                    onChanged: (val) => setState(() => _unit3 = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _ratio3Controller,
                    decoration: const InputDecoration(
                      labelText: 'Isi (Rasio)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _defUnitPrice3Controller,
              decoration: const InputDecoration(
                labelText: 'Harga Jual Satuan 3 (Rp)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildUnitItems(List<String> names) {
    return [
      const DropdownMenuItem<String>(value: null, child: Text('Tidak diatur')),
      ...names.map((n) => DropdownMenuItem<String>(value: n, child: Text(n))),
    ];
  }
}
