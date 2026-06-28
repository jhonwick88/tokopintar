import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/sales_history_provider.dart';
import '../widgets/main_layout.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesHistoryNotifierProvider);

    // Calculate Dashboard Stats
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    double todayRevenue = 0.0;
    int todayTxCount = 0;
    double monthRevenue = 0.0;

    // Map to group sold items for popular items leaderboard
    final Map<String, _TopItem> itemLeaderboard = {};

    // Map to group daily sales for chart
    final Map<int, double> dailySalesChartData = {};
    // Pre-populate last 7 days with 0.0
    for (int i = 6; i >= 0; i--) {
      final dayKey = now.subtract(Duration(days: i)).day;
      dailySalesChartData[dayKey] = 0.0;
    }

    final completedSales = salesState.sales.where((s) => s.status == 'completed');

    for (var sale in completedSales) {
      final isToday = sale.date.isAfter(todayStart) || sale.date.isAtSameMomentAs(todayStart);
      final isThisMonth = sale.date.isAfter(monthStart) || sale.date.isAtSameMomentAs(monthStart);

      if (isToday) {
        todayRevenue += sale.grandTotal;
        todayTxCount++;
      }

      if (isThisMonth) {
        monthRevenue += sale.grandTotal;
      }

      // Populate chart data (aggregate sales matching last 7 days range)
      final saleDay = sale.date.day;
      if (dailySalesChartData.containsKey(saleDay)) {
        dailySalesChartData[saleDay] = (dailySalesChartData[saleDay] ?? 0.0) + sale.grandTotal;
      }

      // Group for leaderboard
      for (var item in sale.items) {
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

    // Sort leaderboard by quantity sold
    final topItems = itemLeaderboard.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    final leaderboardLimit = topItems.length > 5 ? topItems.sublist(0, 5) : topItems;

    // Prepare chart spots
    final chartEntries = dailySalesChartData.entries.toList();
    final List<FlSpot> spots = [];
    for (int i = 0; i < chartEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), chartEntries[i].value));
    }

    final double maxVal = dailySalesChartData.values.fold(100000.0, (prev, val) => val > prev ? val : prev);

    return MainLayout(
      currentRoute: '/dashboard',
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Dashboard Analitik', style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final count = constraints.maxWidth < 700 ? 1 : 3;
                          return GridView.count(
                            crossAxisCount: count,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.3,
                            children: [
                              _buildStatCard(
                                context,
                                'Penjualan Hari Ini',
                                _formatRupiah(todayRevenue),
                                Icons.monetization_on_rounded,
                                Colors.teal,
                              ),
                              _buildStatCard(
                                context,
                                'Transaksi Hari Ini',
                                '$todayTxCount Transaksi',
                                Icons.shopping_basket_rounded,
                                Colors.orange,
                              ),
                              _buildStatCard(
                                context,
                                'Pendapatan Bulan Ini',
                                _formatRupiah(monthRevenue),
                                Icons.account_balance_wallet_rounded,
                                Colors.indigo,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Chart and Leaderboard row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 1000) {
                            return Column(
                              children: [
                                _buildChartCard(context, spots, chartEntries, maxVal),
                                const SizedBox(height: 24),
                                _buildLeaderboardCard(context, leaderboardLimit),
                              ],
                            );
                          } else {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildChartCard(context, spots, chartEntries, maxVal),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildLeaderboardCard(context, leaderboardLimit),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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

  Widget _buildChartCard(BuildContext context, List<FlSpot> spots, List<MapEntry<int, double>> entries, double maxVal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grafik Penjualan 7 Hari Terakhir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 250,
              child: spots.isEmpty
                  ? const Center(child: Text('Tidak ada data penjualan'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
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
                                      'Tgl ${entries[idx].key}',
                                      style: TextStyle(
                                        fontSize: 10,
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
                            barWidth: 4,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            ),
                          ),
                        ],
                        minX: 0,
                        maxX: spots.length - 1.toDouble(),
                        minY: 0,
                        maxY: maxVal * 1.1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, List<_TopItem> topItems) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produk Terlaris',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (topItems.isEmpty)
              const SizedBox(
                height: 200,
                child: Center(child: Text('Belum ada transaksi')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topItems.length,
                separatorBuilder: (c, i) => const Divider(height: 16, indent: 48),
                itemBuilder: (context, index) {
                  final item = topItems[index];
                  return Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Terjual ${item.qty} item',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatRupiah(item.revenue),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
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
