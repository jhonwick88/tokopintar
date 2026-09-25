import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/reconciliation_provider.dart' hide DateTimeRange;
import '../../data/models/cash_reconciliation_model.dart';
import '../../data/models/cash_movement_model.dart';
import '../widgets/main_layout.dart';
import '../widgets/cash_out_dialog.dart';

class ReconciliationAnalysisScreen extends ConsumerStatefulWidget {
  const ReconciliationAnalysisScreen({super.key});

  @override
  ConsumerState<ReconciliationAnalysisScreen> createState() => _ReconciliationAnalysisScreenState();
}

class _ReconciliationAnalysisScreenState extends ConsumerState<ReconciliationAnalysisScreen> {
  int _selectedTab = 0; // 0: Rekonsiliasi Kas, 1: Kas Keluar

  @override
  Widget build(BuildContext context) {
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Catat Kas Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => CashOutDialog.show(context),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang',
              onPressed: () => ref.read(reconciliationProvider.notifier).fetchReconciliations(),
            ),
            const SizedBox(width: 8),
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
                          const _ReconciliationFiltersBar(),
                          const SizedBox(height: 20),

                          // ROW 2: Statistics Overview
                          _buildStatsRow(context, isLarge, state, currencyFormatter),
                          const SizedBox(height: 24),

