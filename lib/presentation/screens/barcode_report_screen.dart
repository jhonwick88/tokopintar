import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_pkg;

import '../providers/barcode_report_provider.dart';
import '../providers/users_provider.dart';
import '../widgets/main_layout.dart';
import '../../core/utils/file_saver_helper.dart';
import '../../data/models/barcode_log_model.dart';

class BarcodeReportScreen extends ConsumerStatefulWidget {
  const BarcodeReportScreen({super.key});

  @override
  ConsumerState<BarcodeReportScreen> createState() => _BarcodeReportScreenState();
}

class _BarcodeReportScreenState extends ConsumerState<BarcodeReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy, HH:mm');
  final DateFormat _shortDateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(barcodeReportProvider.notifier).loadReport();
      ref.read(usersNotifierProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final state = ref.read(barcodeReportProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(now.year + 2),
      initialDateRange: state.startDate != null && state.endDate != null
          ? DateTimeRange(start: state.startDate!, end: state.endDate!)
          : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );

    if (picked != null) {
      ref.read(barcodeReportProvider.notifier).setCustomRange(picked.start, picked.end);
    }
  }

  Future<void> _exportToExcel(List<BarcodeLogModel> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Riwayat Rekam Barcode'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_pkg.TextCellValue('No'),
        excel_pkg.TextCellValue('Waktu Perekaman'),
        excel_pkg.TextCellValue('SKU Produk'),
        excel_pkg.TextCellValue('Nama Produk'),
        excel_pkg.TextCellValue('Barcode Baru'),
        excel_pkg.TextCellValue('Barcode Sebelumnya'),
        excel_pkg.TextCellValue('Direkam Oleh'),
      ]);

      for (int i = 0; i < logs.length; i++) {
        final l = logs[i];
        sheet.appendRow([
          excel_pkg.IntCellValue(i + 1),
          excel_pkg.TextCellValue(_dateFormatter.format(l.recordedAt)),
          excel_pkg.TextCellValue(l.itemNo),
          excel_pkg.TextCellValue(l.itemName),
          excel_pkg.TextCellValue(l.barcode),
          excel_pkg.TextCellValue(l.previousBarcode.isEmpty ? '-' : l.previousBarcode),
          excel_pkg.TextCellValue(l.username),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final fileName = 'Laporan_Rekam_Barcode_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
        final saved = await FileSaverHelper.saveFile(
          bytes: fileBytes,
          fileName: fileName,
          dialogTitle: 'Simpan Laporan Rekam Barcode Excel',
          allowedExtensions: ['xlsx'],
        );
        if (mounted && saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File Excel berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(barcodeReportProvider);
    final usersState = ref.watch(usersNotifierProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final filteredLogs = state.filteredLogs;
    final reportData = state.data;

    return MainLayout(
      currentRoute: '/barcode-report',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan Rekam Barcode', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang',
              onPressed: () => ref.read(barcodeReportProvider.notifier).loadReport(),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Ekspor Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _exportToExcel(filteredLogs),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Filters Bar
                    _buildFiltersBar(context, state, usersState),
                    const SizedBox(height: 20),

                    // ROW 2: KPI Summary Cards
                    _buildKpiSummary(context, isDesktop, reportData),
                    const SizedBox(height: 24),

                    // ROW 3: Staff Leaderboard / Progress
                    if (reportData.staffStats.isNotEmpty) ...[
                      _buildStaffProgressCard(reportData.staffStats, isDesktop),
                      const SizedBox(height: 24),
                    ],

                    // ROW 4: Data Table of Logs
                    _buildLogsTableCard(filteredLogs, isDesktop),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFiltersBar(BuildContext context, BarcodeReportState state, UsersState usersState) {
    final isCustom = state.datePreset == 'custom';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 4),
                const Text('Periode: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                _buildPresetChip('Hari Ini', 'today', state.datePreset),
                _buildPresetChip('7 Hari Terakhir', 'last7days', state.datePreset),
                _buildPresetChip('1 Bulan Terakhir', 'last30days', state.datePreset),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    isCustom && state.startDate != null && state.endDate != null
                        ? '${_shortDateFormatter.format(state.startDate!)} - ${_shortDateFormatter.format(state.endDate!)}'
                        : 'Pilih Rentang...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  backgroundColor: isCustom ? Theme.of(context).colorScheme.primaryContainer : null,
                  onPressed: () => _pickDateRange(context),
                ),
              ],
            ),
            const Divider(height: 24),
            // User filter & Search
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // User Filter Dropdown
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: state.selectedUser,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Perekam Barcode',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Semua Staf / Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ...usersState.users.map((u) {
                        final displayName = u.fullname.isNotEmpty ? u.fullname : u.username;
                        return DropdownMenuItem(
                          value: u.username,
                          child: Text('$displayName (@${u.username})', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(barcodeReportProvider.notifier).setUserFilter(val);
                      }
                    },
                  ),
                ),
                // Search Input
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari produk, SKU, barcode, nama staf...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(barcodeReportProvider.notifier).setSearchQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      ref.read(barcodeReportProvider.notifier).setSearchQuery(val);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String presetKey, String currentPreset) {
    final isSelected = currentPreset == presetKey;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(barcodeReportProvider.notifier).applyDatePreset(presetKey);
        }
      },
    );
  }

  Widget _buildKpiSummary(BuildContext context, bool isDesktop, BarcodeReportData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = isDesktop ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              title: 'Barcode Direkam (Periode Ini)',
              value: '${data.totalPeriod} Produk',
              subtitle: 'Aktivitas perekaman barcode',
              icon: Icons.qr_code_scanner,
              color: Colors.blue,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Staf Paling Aktif',
              value: data.topRecorder,
              subtitle: 'Kontributor barcode tertinggi',
              icon: Icons.emoji_events_outlined,
              color: Colors.amber.shade800,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Progress Barcode Toko',
              value: '${data.storeWithBarcode} / ${data.totalStoreItems} (${data.storeProgressPct.toStringAsFixed(1)}%)',
              subtitle: '${data.totalStoreItems - data.storeWithBarcode} produk belum ber-barcode',
              icon: Icons.fact_check_outlined,
              color: Colors.green,
              width: cardWidth,
              progressValue: data.storeProgressPct / 100.0,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    double? progressValue,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (progressValue != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffProgressCard(List<StaffBarcodeStatModel> stats, bool isDesktop) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard_outlined, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Perkembangan Rekam Barcode per Staf / Kasir',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text('${stats.length} Perekam', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            ...stats.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                s.username.isNotEmpty ? s.username[0].toUpperCase() : 'U',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(s.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        Text(
                          '${s.count} Produk (${s.percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (s.percentage / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsTableCard(List<BarcodeLogModel> logs, bool isDesktop) {
    if (logs.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.12)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.qr_code_2, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Belum ada rekaman barcode untuk filter periode ini.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Detail Perekaman (${logs.length} Baris)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.04)),
                columns: const [
                  DataColumn(label: Text('Waktu Rekam', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SKU (itemNo)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Nama Produk', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Barcode Baru (UPC)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Barcode Lama', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Direkam Oleh', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: logs.map((l) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_dateFormatter.format(l.recordedAt))),
                      DataCell(Text(l.itemNo, style: const TextStyle(fontFamily: 'monospace'))),
                      DataCell(SizedBox(
                        width: 250,
                        child: Text(l.itemName, overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(l.barcode, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )),
                      DataCell(Text(l.previousBarcode.isEmpty ? '-' : l.previousBarcode, style: TextStyle(color: Colors.grey.shade600))),
                      DataCell(Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.blue.shade700,
                          child: Text(
                            l.username.isNotEmpty ? l.username[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                        label: Text(l.username, style: const TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
