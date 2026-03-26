import 'package:flutter/material.dart';
import 'package:trading_systems_dashboard/domain/trade.dart';

class TradeTable extends StatelessWidget {
  final List<Trade> trades;

  const TradeTable({super.key, required this.trades});

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = trades.map<DataRow>((t) {
      final pnlColor = t.pnl >= 0 ? Colors.greenAccent : Colors.redAccent;

      return DataRow(
        cells: [
          DataCell(Text(_fmtDate(t.time))),
          DataCell(Text(t.symbol)),
          DataCell(Text(t.side)),
          DataCell(Text(t.lots.toStringAsFixed(2))),
          DataCell(Text(t.entry.toStringAsFixed(2))),
          DataCell(Text(t.exit.toStringAsFixed(2))),
          DataCell(Text(t.pnl.toStringAsFixed(2), style: TextStyle(color: pnlColor))),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Trades', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Symbol')),
                  DataColumn(label: Text('Side')),
                  DataColumn(label: Text('Lots')),
                  DataColumn(label: Text('Entry')),
                  DataColumn(label: Text('Exit')),
                  DataColumn(label: Text('PnL')),
                ],
                rows: rows,
              ),
            ),
          ),
        ],
      ),
    );
  }
}