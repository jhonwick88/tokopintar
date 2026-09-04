import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unit_provider.dart';
import '../widgets/main_layout.dart';

class UnitScreen extends ConsumerWidget {
  const UnitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsState = ref.watch(unitsProvider);

    return MainLayout(
      currentRoute: '/units',
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Master Satuan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showUnitDialog(context, ref),
          ),
        ],
      ),
      body: unitsState.when(
        data: (units) {
          if (units.isEmpty) {
            return const Center(child: Text('Belum ada data satuan.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: units.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final unit = units[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.straighten, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      unit.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit Satuan',
                            onPressed: () => _showUnitDialog(context, ref, id: unit.id, initialName: unit.name),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Hapus Satuan',
                            onPressed: () => _confirmDelete(context, ref, unit.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUnitDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    ));
  }

  void _showUnitDialog(BuildContext context, WidgetRef ref, {int? id, String? initialName}) {
    final controller = TextEditingController(text: initialName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(id == null ? 'Tambah Satuan' : 'Edit Satuan'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nama Satuan (misal: PCS, Pack)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                try {
                  if (id == null) {
                    await ref.read(unitsProvider.notifier).createUnit(name);
                  } else {
                    await ref.read(unitsProvider.notifier).updateUnit(id, name);
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Satuan?'),
        content: const Text('Apakah Anda yakin ingin menghapus satuan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(unitsProvider.notifier).deleteUnit(id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
