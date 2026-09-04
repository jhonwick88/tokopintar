import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../../data/models/stock_ledger_model.dart';

class StockLedgerScreen extends ConsumerStatefulWidget {
  final String itemNo;
  final String itemName;

  const StockLedgerScreen({
    Key? key,
    required this.itemNo,
    required this.itemName,
  }) : super(key: key);

  @override
  ConsumerState<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends ConsumerState<StockLedgerScreen> {
  List<StockLedgerModel> _ledgers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final ledgers = await client.getStockLedger(widget.itemNo);
      if (mounted) {
        setState(() {
          _ledgers = ledgers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  Widget _buildTxIcon(String txType) {
    IconData iconData;
    Color color;

    switch (txType.toUpperCase()) {
      case 'SALE':
        iconData = Icons.shopping_cart_checkout;
        color = Colors.red;
        break;
      case 'ADJ':
        iconData = Icons.edit_note;
        color = Colors.orange;
        break;
      default:
        iconData = Icons.swap_horiz;
        color = Colors.blue;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(iconData, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kartu Stok: ${widget.itemName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      ElevatedButton(
                        onPressed: _loadLedger,
                        child: const Text('Coba Lagi'),
                      )
                    ],
                  ),
                )
              : _ledgers.isEmpty
                  ? const Center(child: Text('Belum ada histori pergerakan stok'))
                  : ListView.builder(
                      itemCount: _ledgers.length,
                      itemBuilder: (context, index) {
                        final ledger = _ledgers[index];
                        final isPositive = ledger.qty > 0;
                        final qtyStr = isPositive ? '+${ledger.qty}' : '${ledger.qty}';
                        final qtyColor = isPositive ? Colors.green : Colors.red;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: _buildTxIcon(ledger.txType),
                            title: Text(
                              ledger.txType == 'SALE' ? 'Penjualan' : 
                              ledger.txType == 'ADJ' ? 'Penyesuaian' : ledger.txType,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatDate(ledger.timestamp)),
                                if (ledger.notes.isNotEmpty) 
                                  Text('Catatan: ${ledger.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                if (ledger.referenceId.isNotEmpty)
                                  Text('Ref: ${ledger.referenceId}'),
                              ],
                            ),
                            isThreeLine: ledger.notes.isNotEmpty || ledger.referenceId.isNotEmpty,
                            trailing: Text(
                              qtyStr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: qtyColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
