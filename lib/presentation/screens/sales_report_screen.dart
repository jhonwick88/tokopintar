import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';

import '../../data/models/category_model.dart';
import '../providers/sales_history_provider.dart';
import '../providers/categories_provider.dart';
import '../widgets/main_layout.dart';
import '../../utils/web_download.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedCategoryId; // null = Semua Kategori
  String _selectedDateRangePreset = 'today'; // 'today', 'yesterday', 'last7days', 'thismonth', 'custom'
  DateTimeRange? _customDateRange;
  String _sortBy = 'omset_desc'; // 'omset_desc', 'omset_asc', 'qty_desc', 'qty_asc', 'name_asc'

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDatePreset('today');
      ref.read(categoriesProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyDatePreset(String preset) {
    setState(() {
      _selectedDateRangePreset = preset;
    });

    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 'last7days':
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        break;
      case 'thismonth':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'custom':
        if (_customDateRange != null) {
          start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        } else {
          start = DateTime(now.year, now.month, now.day);
        }
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    ref.read(salesHistoryNotifierProvider.notifier).updateDateFilter(start, end);
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
      });
      _applyDatePreset('custom');
    }
  }

  Future<void> _exportToExcel({
    required List<_ProductSalesSummary> productList,
    required List<_CategorySalesSummary> categoryList,
    required double totalOmset,
    required int totalQty,
  }) async {
    try {
      final excel = excel_pkg.Excel.createExcel();
      
      // Sheet 1: Per Kategori
      final catSheet = excel['Laporan Kategori'];
      catSheet.cell(excel_pkg.CellIndex.indexByString('A1')).value = excel_pkg.TextCellValue('Kategori');
      catSheet.cell(excel_pkg.CellIndex.indexByString('B1')).value = excel_pkg.TextCellValue('Total Qty Terjual');
      catSheet.cell(excel_pkg.CellIndex.indexByString('C1')).value = excel_pkg.TextCellValue('Total Omset (Rp)');
      catSheet.cell(excel_pkg.CellIndex.indexByString('D1')).value = excel_pkg.TextCellValue('Kontribusi (%)');

      for (int i = 0; i < categoryList.length; i++) {
        final cat = categoryList[i];
        final row = i + 2;
        catSheet.cell(excel_pkg.CellIndex.indexByString('A$row')).value = excel_pkg.TextCellValue(cat.categoryName);
        catSheet.cell(excel_pkg.CellIndex.indexByString('B$row')).value = excel_pkg.IntCellValue(cat.totalQty);
        catSheet.cell(excel_pkg.CellIndex.indexByString('C$row')).value = excel_pkg.DoubleCellValue(cat.totalOmset);
        catSheet.cell(excel_pkg.CellIndex.indexByString('D$row')).value = excel_pkg.TextCellValue('${cat.percentage.toStringAsFixed(1)}%');
      }

      // Sheet 2: Per Produk
      final prodSheet = excel['Laporan Produk'];
      prodSheet.cell(excel_pkg.CellIndex.indexByString('A1')).value = excel_pkg.TextCellValue('Kode / Barcode');
      prodSheet.cell(excel_pkg.CellIndex.indexByString('B1')).value = excel_pkg.TextCellValue('Nama Produk');
      prodSheet.cell(excel_pkg.CellIndex.indexByString('C1')).value = excel_pkg.TextCellValue('Kategori');
      prodSheet.cell(excel_pkg.CellIndex.indexByString('D1')).value = excel_pkg.TextCellValue('Qty Terjual');
      prodSheet.cell(excel_pkg.CellIndex.indexByString('E1')).value = excel_pkg.TextCellValue('Rata-rata Harga');
      prodSheet.cell(excel_pkg.CellIndex.indexByString('F1')).value = excel_pkg.TextCellValue('Total Omset (Rp)');

      for (int i = 0; i < productList.length; i++) {
        final prod = productList[i];
        final row = i + 2;
        prodSheet.cell(excel_pkg.CellIndex.indexByString('A$row')).value = excel_pkg.TextCellValue(prod.barcode.isNotEmpty ? prod.barcode : prod.itemNo);
        prodSheet.cell(excel_pkg.CellIndex.indexByString('B$row')).value = excel_pkg.TextCellValue(prod.itemName);
        prodSheet.cell(excel_pkg.CellIndex.indexByString('C$row')).value = excel_pkg.TextCellValue(prod.categoryName);
        prodSheet.cell(excel_pkg.CellIndex.indexByString('D$row')).value = excel_pkg.IntCellValue(prod.totalQty);
        prodSheet.cell(excel_pkg.CellIndex.indexByString('E$row')).value = excel_pkg.DoubleCellValue(prod.avgPrice);
        prodSheet.cell(excel_pkg.CellIndex.indexByString('F$row')).value = excel_pkg.DoubleCellValue(prod.totalOmset);
      }

      // Remove default Sheet1 if exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final filename = 'laporan_penjualan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
        if (kIsWeb) {
          downloadFileWeb(fileBytes, filename);
        } else {
          final FileSaveLocation? result = await getSaveLocation(suggestedName: filename);
          if (result != null) {
            final file = File(result.path);
            await file.writeAsBytes(fileBytes);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Laporan Excel berhasil disimpan'), backgroundColor: Colors.green),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor laporan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesHistoryNotifierProvider);
    final categories = ref.watch(categoriesProvider).categories;

    // Create category lookup map: categoryId -> CategoryModel
    final Map<int, CategoryModel> categoryLookup = {};
    for (var cat in categories) {
      categoryLookup[cat.id] = cat;
    }

    // Only count completed sales (exclude voided)
    final completedSales = salesState.sales.where((s) => s.status == 'completed').toList();

    // 1. Calculate Product Sales & map to Category
    final Map<String, _ProductSalesSummary> productSalesMap = {};
    final Map<int, _CategorySalesSummary> categorySalesMap = {};

    // Initialize all categories in map
    categorySalesMap[0] = _CategorySalesSummary(
      categoryId: 0,
      categoryName: 'Tanpa Kategori',
      totalQty: 0,
      totalOmset: 0.0,
    );
    for (var cat in categories) {
      categorySalesMap[cat.id] = _CategorySalesSummary(
        categoryId: cat.id,
        categoryName: cat.name,
        totalQty: 0,
        totalOmset: 0.0,
      );
    }

    double grandTotalOmset = 0.0;
    int grandTotalQty = 0;

    for (var sale in completedSales) {
      for (var item in sale.items) {
        // Read category directly from sale item
        int catId = item.categoryId;
        String catName = item.categoryName.isNotEmpty ? item.categoryName : 'Tanpa Kategori';
        String barcode = item.itemUPC;

        if (catId > 0 && categoryLookup.containsKey(catId)) {
          catName = categoryLookup[catId]!.name;
        }

        final itemOmset = item.subtotal;
        final itemQty = item.qty;

        grandTotalOmset += itemOmset;
        grandTotalQty += itemQty;

        // Aggregate by Category
        if (!categorySalesMap.containsKey(catId)) {
          categorySalesMap[catId] = _CategorySalesSummary(
            categoryId: catId,
            categoryName: catName,
            totalQty: 0,
            totalOmset: 0.0,
          );
        }
        final catSummary = categorySalesMap[catId]!;
        catSummary.totalQty += itemQty;
        catSummary.totalOmset += itemOmset;

        // Aggregate by Product
        final prodKey = item.itemNo.isNotEmpty ? item.itemNo : item.itemName;
        if (!productSalesMap.containsKey(prodKey)) {
          productSalesMap[prodKey] = _ProductSalesSummary(
            itemNo: item.itemNo,
            barcode: barcode,
            itemName: item.itemName,
            categoryId: catId,
            categoryName: catName,
            totalQty: 0,
            totalOmset: 0.0,
          );
        }
        final prodSummary = productSalesMap[prodKey]!;
        prodSummary.totalQty += itemQty;
        prodSummary.totalOmset += itemOmset;
      }
    }

    // Calculate Category Percentages and filter only active categories
    final List<_CategorySalesSummary> categoryList = categorySalesMap.values
        .where((c) => c.totalQty > 0 || c.totalOmset > 0)
        .toList();

    for (var cat in categoryList) {
      cat.percentage = grandTotalOmset > 0 ? (cat.totalOmset / grandTotalOmset) * 100 : 0.0;
    }
    categoryList.sort((a, b) => b.totalOmset.compareTo(a.totalOmset));

    // Filter Product List according to Selected Category & Search Query
    var productList = productSalesMap.values.where((p) {
      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = p.itemName.toLowerCase().contains(query);
        final matchNo = p.itemNo.toLowerCase().contains(query);
        final matchBarcode = p.barcode.toLowerCase().contains(query);
        final matchCat = p.categoryName.toLowerCase().contains(query);
        if (!matchName && !matchNo && !matchBarcode && !matchCat) return false;
      }
      return true;
    }).toList();

    // Sort Product List
    switch (_sortBy) {
      case 'omset_desc':
        productList.sort((a, b) => b.totalOmset.compareTo(a.totalOmset));
        break;
      case 'omset_asc':
        productList.sort((a, b) => a.totalOmset.compareTo(b.totalOmset));
        break;
      case 'qty_desc':
        productList.sort((a, b) => b.totalQty.compareTo(a.totalQty));
        break;
      case 'qty_asc':
        productList.sort((a, b) => a.totalQty.compareTo(b.totalQty));
        break;
      case 'name_asc':
        productList.sort((a, b) => a.itemName.compareTo(b.itemName));
        break;
    }

    // Filtered Totals for KPI (if filtered by category or search)
    final filteredOmset = productList.fold<double>(0.0, (sum, p) => sum + p.totalOmset);
    final filteredQty = productList.fold<int>(0, (sum, p) => sum + p.totalQty);

    return MainLayout(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/inventory'),
            tooltip: 'Kembali ke Inventori',
          ),
          title: const Text('Laporan Penjualan Produk'),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Ekspor ke Excel',
              onPressed: () => _exportToExcel(
                productList: productList,
                categoryList: categoryList,
                totalOmset: grandTotalOmset,
                totalQty: grandTotalQty,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang Data',
              onPressed: () => ref.read(salesHistoryNotifierProvider.notifier).fetchSales(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(salesHistoryNotifierProvider.notifier).fetchSales();
            await ref.read(categoriesProvider.notifier).loadCategories();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Section
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Preset Chips
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18),
                              const SizedBox(width: 8),
                              const Text('Periode: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildDateChip('Hari Ini', 'today'),
                                      _buildDateChip('Kemarin', 'yesterday'),
                                      _buildDateChip('7 Hari Terakhir', 'last7days'),
                                      _buildDateChip('Bulan Ini', 'thismonth'),
                                      ActionChip(
                                        avatar: const Icon(Icons.date_range, size: 16),
                                        label: Text(
                                          _selectedDateRangePreset == 'custom' && _customDateRange != null
                                              ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_customDateRange!.end)}'
                                              : 'Pilih Rentang...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _selectedDateRangePreset == 'custom' ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        backgroundColor: _selectedDateRangePreset == 'custom'
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : null,
                                        onPressed: _pickCustomDateRange,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // Search & Category Dropdown Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Search input
                              SizedBox(
                                width: 320,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Cari produk, barcode, atau kategori...',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    isDense: true,
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                ),
                              ),
                              // Category Filter Dropdown
                              SizedBox(
                                width: 230,
                                child: DropdownButtonFormField<int?>(
                                  value: (_selectedCategoryId == null || categories.any((cat) => cat.id == _selectedCategoryId))
                                      ? _selectedCategoryId
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Filter Kategori',
                                    prefixIcon: const Icon(Icons.category_outlined, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Semua Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    ...categories.map((cat) {
                                      return DropdownMenuItem<int?>(
                                        value: cat.id,
                                        child: Text(cat.name, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedCategoryId = val;
                                    });
                                  },
                                ),
                              ),
                              // Sort by Dropdown
                              SizedBox(
                                width: 230,
                                child: DropdownButtonFormField<String>(
                                  value: _sortBy,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Urutkan',
                                    prefixIcon: const Icon(Icons.sort, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'omset_desc', child: Text('Omset Tertinggi', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'omset_asc', child: Text('Omset Terendah', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'qty_desc', child: Text('Qty Terbanyak', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'qty_asc', child: Text('Qty Tersedikit', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'name_asc', child: Text('Nama Produk (A-Z)', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _sortBy = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Top KPI Summary Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 700;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildKpiCard(
                            context: context,
                            title: 'Total Omset Penjualan',
                            value: _currencyFormatter.format(_selectedCategoryId == null && _searchQuery.isEmpty ? grandTotalOmset : filteredOmset),
                            icon: Icons.payments_outlined,
                            color: Colors.green,
                            isDesktop: isDesktop,
                            subtitle: _selectedCategoryId != null ? 'Omset Kategori Terpilih' : 'Semua Penjualan Selesai',
                          ),
                          _buildKpiCard(
                            context: context,
                            title: 'Total Qty Terjual',
                            value: '${_selectedCategoryId == null && _searchQuery.isEmpty ? grandTotalQty : filteredQty} Unit',
                            icon: Icons.inventory_2_outlined,
                            color: Colors.blue,
                            isDesktop: isDesktop,
                            subtitle: 'Akumulasi Produk Keluar',
                          ),
                          _buildKpiCard(
                            context: context,
                            title: 'Total Transaksi Selesai',
                            value: '${completedSales.length} Struk',
                            icon: Icons.receipt_long_outlined,
                            color: Colors.purple,
                            isDesktop: isDesktop,
                            subtitle: 'Transaksi Berhasil',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // SECTION: Total Omset Penjualan Per Kategori
                  Row(
                    children: [
                      Icon(Icons.pie_chart_outline, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Total Omset Penjualan per Kategori',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (categoryList.isEmpty)
                    Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text('Belum ada transaksi penjualan pada periode ini.', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: categoryList.map((cat) {
                            final isSelected = _selectedCategoryId == cat.categoryId;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (_selectedCategoryId == cat.categoryId) {
                                    _selectedCategoryId = null; // Toggle off
                                  } else {
                                    _selectedCategoryId = cat.categoryId;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Colors.blueAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                cat.categoryName,
                                                style: TextStyle(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(${cat.totalQty} item terjual)',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _currencyFormatter.format(cat.totalOmset),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 50,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            '${cat.percentage.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (cat.percentage / 100).clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isSelected ? Theme.of(context).colorScheme.primary : Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),

                  // SECTION: Rincian Produk Terjual
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_alt_rounded, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Rincian Produk Terjual',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        'Total ${productList.length} Produk',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (salesState.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (productList.isEmpty)
                    Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty || _selectedCategoryId != null
                                    ? 'Tidak ada produk yang cocok dengan filter yang dipilih'
                                    : 'Belum ada produk yang terjual di periode ini',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: productList.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final prod = productList[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    prod.itemName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Text(
                                  _currencyFormatter.format(prod.totalOmset),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      prod.categoryName,
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (prod.barcode.isNotEmpty) ...[
                                    Text(
                                      'Barcode: ${prod.barcode}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  const Spacer(),
                                  Text(
                                    '${prod.totalQty} Terjual (Rata2: ${_currencyFormatter.format(prod.avgPrice)})',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, String presetKey) {
    final isSelected = _selectedDateRangePreset == presetKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) _applyDatePreset(presetKey);
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDesktop,
    required String subtitle,
  }) {
    final width = isDesktop ? 350.0 : MediaQuery.of(context).size.width - 40;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySalesSummary {
  final int categoryId;
  final String categoryName;
  int totalQty;
  double totalOmset;
  double percentage;

  _CategorySalesSummary({
    required this.categoryId,
    required this.categoryName,
    required this.totalQty,
    required this.totalOmset,
    this.percentage = 0.0,
  });
}

class _ProductSalesSummary {
  final String itemNo;
  final String barcode;
  final String itemName;
  final int categoryId;
  final String categoryName;
  int totalQty;
  double totalOmset;

  _ProductSalesSummary({
    required this.itemNo,
    required this.barcode,
    required this.itemName,
    required this.categoryId,
    required this.categoryName,
    required this.totalQty,
    required this.totalOmset,
  });

  double get avgPrice => totalQty > 0 ? totalOmset / totalQty : 0.0;
}