                          // ROW 3: Tab Selector (Rekonsiliasi vs Kas Keluar)
                          _buildTabSelector(state),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // TAB 0: REKONSILIASI KAS
                    if (_selectedTab == 0) ...[
                      if (state.filteredReconciliations.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'Tidak ada data rekonsiliasi kas untuk periode ini.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      else if (isLarge)
                        SliverToBoxAdapter(
                          child: _buildDesktopTable(state, currencyFormatter, dateFormatter),
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
                    ]
                    // TAB 1: KAS KELUAR (PETTY CASH)
                    else ...[
                      if (state.filteredCashMovements.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.output_rounded, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Belum ada pengeluaran kas laci untuk periode ini.',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => CashOutDialog.show(context),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Catat Kas Keluar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (isLarge)
                        SliverToBoxAdapter(
                          child: _buildCashMovementsDesktopTable(state, currencyFormatter, dateFormatter),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final mov = state.filteredCashMovements[index];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: _buildCashMovementMobileCard(mov, currencyFormatter, dateFormatter),
                              );
                            },
                            childCount: state.filteredCashMovements.length,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTabSelector(ReconciliationState state) {
    return SegmentedButton<int>(
      segments: [
        ButtonSegment<int>(
          value: 0,
          icon: const Icon(Icons.balance, size: 18),
          label: Text('Tutup Kasir (${state.filteredReconciliations.length})'),
        ),
        ButtonSegment<int>(
          value: 1,
          icon: const Icon(Icons.output_rounded, size: 18),
          label: Text('Kas Keluar (${state.filteredCashMovements.length})'),
        ),
      ],
      selected: {_selectedTab},
      onSelectionChanged: (newSelection) {
        setState(() {
          _selectedTab = newSelection.first;
        });
      },
    );
  }

  Widget _buildStatsRow(BuildContext context, bool isLarge, ReconciliationState state, NumberFormat currencyFormatter) {
    final double accuracy = state.averageAccuracy;
    
    final accuracyGradient = [const Color(0xFF0F9B0F), const Color(0xFF4CAF50)];
    
    final discrepancyGradient = state.totalDiscrepancyCount > 0
        ? [const Color(0xFFC62828), const Color(0xFFEF5350)]
        : [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];

    final differenceGradient = state.totalDifference == 0
        ? [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]
        : (state.totalDifference < 0
            ? [const Color(0xFFE65100), const Color(0xFFF57C00)]
            : [const Color(0xFF0288D1), const Color(0xFF29B6F6)]);

    final cashOutGradient = [const Color(0xFFD84315), const Color(0xFFFF7043)];

    if (isLarge) {
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildStatCard(
                context: context,
                title: 'Akurasi Kas',
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
                title: 'Total Kas Keluar',
                value: currencyFormatter.format(state.totalCashOut),
                icon: Icons.output_rounded,
                gradientColors: cashOutGradient,
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
                  title: 'Kas Keluar',
                  value: currencyFormatter.format(state.totalCashOut),
                  icon: Icons.output_rounded,
                  gradientColors: cashOutGradient,
                  isCompact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
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
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  context: context,
                  title: 'Akumulasi Selisih',
                  value: (state.totalDifference > 0 ? '+' : '') + currencyFormatter.format(state.totalDifference),
                  icon: Icons.account_balance_wallet,
                  gradientColors: differenceGradient,
                  isCompact: true,
                ),
              ),
            ],
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
                            fontSize: isCompact ? 13 : 17,
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

  // --- RECONCILIATION DESKTOP TABLE ---
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
                DataColumn(label: Text('Kas Sistem (Seharusnya)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Uang Fisik Laci', style: TextStyle(fontWeight: FontWeight.bold))),
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

  // --- KAS KELUAR DESKTOP TABLE ---
  Widget _buildCashMovementsDesktopTable(
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
                DataColumn(label: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Nominal', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Kasir / Operator', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Keperluan / Catatan', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: state.filteredCashMovements.map((mov) {
                return DataRow(
                  cells: [
                    DataCell(Text(dateFormatter.format(mov.date))),
                    DataCell(_buildCategoryBadge(mov.category)),
                    DataCell(
                      Text(
                        currencyFormatter.format(mov.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ),
                    DataCell(Text(mov.cashierName)),
                    DataCell(
                      SizedBox(
                        width: 250,
                        child: Text(
                          mov.notes.isEmpty ? '-' : mov.notes,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        tooltip: 'Hapus Catatan',
                        onPressed: () => _confirmDeleteCashMovement(context, mov),
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

  Widget _buildCategoryBadge(String category) {
    Color bg;
    Color fg;
    IconData icon;

    switch (category.toLowerCase()) {
      case 'pengamen':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        icon = Icons.music_note_rounded;
        break;
      case 'sumbangan':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        icon = Icons.volunteer_activism_rounded;
        break;
      case 'operasional':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        icon = Icons.shopping_bag_rounded;
        break;
      case 'konsumsi':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        icon = Icons.local_cafe_rounded;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        icon = Icons.label_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            category,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            '${accuracy.toStringAsFixed(1)}%',
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
                  _buildDetailRow('Kas Seharusnya', currencyFormatter.format(rec.systemRevenue)),
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

  Widget _buildCashMovementMobileCard(
      CashMovementModel mov, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCategoryBadge(mov.category),
                Text(
                  currencyFormatter.format(mov.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (mov.notes.isNotEmpty) ...[
              Text(
                mov.notes,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${mov.cashierName} • ${dateFormatter.format(mov.date)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => _confirmDeleteCashMovement(context, mov),
                  tooltip: 'Hapus',
                ),
              ],
            ),
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

  void _confirmDeleteCashMovement(BuildContext context, CashMovementModel mov) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Catatan Kas Keluar?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus catatan pengeluaran ${mov.category} sebesar Rp ${NumberFormat("#,##0", "id_ID").format(mov.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await ref.read(reconciliationProvider.notifier).deleteCashMovement(mov.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Catatan kas keluar berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
                  );
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
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

class _ReconciliationFiltersBar extends ConsumerStatefulWidget {
  const _ReconciliationFiltersBar({Key? key}) : super(key: key);

  @override
  ConsumerState<_ReconciliationFiltersBar> createState() => _ReconciliationFiltersBarState();
}

class _ReconciliationFiltersBarState extends ConsumerState<_ReconciliationFiltersBar> {
  DateTime? _customStart;
  DateTime? _customEnd;

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );

    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
      });
      ref.read(reconciliationProvider.notifier).setCustomDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reconciliationProvider);
    final isCustom = state.filterType == 'custom';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: 'Hari Ini',
                isSelected: state.filterType == 'today',
                onSelected: () {
                  setState(() {
                    _customStart = null;
                    _customEnd = null;
                  });
                  ref.read(reconciliationProvider.notifier).setFilterType('today');
                },
              ),
              _buildFilterChip(
                label: '7 Hari',
                isSelected: state.filterType == 'weekly',
                onSelected: () {
                  setState(() {
                    _customStart = null;
                    _customEnd = null;
                  });
                  ref.read(reconciliationProvider.notifier).setFilterType('weekly');
                },
              ),
              _buildFilterChip(
                label: 'Bulan Ini',
                isSelected: state.filterType == 'monthly',
                onSelected: () {
                  setState(() {
                    _customStart = null;
                    _customEnd = null;
                  });
                  ref.read(reconciliationProvider.notifier).setFilterType('monthly');
                },
              ),
              _buildFilterChip(
                label: isCustom && state.customStartDate != null && state.customEndDate != null
                    ? '${DateFormat('dd/MM').format(state.customStartDate!)} - ${DateFormat('dd/MM').format(state.customEndDate!)}'
                    : 'Kustom',
                isSelected: isCustom,
                icon: Icons.calendar_today_rounded,
                onSelected: () => _pickDateRange(context),
              ),
            ],
          ),
          if (isCustom)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _customStart = null;
                  _customEnd = null;
                });
                ref.read(reconciliationProvider.notifier).setFilterType('weekly');
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Reset Filter'),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
  }) {
    return ChoiceChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 14,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700],
            )
          : null,
      label: Text(label),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[800],
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
