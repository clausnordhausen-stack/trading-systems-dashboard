import 'package:flutter/material.dart';

import 'package:trading_systems_dashboard/data/mt5_html_importer.dart';
import 'package:trading_systems_dashboard/domain/trade.dart';

import 'widgets/equity_chart.dart';
import 'widgets/kpi_card.dart';
import 'widgets/sidebar.dart';
import 'widgets/trade_table.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Row(
        children: [
          Sidebar(),
          Expanded(child: DashboardBody()),
        ],
      ),
    );
  }
}

class DashboardBody extends StatefulWidget {
  const DashboardBody({super.key});

  @override
  State<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<DashboardBody> {
  List<Trade> trades = demoTrades();

  Future<void> _pickAndImportMt5() async {
    try {
      const filePath = r'C:\Users\claus\Desktop\mt5_history.html';
      final imported = Mt5HtmlImporter.parseTradesFromHtmlFile(filePath);

      if (imported.isEmpty) {
        debugPrint("⚠ Keine Trades erkannt – Parser ggf. anpassen.");
        return;
      }

      setState(() {
        trades = imported;
      });

      debugPrint("✅ ${imported.length} Trades importiert.");
    } catch (e) {
      debugPrint("❌ Fehler beim Import: $e");
    }
  }

  List<double> _buildEquity(List<Trade> t, {double start = 10000}) {
    final sorted = [...t]..sort((a, b) => a.time.compareTo(b.time));
    final eq = <double>[start];

    double cur = start;
    for (final tr in sorted) {
      cur += tr.pnl;
      eq.add(cur);
    }
    return eq;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: _pickAndImportMt5,
                child: const Text("Import MT5"),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: KpiCard(title: 'Total Profit', value: '\$124,530')),
              SizedBox(width: 16),
              Expanded(child: KpiCard(title: 'Win Rate', value: '63%')),
              SizedBox(width: 16),
              Expanded(child: KpiCard(title: 'Max Drawdown', value: '-8.4%')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: EquityChart(
                    equity: _buildEquity(trades),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TradeTable(trades: trades),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}