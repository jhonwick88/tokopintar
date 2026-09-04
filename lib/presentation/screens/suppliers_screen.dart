import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supplier_provider.dart';
import '../../data/models/supplier_model.dart';
import '../widgets/main_layout.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(supplierNotifierProvider.notifier).loadSuppliers());
  }

  void _showSupplierForm([SupplierModel? supplier]) {
    showDialog(
      context: context,
      builder: (context) => _SupplierFormDialog(supplier: supplier),
    );
  }

  void _confirmDelete(SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Supplier?'),
        content: Text('Anda yakin ingin menghapus "${supplier.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (supplier.id != null) {
                final success = await ref.read(supplierNotifierProvider.notifier).deleteSupplier(supplier.id!);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supplier berhasil dihapus'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierNotifierProvider);

    return MainLayout(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Supplier'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(supplierNotifierProvider.notifier).loadSuppliers(),
            ),
          ],
        ),
        body: state.isLoading && state.suppliers.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.errorMessage != null && state.suppliers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.read(supplierNotifierProvider.notifier).loadSuppliers(),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : state.suppliers.isEmpty
                    ? const Center(child: Text('Belum ada data supplier'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = state.suppliers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.local_shipping),
                              ),
                              title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (supplier.contactInfo.isNotEmpty) Text('Kontak: ${supplier.contactInfo}'),
                                  if (supplier.address.isNotEmpty) Text('Alamat: ${supplier.address}'),
                                ],
                              ),
                              isThreeLine: supplier.contactInfo.isNotEmpty || supplier.address.isNotEmpty,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showSupplierForm(supplier),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDelete(supplier),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSupplierForm(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Supplier'),
        ),
      ),
    );
  }
}

class _SupplierFormDialog extends ConsumerStatefulWidget {
  final SupplierModel? supplier;
  const _SupplierFormDialog({this.supplier, Key? key}) : super(key: key);

  @override
  ConsumerState<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _contactController = TextEditingController(text: widget.supplier?.contactInfo ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');
    _notesController = TextEditingController(text: widget.supplier?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final newSupplier = SupplierModel(
      id: widget.supplier?.id,
      name: _nameController.text.trim(),
      contactInfo: _contactController.text.trim(),
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
    );

    bool success;
    if (widget.supplier == null) {
      success = await ref.read(supplierNotifierProvider.notifier).addSupplier(newSupplier);
    } else {
      success = await ref.read(supplierNotifierProvider.notifier).updateSupplier(newSupplier);
    }

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.supplier == null ? 'Supplier ditambahkan' : 'Supplier diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierNotifierProvider);
    final isEditing = widget.supplier != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Supplier' : 'Tambah Supplier Baru'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Supplier *', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(labelText: 'Info Kontak', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Alamat', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
