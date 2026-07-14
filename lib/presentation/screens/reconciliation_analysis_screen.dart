import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/reconciliation_provider.dart';
import '../../data/models/cash_reconciliation_model.dart';
import '../widgets/main_layout.dart';

class ReconciliationAnalysisScreen extends ConsumerWidget {
  const ReconciliationAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reconciliationProvider);
    final width = MediaQuery.of(context).size.width;
    final isLarge = width >= 900;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');

    return MainLayout(
      currentRoute: '/reconciliation-analysis',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analisis Kas Laci', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang',
              onPressed: () => ref.read(reconciliationProvider.notifier).fetchReconciliations(),
            ),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ROW 1: Filters Bar
                          _buildFiltersBar(context, ref, state),
                          const SizedBox(height: 20),

                          // ROW 2: Statistics Overview
                          _buildStatsRow(context, isLarge, state, currencyFormatter),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: const Text(
                            'Riwayat Rekonsiliasi Kas',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        height: 40.0,
                      ),
                    ),
                    if (state.filteredReconciliations.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Tidak ada data rekonsiliasi kas untuk periode ini.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else if (isLarge)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildDesktopTable(state, currencyFormatter, dateFormatter),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final rec = state.filteredReconciliations[index];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: _buildMobileCard(rec, currencyFormatter, dateFormatter),
                            );
                          },
                          childCount: state.filteredReconciliations.length,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFiltersBar(BuildContext context, WidgetRef ref, ReconciliationState state) {
    final startStr = state.customStartDate != null ? DateFormat('dd/MM/yyyy').format(state.customStartDate!) : '';
    final endStr = state.customEndDate != null ? DateFormat('dd/MM/yyyy').format(state.customEndDate!) : '';
    final rangeText = state.filterType == 'custom' && state.customStartDate != null
        ? ' ($startStr - $endStr)'
        : '';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Segmented Control for Quick Filters
        Container(
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentItem(
                context: context,
                label: 'Hari Ini',
                isSelected: state.filterType == 'today',
                onTap: () => ref.read(reconciliationProvider.notifier).setFilterType('today'),
              ),
              _buildSegmentItem(
                context: context,
                label: 'Minggu Ini',
                isSelected: state.filterType == 'weekly',
                onTap: () => ref.read(reconciliationProvider.notifier).setFilterType('weekly'),
              ),
              _buildSegmentItem(
                context: context,
                label: 'Bulan Ini',
                isSelected: state.filterType == 'monthly',
                onTap: () => ref.read(reconciliationProvider.notifier).setFilterType('monthly'),
              ),
            ],
          ),
        ),

        // Custom Date Range Picker Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
                initialDateRange: state.customStartDate != null && state.customEndDate != null
                    ? DateTimeRange(start: state.customStartDate!, end: state.customEndDate!)
                    : null,
              );
              if (picked != null) {
                ref.read(reconciliationProvider.notifier).setCustomDateRange(picked.start, picked.end);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: state.filterType == 'custom'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                boxShadow: state.filterType == 'custom'
                    ? [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 16,
                    color: state.filterType == 'custom' ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.filterType == 'custom' ? 'Kustom$rangeText' : 'Tanggal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: state.filterType == 'custom' ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildStatsRow(BuildContext context, bool isLarge, ReconciliationState state, NumberFormat currencyFormatter) {
    final double accuracy = state.averageAccuracy;
    
    // Gradient definitions
    final accuracyGradient = [const Color(0xFF0F9B0F), const Color(0xFF4CAF50)];
    
    final discrepancyGradient = state.totalDiscrepancyCount > 0
        ? [const Color(0xFFC62828), const Color(0xFFEF5350)]
        : [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];

    final differenceGradient = state.totalDifference == 0
        ? [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]
        : (state.totalDifference < 0
            ? [const Color(0xFFE65100), const Color(0xFFF57C00)]
            : [const Color(0xFF0288D1), const Color(0xFF29B6F6)]);

    if (isLarge) {
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildStatCard(
                context: context,
                title: 'Akurasi',
                value: '${accuracy.toStringAsFixed(1)}%',
                icon: Icons.percent,
                gradientColors: accuracyGradient,
                accuracy: accuracy,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildStatCard(
                context: context,
                title: 'Selisih Kas',
                value: '${state.totalDiscrepancyCount} kali',
                icon: Icons.error_outline,
                gradientColors: discrepancyGradient,
              ),
            ),
          ),
          Expanded(
            child: _buildStatCard(
              context: context,
              title: 'Akumulasi Selisih',
              value: (state.totalDifference > 0 ? '+' : '') + currencyFormatter.format(state.totalDifference),
              icon: Icons.account_balance_wallet,
              gradientColors: differenceGradient,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context: context,
                  title: 'Akurasi',
                  value: '${accuracy.toStringAsFixed(1)}%',
                  icon: Icons.percent,
                  gradientColors: accuracyGradient,
                  accuracy: accuracy,
                  isCompact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  context: context,
                  title: 'Selisih Kas',
                  value: '${state.totalDiscrepancyCount} kali',
                  icon: Icons.error_outline,
                  gradientColors: discrepancyGradient,
                  isCompact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatCard(
            context: context,
            title: 'Akumulasi Selisih',
            value: (state.totalDifference > 0 ? '+' : '') + currencyFormatter.format(state.totalDifference),
            icon: Icons.account_balance_wallet,
            gradientColors: differenceGradient,
            isCompact: false,
          ),
        ],
      );
    }
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    double? accuracy,
    bool isCompact = false,
  }) {
    Widget progressWidget;
    if (accuracy != null) {
      progressWidget = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: isCompact ? 32 : 44,
            height: isCompact ? 32 : 44,
            child: CircularProgressIndicator(
              value: accuracy / 100.0,
              strokeWidth: isCompact ? 3.0 : 4.0,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Text(
            '${accuracy.toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 9 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      progressWidget = CircleAvatar(
        radius: isCompact ? 16 : 22,
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Colors.white,
        child: Icon(icon, size: isCompact ? 18 : 24),
      );
    }

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
              padding: EdgeInsets.all(isCompact ? 12.0 : 18.0),
              child: Row(
                children: [
                  progressWidget,
                  SizedBox(width: isCompact ? 10 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isCompact ? 11 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: isCompact ? 14 : 18,
                          ),
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

  Widget _buildDesktopTable(
      ReconciliationState state, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.03)),
              columns: const [
                DataColumn(label: Text('Tanggal & Waktu', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Kasir', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Omzet Sistem', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Uang di Laci', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Selisih', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Akurasi', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Catatan', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: state.filteredReconciliations.map((rec) {
                return DataRow(
                  cells: [
                    DataCell(Text(dateFormatter.format(rec.date))),
                    DataCell(Text(rec.cashierName)),
                    DataCell(Text(currencyFormatter.format(rec.systemRevenue))),
                    DataCell(Text(currencyFormatter.format(rec.actualDrawerCash))),
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: _buildDifferenceBadge(rec.difference, currencyFormatter),
                    )),
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: _buildAccuracyBadge(rec.accuracyRate),
                    )),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          rec.notes.isEmpty ? '-' : rec.notes,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifferenceBadge(double difference, NumberFormat currencyFormatter) {
    Color bg;
    Color fg;
    IconData icon;
    String prefix = '';

    if (difference == 0) {
      bg = Colors.green.withOpacity(0.12);
      fg = Colors.green.shade800;
      icon = Icons.check_circle_outline_rounded;
    } else if (difference < 0) {
      bg = Colors.red.withOpacity(0.12);
      fg = Colors.red.shade800;
      icon = Icons.arrow_downward_rounded;
    } else {
      bg = Colors.orange.withOpacity(0.12);
      fg = Colors.orange.shade800;
      icon = Icons.arrow_upward_rounded;
      prefix = '+';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            prefix + currencyFormatter.format(difference),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyBadge(double accuracy) {
    Color bg;
    Color fg;
    if (accuracy >= 98.0) {
      bg = Colors.green.withOpacity(0.12);
      fg = Colors.green.shade800;
    } else if (accuracy >= 90.0) {
      bg = Colors.orange.withOpacity(0.12);
      fg = Colors.orange.shade800;
    } else {
      bg = Colors.red.withOpacity(0.12);
      fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${accuracy.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildMobileCard(
      CashReconciliationModel rec, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rec.cashierName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              _buildDifferenceBadge(rec.difference, currencyFormatter),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              dateFormatter.format(rec.date),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          children: [
            Divider(height: 1, color: Colors.grey.withOpacity(0.12)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Omzet Sistem', currencyFormatter.format(rec.systemRevenue)),
                  const SizedBox(height: 8),
                  _buildDetailRow('Uang Fisik Laci', currencyFormatter.format(rec.actualDrawerCash)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Akurasi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      _buildAccuracyBadge(rec.accuracyRate),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Catatan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rec.notes.isEmpty ? 'Tidak ada catatan' : rec.notes,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyHeaderDelegate({
    required this.child,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
