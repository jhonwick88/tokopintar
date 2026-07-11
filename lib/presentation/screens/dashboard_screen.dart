import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/sales_history_provider.dart';
import '../widgets/main_layout.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final ScrollController _scrollController;
  int _leaderboardLimit = 10;
  int _totalTopItems = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
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

    final completedSales = salesState.sales.where((s) => s.status == 'completed').toList();

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
      if (sale.paymentMethod == 'cash') {
        cashTotal += sale.grandTotal;
      } else if (sale.paymentMethod == 'qris') {
        qrisTotal += sale.grandTotal;
      } else if (sale.paymentMethod == 'bank') {
        bankTotal += sale.grandTotal;
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
    final start = salesState.startDate ?? (completedSales.isEmpty ? now.subtract(const Duration(days: 30)) : completedSales.last.date);
    final end = salesState.endDate ?? now;
    final diffDays = end.difference(start).inDays;

    final Map<String, double> chartData = {};

    if (diffDays <= 1) {
      // Group by hours (e.g. 0-23 in steps of 2)
      for (int h = 0; h < 24; h += 2) {
        chartData['${h.toString().padLeft(2, '0')}:00'] = 0.0;
      }
      for (var sale in completedSales) {
        final hour = (sale.date.hour ~/ 2) * 2;
        final key = '${hour.toString().padLeft(2, '0')}:00';
        if (chartData.containsKey(key)) {
          chartData[key] = chartData[key]! + sale.grandTotal;
        }
      }
    } else if (diffDays <= 7) {
      // Group by date (DD/MM)
      for (int i = diffDays; i >= 0; i--) {
        final d = end.subtract(Duration(days: i));
        final key = DateFormat('dd/MM').format(d);
        chartData[key] = 0.0;
      }
      for (var sale in completedSales) {
        final key = DateFormat('dd/MM').format(sale.date);
        if (chartData.containsKey(key)) {
          chartData[key] = chartData[key]! + sale.grandTotal;
        }
      }
    } else if (diffDays <= 31) {
      // Group by date (DD/MM) with step of 2 or 1
      final step = diffDays > 15 ? 2 : 1;
      for (int i = diffDays; i >= 0; i -= step) {
        final d = end.subtract(Duration(days: i));
        final key = DateFormat('dd/MM').format(d);
        chartData[key] = 0.0;
      }
      for (var sale in completedSales) {
        final key = DateFormat('dd/MM').format(sale.date);
        String? closestKey;
        int minDiff = 999999;
        for (var k in chartData.keys) {
          final parts = k.split('/');
          final kDay = int.parse(parts[0]);
          final diff = (sale.date.day - kDay).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closestKey = k;
          }
        }
        if (closestKey != null) {
          chartData[closestKey] = chartData[closestKey]! + sale.grandTotal;
        }
      }
    } else {
      // Group by month
      for (int i = 5; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final key = DateFormat('MMM yy').format(d);
        chartData[key] = 0.0;
      }
      for (var sale in completedSales) {
        final key = DateFormat('MMM yy').format(sale.date);
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
    if (salesState.startDate != null && salesState.endDate != null) {
      dateRangeStr = '${DateFormat('dd MMM yyyy').format(salesState.startDate!)} - ${DateFormat('dd MMM yyyy').format(salesState.endDate!)}';
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
              icon: const Icon(Icons.refresh),
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
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '#${index + 1}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
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

  void _updateFilter(VoidCallback updateCallback) {
    setState(() {
      _leaderboardLimit = 10;
    });
    updateCallback();
  }

  Widget _buildFilterChips(BuildContext context, SalesHistoryState salesState) {
    final notifier = ref.read(salesHistoryNotifierProvider.notifier);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    String activeFilter = 'all';
    if (salesState.startDate != null && salesState.endDate != null) {
      final start = salesState.startDate!;
      final end = salesState.endDate!;
      final startZero = DateTime(start.year, start.month, start.day);
      final endZero = DateTime(end.year, end.month, end.day);
      final diffDays = endZero.difference(startZero).inDays;

      if (startZero.year == todayStart.year && startZero.month == todayStart.month && startZero.day == todayStart.day) {
        activeFilter = 'today';
      } else if (diffDays == 6 && endZero.year == todayStart.year && endZero.month == todayStart.month && endZero.day == todayStart.day) {
        activeFilter = '7days';
      } else if (diffDays == 29 && endZero.year == todayStart.year && endZero.month == todayStart.month && endZero.day == todayStart.day) {
        activeFilter = '30days';
      } else if (startZero.year == now.year && startZero.month == now.month && startZero.day == 1) {
        activeFilter = 'month';
      } else {
        activeFilter = 'custom';
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('Semua'),
            selected: activeFilter == 'all',
            onSelected: (selected) {
              if (selected) {
                _updateFilter(() => notifier.updateDateFilter(null, null));
              }
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Hari Ini'),
            selected: activeFilter == 'today',
            onSelected: (selected) {
              if (selected) {
                final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
                _updateFilter(() => notifier.updateDateFilter(todayStart, end));
              }
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('7 Hari Terakhir'),
            selected: activeFilter == '7days',
            onSelected: (selected) {
              if (selected) {
                final start = todayStart.subtract(const Duration(days: 6));
                final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
                _updateFilter(() => notifier.updateDateFilter(start, end));
              }
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('30 Hari Terakhir'),
            selected: activeFilter == '30days',
            onSelected: (selected) {
              if (selected) {
                final start = todayStart.subtract(const Duration(days: 29));
                final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
                _updateFilter(() => notifier.updateDateFilter(start, end));
              }
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Bulan Ini'),
            selected: activeFilter == 'month',
            onSelected: (selected) {
              if (selected) {
                final start = DateTime(now.year, now.month, 1);
                final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
                _updateFilter(() => notifier.updateDateFilter(start, end));
              }
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range, size: 14),
                const SizedBox(width: 4),
                Text(activeFilter == 'custom' 
                    ? '${DateFormat('dd/MM').format(salesState.startDate!)} - ${DateFormat('dd/MM').format(salesState.endDate!)}'
                    : 'Kustom'),
              ],
            ),
            selected: activeFilter == 'custom',
            onSelected: (selected) async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
                initialDateRange: salesState.startDate != null && salesState.endDate != null
                    ? DateTimeRange(start: salesState.startDate!, end: salesState.endDate!)
                    : null,
              );
              if (picked != null) {
                final end = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                _updateFilter(() => notifier.updateDateFilter(picked.start, end));
              }
            },
          ),
        ],
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
              context,
              'Pendapatan Kotor',
              _formatRupiah(totalRevenue),
              Icons.monetization_on_rounded,
              Colors.teal,
            ),
            _buildStatCard(
              context,
              'Jumlah Transaksi',
              '$totalTransactions Transaksi',
              Icons.shopping_basket_rounded,
              Colors.orange,
            ),
            _buildStatCard(
              context,
              'Rata-rata Belanja',
              _formatRupiah(averageBasket),
              Icons.trending_up_rounded,
              Colors.indigo,
            ),
            _buildStatCard(
              context,
              'Diskon Terpakai',
              _formatRupiah(totalDiscounts),
              Icons.percent_rounded,
              Colors.pink,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < entries.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      entries[idx].key,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
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
