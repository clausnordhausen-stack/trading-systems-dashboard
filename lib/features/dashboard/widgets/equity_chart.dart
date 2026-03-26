import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class EquityChart extends StatelessWidget {
  final List<double> equity;

  const EquityChart({super.key, required this.equity});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];

    for (int i = 0; i < equity.length; i++) {
      spots.add(FlSpot(i.toDouble(), equity[i]));
    }

    double minY = equity.first;
    double maxY = equity.first;

    for (final v in equity) {
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }

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
          const Text(
            'Equity Curve',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xFF2A2A3D)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
                    barWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}