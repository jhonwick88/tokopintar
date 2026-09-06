import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/categories_provider.dart';
import '../widgets/main_layout.dart';
import '../../data/models/category_model.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    // Refresh categories when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoriesProvider.notifier).loadCategories();
    });
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Anda yakin ingin menghapus kategori "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kategori berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);

    final filteredCategories = categoriesState.categories.where((category) {
      return category.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return MainLayout(
      currentRoute: '/categories',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Kategori'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(categoriesProvider.notifier).loadCategories(),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Cari Kategori',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/categories/new');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Kategori'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: categoriesState.isLoading && categoriesState.categories.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : categoriesState.error != null && categoriesState.categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${categoriesState.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => ref.read(categoriesProvider.notifier).loadCategories(),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : filteredCategories.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isEmpty 
                                  ? 'Tidak ada data kategori.' 
                                  : 'Kategori tidak ditemukan.',
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredCategories.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final category = filteredCategories[index];
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isMobile = constraints.maxWidth < 600;

                                    if (isMobile) {
                                      return Column(
                                        children: [
                                          ListTile(
                                            leading: CircleAvatar(
                                              child: Text(category.name.isNotEmpty ? category.name[0].toUpperCase() : '?'),
                                            ),
                                            title: Text(category.name),
                                            subtitle: Text('ID: ${category.id}'),
                                          ),
                                          const Divider(height: 1),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                            child: Wrap(
                                              spacing: 8.0,
                                              alignment: WrapAlignment.end,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () => context.push('/categories/edit', extra: category),
                                                  icon: const Icon(Icons.edit, size: 16),
                                                  label: const Text('Edit'),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: () => _deleteCategory(category),
                                                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                                  label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 4, thickness: 4),
                                        ],
                                      );
                                    }

                                    return ListTile(
                                      leading: CircleAvatar(
                                        child: Text(category.name.isNotEmpty ? category.name[0].toUpperCase() : '?'),
                                      ),
                                      title: Text(category.name),
                                      subtitle: Text('ID: ${category.id}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () => context.push('/categories/edit', extra: category),
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteCategory(category),
                                            tooltip: 'Hapus',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
