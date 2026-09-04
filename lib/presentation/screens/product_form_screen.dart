import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/item_model.dart';
import '../providers/items_provider.dart';
import '../providers/unit_provider.dart';

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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _skuController = TextEditingController(text: item?.itemNo ?? '');
    _nameController = TextEditingController(text: item?.itemName ?? '');
    _nameShortController = TextEditingController(text: item?.itemNameShort ?? '');
    _upcController = TextEditingController(text: item?.itemUPC ?? '');
    _priceController = TextEditingController(text: item?.price.toString() ?? '0.0');
    _obQuantityController = TextEditingController(text: item?.obQuantity.toString() ?? '10.0');
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil ditambahkan!')));
          Navigator.pop(context);
        }
      } else {
        await ref.read(itemsNotifierProvider.notifier).updateItem(widget.existingItem!.itemNo, newItem);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil diperbarui!')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(itemsNotifierProvider).categories;
    final unitsState = ref.watch(unitsProvider);

    final List<String> unitNames = [];
    if (unitsState.hasValue) {
      unitNames.addAll(unitsState.value!.map((e) => e.name).toList());
    }
    // Ensure currently selected units are in the list if not found
    for (final u in [_unit1, _unit2, _unit3]) {
      if (u != null && u.isNotEmpty && !unitNames.contains(u)) {
        unitNames.add(u);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Tambah Produk' : 'Edit Produk'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildBasicInfoCard(categories),
                  const SizedBox(height: 16),
                  _buildPriceStockCard(),
                  const SizedBox(height: 16),
                  _buildUnitsCard(unitNames),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(widget.existingItem == null ? 'Simpan Produk Baru' : 'Simpan Perubahan'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildBasicInfoCard(List<dynamic> categories) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Dasar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(labelText: 'SKU / Kode Item'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _upcController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Barcode (UPC)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Produk *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Nama produk wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameShortController,
              decoration: const InputDecoration(labelText: 'Nama Pendek (Opsional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: categories.map((c) {
                return DropdownMenuItem<int>(
                  value: c.id,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _categoryId = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceStockCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Harga & Stok Dasar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Harga Jual Dasar (Rp)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _obQuantityController,
                    decoration: const InputDecoration(labelText: 'Stok Awal'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsCard(List<String> unitNames) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pengaturan Multi Satuan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            
            // Unit 1
            const Text('Satuan Dasar (Unit 1)', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: _unit1,
              decoration: const InputDecoration(labelText: 'Nama Satuan 1'),
              items: _buildUnitItems(unitNames),
              onChanged: (val) => setState(() => _unit1 = val),
            ),
            const SizedBox(height: 24),
            
            // Unit 2
            const Text('Satuan Menengah (Unit 2)', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit2,
                    decoration: const InputDecoration(labelText: 'Nama Satuan 2'),
                    items: _buildUnitItems(unitNames),
                    onChanged: (val) => setState(() => _unit2 = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _ratio2Controller,
                    decoration: const InputDecoration(labelText: 'Isi (Ratio)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _defUnitPrice2Controller,
              decoration: const InputDecoration(labelText: 'Harga Jual Satuan 2 (Rp)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Unit 3
            const Text('Satuan Besar (Unit 3)', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit3,
                    decoration: const InputDecoration(labelText: 'Nama Satuan 3'),
                    items: _buildUnitItems(unitNames),
                    onChanged: (val) => setState(() => _unit3 = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _ratio3Controller,
                    decoration: const InputDecoration(labelText: 'Isi (Ratio)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _defUnitPrice3Controller,
              decoration: const InputDecoration(labelText: 'Harga Jual Satuan 3 (Rp)'),
              keyboardType: TextInputType.number,
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
