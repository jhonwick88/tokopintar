import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/sales_history_provider.dart';
import '../widgets/main_layout.dart';
import '../widgets/app_permissions_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final ScrollController _scrollController;
  int _leaderboardLimit = 10;
  int _totalTopItems = 0;
  String _selectedPreset = 'today'; // 'all', 'today', 'yesterday', 'last7days', 'last30days', 'thismonth', 'custom'
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptPermissions();
      _applyDatePreset('today');
    });
  }

  void _applyDatePreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      _leaderboardLimit = 10;
    });

    final now = DateTime.now();
    DateTime? start;
    DateTime? end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (preset) {
      case 'all':
        start = null;
        end = null;
        break;
      case 'today':
        start = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0, 0);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);
        break;
      case 'last7days':
        final d7 = now.subtract(const Duration(days: 6));
        start = DateTime(d7.year, d7.month, d7.day, 0, 0, 0, 0);
        break;
      case 'last30days':
        final d30 = now.subtract(const Duration(days: 29));
        start = DateTime(d30.year, d30.month, d30.day, 0, 0, 0, 0);
        break;
      case 'thismonth':
        start = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
        break;
      case 'custom':
        if (_customDateRange != null) {
          start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0, 0);
          end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
        } else {
          start = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
        }
        break;
      default:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
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

  Future<void> _checkAndPromptPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    final camera = await Permission.camera.isGranted;
    final location = await Permission.locationWhenInUse.isGranted;
    final mic = await Permission.microphone.isGranted;
    final btConnect = await Permission.bluetoothConnect.isGranted;
    final btScan = await Permission.bluetoothScan.isGranted;

    if (!camera || !location || !mic || !btConnect || !btScan) {
      if (mounted) {
        await AppPermissionsDialog.show(context);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_leaderboardLimit < _totalTopItems) {
        setState(() {
          _leaderboardLimit += 10;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesHistoryNotifierProvider);
    final now = DateTime.now();

    final completedSales = salesState.sales.where((s) {
      final statusLower = s.status.toLowerCase().trim();
      if (statusLower == 'voided' || statusLower == 'refunded' || statusLower == 'cancelled') {
        return false;
      }
      final saleDate = s.date.toLocal();
      if (salesState.startDate != null && saleDate.isBefore(salesState.startDate!)) return false;
      if (salesState.endDate != null && saleDate.isAfter(salesState.endDate!)) return false;
      return true;
    }).toList();

    // 1. Calculate stats based on currently loaded sales (which respect active date filters)
    double totalRevenue = 0.0;
    int totalTransactions = completedSales.length;
    double totalDiscounts = 0.0;
    double cashTotal = 0.0;
    double qrisTotal = 0.0;
    double bankTotal = 0.0;

    // Leaderboard map
    final Map<String, _TopItem> itemLeaderboard = {};

    for (var sale in completedSales) {
      totalRevenue += sale.grandTotal;
      totalDiscounts += sale.discount;
      
      // Payment grouping
      final pm = sale.paymentMethod.toLowerCase().trim();
      if (sale.payments.isNotEmpty) {
        for (var p in sale.payments) {
          final subPm = p.paymentMethod.toLowerCase().trim();
          if (subPm == 'cash' || subPm == 'tunai') {
            cashTotal += p.amount;
          } else if (subPm == 'qris') {
            qrisTotal += p.amount;
          } else if (subPm.contains('bank') || subPm.contains('transfer') || subPm.contains('card') || subPm.contains('edc') || subPm.contains('debit') || subPm.contains('credit')) {
            bankTotal += p.amount;
          } else {
            cashTotal += p.amount;
          }
        }
      } else {
        if (pm == 'cash' || pm == 'tunai') {
          cashTotal += sale.grandTotal;
        } else if (pm == 'qris') {
          qrisTotal += sale.grandTotal;
        } else if (pm.contains('bank') || pm.contains('transfer') || pm.contains('card') || pm.contains('edc') || pm.contains('debit') || pm.contains('credit')) {
          bankTotal += sale.grandTotal;
        } else {
          cashTotal += sale.grandTotal;
        }
      }

      // Group items for leaderboard
      for (var item in sale.items) {
        totalDiscounts += item.discount;
        if (itemLeaderboard.containsKey(item.itemNo)) {
          final existing = itemLeaderboard[item.itemNo]!;
          itemLeaderboard[item.itemNo] = _TopItem(
            name: item.itemName,
            qty: existing.qty + item.qty,
            revenue: existing.revenue + item.subtotal,
          );
        } else {
          itemLeaderboard[item.itemNo] = _TopItem(
            name: item.itemName,
            qty: item.qty,
            revenue: item.subtotal,
          );
        }
      }
    }

    final double averageBasket = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

    // Sort leaderboard by quantity sold
    final topItems = itemLeaderboard.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    _totalTopItems = topItems.length;

    // 2. Generate dynamic line chart spots based on active range
    final start = salesState.startDate ?? (completedSales.isEmpty ? now.subtract(const Duration(days: 30)) : completedSales.last.date.toLocal());
    final end = salesState.endDate ?? now;
    final diffDays = end.difference(start).inDays;

    final Map<String, double> chartData = {};

    if (_selectedPreset == 'today' || _selectedPreset == 'yesterday' || diffDays <= 1) {
      // Group by hours (e.g. 0-23 in steps of 2)
      for (int h = 0; h < 24; h += 2) {
        chartData['${h.toString().padLeft(2, '0')}:00'] = 0.0;
      }
      for (var sale in completedSales) {
        final localDate = sale.date.toLocal();
        final hour = (localDate.hour ~/ 2) * 2;
        final key = '${hour.toString().padLeft(2, '0')}:00';
        if (chartData.containsKey(key)) {
          chartData[key] = chartData[key]! + sale.grandTotal;
        }
      }
    } else if (diffDays <= 31 && _selectedPreset != 'all') {
      // Group by exact date (dd/MM) for each day in range
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      DateTime current = startDay;
      while (!current.isAfter(endDay)) {
        final key = DateFormat('dd/MM').format(current);
        chartData[key] = 0.0;
        current = current.add(const Duration(days: 1));
      }
      for (var sale in completedSales) {
        final key = DateFormat('dd/MM').format(sale.date.toLocal());
        if (chartData.containsKey(key)) {
          chartData[key] = chartData[key]! + sale.grandTotal;
        }
      }
    } else {
      // Group by month
      DateTime startMonth;
      DateTime endMonth;
      if (completedSales.isNotEmpty) {
        final firstDate = completedSales.map((s) => s.date.toLocal()).reduce((a, b) => a.isBefore(b) ? a : b);
        final lastDate = completedSales.map((s) => s.date.toLocal()).reduce((a, b) => a.isAfter(b) ? a : b);
        startMonth = DateTime(firstDate.year, firstDate.month, 1);
        endMonth = DateTime(lastDate.year, lastDate.month, 1);
      } else {
        startMonth = DateTime(now.year, now.month - 5, 1);
        endMonth = DateTime(now.year, now.month, 1);
      }

      // Ensure at least 3 months for good chart visuals
      int monthSpan = (endMonth.year - startMonth.year) * 12 + (endMonth.month - startMonth.month) + 1;
      if (monthSpan < 3) {
        startMonth = DateTime(endMonth.year, endMonth.month - 2, 1);
      }

      DateTime curM = startMonth;
      while (!curM.isAfter(endMonth)) {
        final key = DateFormat('MMM yy', 'id_ID').format(curM);
        chartData[key] = 0.0;
        curM = DateTime(curM.year, curM.month + 1, 1);
      }

      for (var sale in completedSales) {
        final key = DateFormat('MMM yy', 'id_ID').format(sale.date.toLocal());
        if (chartData.containsKey(key)) {
          chartData[key] = chartData[key]! + sale.grandTotal;
        }
      }
    }

    final chartEntries = chartData.entries.toList();
    final List<FlSpot> spots = [];
    for (int i = 0; i < chartEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), chartEntries[i].value));
    }

    final double maxVal = chartData.values.fold(100000.0, (prev, val) => val > prev ? val : prev);

    String dateRangeStr = 'Semua Waktu';
    if (_selectedPreset == 'today') {
      dateRangeStr = 'Hari Ini (${DateFormat('dd MMM yyyy', 'id_ID').format(now)})';
    } else if (_selectedPreset == 'yesterday') {
      final y = now.subtract(const Duration(days: 1));
      dateRangeStr = 'Kemarin (${DateFormat('dd MMM yyyy', 'id_ID').format(y)})';
    } else if (_selectedPreset == 'last7days') {
      dateRangeStr = '7 Hari Terakhir';
    } else if (_selectedPreset == 'last30days') {
      dateRangeStr = '30 Hari Terakhir';
    } else if (_selectedPreset == 'thismonth') {
      dateRangeStr = 'Bulan Ini (${DateFormat('MMMM yyyy', 'id_ID').format(now)})';
    } else if (salesState.startDate != null && salesState.endDate != null) {
      dateRangeStr = '${DateFormat('dd MMM yyyy', 'id_ID').format(salesState.startDate!)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(salesState.endDate!)}';
    }

    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 900;

    return MainLayout(
      currentRoute: '/dashboard',
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard Analitik', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                dateRangeStr,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.date_range_rounded),
              onPressed: _pickCustomDateRange,
              tooltip: 'Pilih Rentang Tanggal',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.read(salesHistoryNotifierProvider.notifier).fetchSales();
              },
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        body: salesState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await ref.read(salesHistoryNotifierProvider.notifier).fetchSales();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date range selectors (Chips)
                            _buildFilterChips(context, salesState),
                            const SizedBox(height: 16),

                            // Stats Row
                            _buildStatsGrid(totalRevenue, totalTransactions, averageBasket, totalDiscounts),
                            const SizedBox(height: 24),

                            // Charts & Payment Distribution
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 1000) {
                                  return Column(
                                    children: [
                                      _buildChartCard(context, spots, chartEntries, maxVal, dateRangeStr),
                                      const SizedBox(height: 24),
                                      _buildPaymentDistributionCard(context, cashTotal, qrisTotal, bankTotal),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildChartCard(context, spots, chartEntries, maxVal, dateRangeStr),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: _buildPaymentDistributionCard(context, cashTotal, qrisTotal, bankTotal),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),

                      // Sticky Pinned Header Card top
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyHeaderDelegate(
                          child: Container(
                            color: Theme.of(context).colorScheme.surface,
                            padding: const EdgeInsets.only(top: 8),
                            child: Card(
                              margin: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Produk Terlaris',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    if (topItems.isNotEmpty)
                                      Text(
                                        'Menampilkan ${_leaderboardLimit < topItems.length ? _leaderboardLimit : topItems.length} dari ${topItems.length} Produk',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // List Content wrapped as cards
                      if (topItems.isEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: Card(
                              margin: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Center(child: Text('Belum ada transaksi')),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = topItems[index];
                              final isLast = index == _leaderboardLimit - 1 || index == topItems.length - 1;
                              final double maxRevenue = topItems.isNotEmpty ? topItems.first.revenue : 1.0;

                              return Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
                                      bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
                                    ),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                gradient: index == 0
                                                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                                                    : index == 1
                                                        ? const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)])
                                                        : index == 2
                                                            ? const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFF8B4513)])
                                                            : null,
                                                color: index > 2
                                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                                                    : null,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '#${index + 1}',
                                                style: TextStyle(
                                                  color: index <= 2
                                                      ? Colors.white
                                                      : Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(2),
                                                    child: LinearProgressIndicator(
                                                      value: maxRevenue > 0 ? item.revenue / maxRevenue : 0.0,
                                                      backgroundColor: Colors.grey.shade100,
                                                      color: Theme.of(context).colorScheme.primary,
                                                      minHeight: 4,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Terjual ${item.qty} item',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _formatRupiah(item.revenue),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        if (!isLast) const Divider(height: 20, indent: 44),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: _leaderboardLimit < topItems.length ? _leaderboardLimit : topItems.length,
                          ),
                        ),
                        if (_leaderboardLimit < topItems.length)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _leaderboardLimit += 10;
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Muat Lebih Banyak'),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, SalesHistoryState salesState) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildSegmentItem(
              context: context,
              label: 'Semua',
              isSelected: _selectedPreset == 'all',
              onTap: () => _applyDatePreset('all'),
            ),
            _buildSegmentItem(
              context: context,
              label: 'Hari Ini',
              isSelected: _selectedPreset == 'today',
              onTap: () => _applyDatePreset('today'),
            ),
            _buildSegmentItem(
              context: context,
              label: 'Kemarin',
              isSelected: _selectedPreset == 'yesterday',
              onTap: () => _applyDatePreset('yesterday'),
            ),
            _buildSegmentItem(
              context: context,
              label: '7 Hari',
              isSelected: _selectedPreset == 'last7days',
              onTap: () => _applyDatePreset('last7days'),
            ),
            _buildSegmentItem(
              context: context,
              label: '30 Hari',
              isSelected: _selectedPreset == 'last30days',
              onTap: () => _applyDatePreset('last30days'),
            ),
            _buildSegmentItem(
              context: context,
              label: 'Bulan Ini',
              isSelected: _selectedPreset == 'thismonth',
              onTap: () => _applyDatePreset('thismonth'),
            ),
            GestureDetector(
              onTap: _pickCustomDateRange,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedPreset == 'custom' ? Theme.of(context).colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedPreset == 'custom'
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      size: 14,
                      color: _selectedPreset == 'custom'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedPreset == 'custom' && salesState.startDate != null && salesState.endDate != null
                          ? '${DateFormat('dd/MM').format(salesState.startDate!)} - ${DateFormat('dd/MM').format(salesState.endDate!)}'
                          : 'Kustom',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedPreset == 'custom' ? FontWeight.bold : FontWeight.w500,
                        color: _selectedPreset == 'custom'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentItem({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(double totalRevenue, int totalTransactions, double averageBasket, double totalDiscounts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 600
            ? 1
            : constraints.maxWidth < 900
                ? 2
                : 4;
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth < 600 ? 3.0 : 1.8,
          children: [
            _buildStatCard(
              context: context,
              title: 'Pendapatan Kotor',
              value: _formatRupiah(totalRevenue),
              icon: Icons.monetization_on_rounded,
              gradientColors: [const Color(0xFF0F9B0F), const Color(0xFF4CAF50)],
            ),
            _buildStatCard(
              context: context,
              title: 'Jumlah Transaksi',
              value: '$totalTransactions Transaksi',
              icon: Icons.shopping_basket_rounded,
              gradientColors: [const Color(0xFFE65100), const Color(0xFFF57C00)],
            ),
            _buildStatCard(
              context: context,
              title: 'Rata-rata Belanja',
              value: _formatRupiah(averageBasket),
              icon: Icons.trending_up_rounded,
              gradientColors: [const Color(0xFF1E3C72), const Color(0xFF2A5298)],
            ),
            _buildStatCard(
              context: context,
              title: 'Diskon Terpakai',
              value: _formatRupiah(totalDiscounts),
              icon: Icons.percent_rounded,
              gradientColors: [const Color(0xFFD81B60), const Color(0xFFEC407A)],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withOpacity(0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    child: Icon(icon, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, List<FlSpot> spots, List<MapEntry<String, double>> entries, double maxVal, String titleRange) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tren Penjualan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    titleRange,
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: spots.isEmpty
                  ? const Center(child: Text('Tidak ada data penjualan'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade100,
                              strokeWidth: 1.5,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= entries.length) {
                                  return const SizedBox();
                                }
                                int interval = 1;
                                if (entries.length > 20) {
                                  interval = 4;
                                } else if (entries.length > 10) {
                                  interval = 2;
                                }
                                if (idx % interval != 0 && idx != entries.length - 1) {
                                  return const SizedBox();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    entries[idx].key,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 3.5,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                            ),
                          ),
                        ],
                        minX: 0,
                        maxX: spots.length - 1.toDouble(),
                        minY: 0,
                        maxY: maxVal * 1.15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDistributionCard(BuildContext context, double cash, double qris, double bank) {
    final total = cash + qris + bank;
    final hasData = total > 0;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metode Pembayaran Terpilih',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 130,
                    child: !hasData
                        ? const Center(child: Text('Tidak ada data metode pembayaran'))
                        : PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 36,
                              sections: [
                                if (cash > 0)
                                  PieChartSectionData(
                                    color: Colors.teal,
                                    value: cash,
                                    title: '${(cash / total * 100).toStringAsFixed(0)}%',
                                    radius: 16,
                                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                if (qris > 0)
                                  PieChartSectionData(
                                    color: Colors.purple,
                                    value: qris,
                                    title: '${(qris / total * 100).toStringAsFixed(0)}%',
                                    radius: 16,
                                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                if (bank > 0)
                                  PieChartSectionData(
                                    color: Colors.blue,
                                    value: bank,
                                    title: '${(bank / total * 100).toStringAsFixed(0)}%',
                                    radius: 16,
                                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Tunai', Colors.teal, cash, total),
                      const SizedBox(height: 8),
                      _buildLegendItem('QRIS', Colors.purple, qris, total),
                      const SizedBox(height: 8),
                      _buildLegendItem('Card/EDC', Colors.blue, bank, total),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double amount, double total) {
    final percent = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0.0';
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text('$percent% (${_formatRupiah(amount)})', style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  String _formatRupiah(double val) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(val);
  }
}

class _TopItem {
  final String name;
  final int qty;
  final double revenue;

  _TopItem({
    required this.name,
    required this.qty,
    required this.revenue,
  });
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 76.0;

  @override
  double get maxExtent => 76.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: maxExtent,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
