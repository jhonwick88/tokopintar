import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/item_model.dart';
import '../../data/models/quick_item_model.dart';
import '../providers/items_provider.dart';
import '../providers/quick_items_provider.dart';

// Predefined Icon Mappings
final Map<String, IconData> quickItemIconsMap = {
  'print': Icons.print,
  'photo': Icons.photo,
  'description': Icons.description,
  'book': Icons.auto_stories,
  'package': Icons.inventory_2,
  'shipping': Icons.local_shipping,
  'computer': Icons.computer,
  'receipt': Icons.receipt,
  'bag': Icons.shopping_bag,
  'card': Icons.card_membership,
};

// Predefined Color Grid presets
final List<Color> quickItemColorsList = [
  Colors.teal,
  Colors.indigo,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.deepOrange,
  Colors.purple,
  Colors.pink,
  Colors.grey,
];

class QuickAddItemSettingsScreen extends ConsumerStatefulWidget {
  const QuickAddItemSettingsScreen({super.key});

  @override
  ConsumerState<QuickAddItemSettingsScreen> createState() => _QuickAddItemSettingsScreenState();
}

class _MobileItemPickerDialog extends StatefulWidget {
  final List<ItemModel> allItems;

  const _MobileItemPickerDialog({required this.allItems});

  @override
  State<_MobileItemPickerDialog> createState() => _MobileItemPickerDialogState();
}

class _MobileItemPickerDialogState extends State<_MobileItemPickerDialog> {
  String _searchQuery = '';
  late List<ItemModel> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.allItems;
  }

  void _filter(String val) {
    setState(() {
      _searchQuery = val.trim().toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredItems = widget.allItems;
      } else {
        _filteredItems = widget.allItems
            .where((item) =>
                item.itemName.toLowerCase().contains(_searchQuery) ||
                item.itemNo.toLowerCase().contains(_searchQuery) ||
                item.itemUPC.toLowerCase().contains(_searchQuery))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Produk'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama atau barcode...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('Produk tidak ditemukan'))
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          title: Text(item.itemName),
                          subtitle: Text('Code: ${item.itemNo}'),
                          trailing: Text('Rp ${item.price.toStringAsFixed(0)}'),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

class _QuickAddItemSettingsScreenState extends ConsumerState<QuickAddItemSettingsScreen> {
  
  @override
  void initState() {
    super.initState();
    // Load fresh quick items
    Future.microtask(() {
      ref.read(quickItemsNotifierProvider.notifier).loadQuickItems();
    });
  }

  void _showQuickItemFormDialog([QuickItemModel? existingItem]) {
    final list = ref.read(quickItemsNotifierProvider);
    if (existingItem == null && list.length >= 12) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Batas Tercapai'),
          content: const Text('Maksimal tombol Quick Item dibatasi 12 item untuk performa optimal di perangkat mobile.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    ItemModel? selectedProduct;
    String name = existingItem?.itemName ?? '';
    String selectedIcon = existingItem?.iconName ?? 'print';
    Color selectedColor = existingItem?.colorHex != null 
        ? Color(int.parse(existingItem!.colorHex!)) 
        : Colors.teal;
    bool isActive = existingItem?.isActive ?? true;

    // Load available database items
    final itemsState = ref.read(itemsNotifierProvider);
    final allItems = itemsState.items;

    if (existingItem != null) {
      for (var item in allItems) {
        if (item.itemNo == existingItem.itemNo) {
          selectedProduct = item;
          break;
        }
      }
    }

    final nameController = TextEditingController(text: name);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(existingItem == null ? 'Tambah Quick Item' : 'Edit Quick Item'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Picker
                    const Text('Produk Database', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: Text(selectedProduct?.itemName ?? 'Belum memilih produk'),
                      subtitle: Text(selectedProduct != null ? 'Code: ${selectedProduct!.itemNo}' : 'Pilih produk dari database'),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final chosen = await showDialog<ItemModel>(
                          context: context,
                          builder: (context) => _MobileItemPickerDialog(allItems: allItems),
                        );
                        if (chosen != null) {
                          setDialogState(() {
                            selectedProduct = chosen;
                            if (nameController.text.isEmpty) {
                              // Auto-fill name, cut to 15 chars
                              final cutName = chosen.itemName.length > 15 
                                  ? chosen.itemName.substring(0, 15) 
                                  : chosen.itemName;
                              nameController.text = cutName;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Label / Short name
                    const Text('Nama Pendek (Maks 15 Karakter)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Fotokopi',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Icon Selector Grid
                    const Text('Pilih Icon Tombol', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickItemIconsMap.entries.map((entry) {
                        final isSelected = selectedIcon == entry.key;
                        return ChoiceChip(
                          avatar: Icon(entry.value, size: 16, color: isSelected ? Colors.white : null),
                          label: Text(entry.key),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => selectedIcon = entry.key);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Color Preset Grid
                    const Text('Pilih Warna Tombol', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickItemColorsList.map((color) {
                        final isSelected = selectedColor.value == color.value;
                        return InkWell(
                          onTap: () {
                            setDialogState(() => selectedColor = color);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Active Toggle
                    SwitchListTile(
                      title: const Text('Status Aktif', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Tampilkan di menu POS'),
                      value: isActive,
                      onChanged: (val) {
                        setDialogState(() => isActive = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedProduct == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Harap pilih produk terlebih dahulu')),
                      );
                      return;
                    }
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Harap isi nama pendek shortcut')),
                      );
                      return;
                    }

                    final newShortcut = QuickItemModel(
                      id: existingItem?.id ?? const Uuid().v4(),
                      itemNo: selectedProduct!.itemNo,
                      itemName: nameController.text.trim(),
                      iconName: selectedIcon,
                      colorHex: '0x${selectedColor.value.toRadixString(16)}',
                      displayOrder: existingItem?.displayOrder ?? list.length,
                      isActive: isActive,
                    );

                    if (existingItem == null) {
                      ref.read(quickItemsNotifierProvider.notifier).addQuickItem(newShortcut);
                    } else {
                      ref.read(quickItemsNotifierProvider.notifier).updateQuickItem(newShortcut);
                    }

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shortcut Quick Item berhasil disimpan'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('Simpan'),
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
    final quickItems = ref.watch(quickItemsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Quick Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickItemFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Shortcut'),
      ),
      body: quickItems.isEmpty
          ? const Center(
              child: Text(
                'Belum ada Quick Item shortcut. Tambahkan produk yang sering dijual di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: AlertBanner(),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: quickItems.length,
                    itemBuilder: (context, index) {
                      final item = quickItems[index];
                      final iconData = quickItemIconsMap[item.iconName] ?? Icons.bolt;
                      final cardColor = item.colorHex != null 
                          ? Color(int.parse(item.colorHex!)) 
                          : Colors.teal;

                      return Card(
                        key: ValueKey(item.id),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(iconData, color: cardColor),
                          ),
                          title: Text(
                            item.itemName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Code: ${item.itemNo} • Status: ${item.isActive ? 'Aktif' : 'Nonaktif'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showQuickItemFormDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  ref.read(quickItemsNotifierProvider.notifier).deleteQuickItem(item.id);
                                },
                              ),
                              const Icon(Icons.drag_handle),
                            ],
                          ),
                        ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      ref.read(quickItemsNotifierProvider.notifier).reorderQuickItems(oldIndex, newIndex);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, color: Colors.blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tekan dan geser baris item (icon paling kanan) untuk mengubah urutan tampil shortcut pada halaman kasir POS.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
