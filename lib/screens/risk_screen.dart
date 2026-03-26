import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/app_session.dart';
import '../service/api_service.dart';

class RiskScreen extends StatefulWidget {
  const RiskScreen({super.key});

  @override
  State<RiskScreen> createState() => _RiskScreenState();
}

class _RiskScreenState extends State<RiskScreen> {
  final ApiService _api = ApiService();

  final TextEditingController _accountSizeController = TextEditingController();
  final TextEditingController _riskPctController = TextEditingController();
  final TextEditingController _stopLossController = TextEditingController();

  Map<String, Future<Map<String, dynamic>>> _futures = {};
  final Map<String, bool> _expanded = {};

  Timer? _timer;

  String _riskPerTrade = '-';
  String _positionSize = '-';
  String _mode = 'Waiting for input';

  @override
  void initState() {
    super.initState();
    _load();
    _startTimer();
    AppSession.selectedAccount.addListener(_accountChanged);
    AppSession.refreshSeconds.addListener(_refreshChanged);
    AppSession.settingsVersion.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accountSizeController.dispose();
    _riskPctController.dispose();
    _stopLossController.dispose();
    AppSession.selectedAccount.removeListener(_accountChanged);
    AppSession.refreshSeconds.removeListener(_refreshChanged);
    AppSession.settingsVersion.removeListener(_settingsChanged);
    super.dispose();
  }

  void _accountChanged() {
    if (!mounted) return;
    setState(_load);
  }

  void _refreshChanged() {
    _startTimer();
  }

  void _settingsChanged() {
    if (!mounted) return;
    setState(_load);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: AppSession.refreshSeconds.value),
      (timer) {
        if (!mounted) return;
        setState(_load);
      },
    );
  }

  void _syncExpandedState(List<String> symbols) {
    for (final symbol in symbols) {
      _expanded.putIfAbsent(symbol, () => symbol == symbols.first);
    }

    final keysToRemove =
        _expanded.keys.where((key) => !symbols.contains(key)).toList();
    for (final key in keysToRemove) {
      _expanded.remove(key);
    }
  }

  void _load() {
    final account = AppSession.selectedAccount.value;
    final symbols = AppSession.trackedSymbolsForSelectedAccount;

    _syncExpandedState(symbols);

    _futures = {
      for (final symbol in symbols)
        symbol: _api.fetchRiskBundle(
          symbol: symbol,
          account: account,
          magic: AppSession.magicFor(
            account: account,
            symbol: symbol,
          ),
        ),
    };
  }

  Future<void> refreshData() async {
    if (!mounted) return;
    setState(_load);
  }

  bool _isMobileWidth(BuildContext context) {
    return MediaQuery.of(context).size.width < 760;
  }

  String _symbolLabel(String symbol) {
    final account = AppSession.selectedAccount.value;
    final displayName = AppSession.displayNameForSymbol(
      account: account,
      symbol: symbol,
    );
    return '$displayName ($symbol)';
  }

  Color _symbolColor(String symbol) {
    final account = AppSession.selectedAccount.value;
    return AppSession.colorForSymbol(account: account, symbol: symbol);
  }

  double _parseInput(String text) {
    return double.tryParse(text.replaceAll(',', '.').trim()) ?? double.nan;
  }

  void _calculateRisk() {
    final accountSize = _parseInput(_accountSizeController.text);
    final riskPct = _parseInput(_riskPctController.text);
    final stopLoss = _parseInput(_stopLossController.text);

    if (accountSize.isNaN ||
        riskPct.isNaN ||
        stopLoss.isNaN ||
        accountSize <= 0 ||
        riskPct <= 0 ||
        stopLoss <= 0) {
      setState(() {
        _riskPerTrade = '-';
        _positionSize = '-';
        _mode = 'Invalid input';
      });
      return;
    }

    final riskUsd = accountSize * (riskPct / 100.0);
    final positionSize = riskUsd / stopLoss;

    setState(() {
      _riskPerTrade = riskUsd.toStringAsFixed(2);
      _positionSize = positionSize.toStringAsFixed(4);
      _mode = 'Calculated';
    });
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _compactNumber(dynamic value, {int fractionDigits = 2}) {
    final number = _toDouble(value);
    if (number == 0 && (value == null || value.toString().trim().isEmpty)) {
      return '-';
    }
    if (number % 1 == 0) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(fractionDigits);
  }

  String _shortBool(dynamic value) {
    if (value == true) return 'YES';
    if (value == false) return 'NO';
    return '-';
  }

  String _formatIsoShort(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty || text == '-') return '-';
    final dt = DateTime.tryParse(text);
    if (dt == null) return text;
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String value) {
    final v = value.toUpperCase();
    if (v == 'GREEN' || v == 'ONLINE' || v == 'TRUE' || v == 'APPROVED') {
      return Colors.greenAccent;
    }
    if (v == 'YELLOW' || v == 'WARNING') {
      return Colors.orangeAccent;
    }
    if (v == 'RED' || v == 'OFFLINE' || v == 'FALSE' || v == 'BLOCKED') {
      return Colors.redAccent;
    }
    if (v == 'OFF') {
      return Colors.white70;
    }
    return Colors.lightBlueAccent;
  }

  Widget _resultRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                fontSize: strong ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (accent ?? Colors.white24).withOpacity(0.35),
        ),
        color: accent == null ? null : accent.withOpacity(0.06),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ?? Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _topStatCard({
    required String title,
    required String value,
    IconData? icon,
    Color? accent,
  }) {
    final Color cardAccent = accent ?? const Color(0xFFE6C86E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardAccent.withOpacity(0.30)),
        color: cardAccent.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: cardAccent),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: cardAccent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskOverviewGrid({
    required Map<String, dynamic> risk,
    required Map<String, dynamic> gate,
    required Map<String, dynamic> latest,
    required Map<String, dynamic> execution,
    required Color symbolColor,
  }) {
    final limits = risk['limits'] as Map<String, dynamic>? ?? {};

    final riskLevel = '${risk['risk_level'] ?? '-'}';
    final gateLevel = '${gate['gate_level'] ?? '-'}';
    final allowEntries = _shortBool(risk['allow_new_entries']);
    final effectiveMultiplier =
        latest['effective_risk_multiplier']?.toString() ?? '-';
    final dailyPnl = _toDouble(risk['daily_pnl']);
    final dailyTrades = _compactNumber(risk['daily_trades'], fractionDigits: 0);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _topStatCard(
          title: 'Risk Level',
          value: riskLevel,
          icon: Icons.shield_outlined,
          accent: _statusColor(riskLevel),
        ),
        _topStatCard(
          title: 'Gate',
          value: gateLevel,
          icon: Icons.traffic_outlined,
          accent: _statusColor(gateLevel),
        ),
        _topStatCard(
          title: 'Entries',
          value: allowEntries,
          icon: Icons.login_outlined,
          accent: _statusColor(allowEntries),
        ),
        _topStatCard(
          title: 'Eff. Multiplier',
          value: effectiveMultiplier,
          icon: Icons.tune_outlined,
          accent: symbolColor,
        ),
        _topStatCard(
          title: 'Daily PnL',
          value: _compactNumber(risk['daily_pnl']),
          icon: Icons.attach_money,
          accent: dailyPnl >= 0 ? Colors.greenAccent : Colors.redAccent,
        ),
        _topStatCard(
          title: 'Daily Trades',
          value: dailyTrades,
          icon: Icons.swap_horiz,
          accent: symbolColor,
        ),
        _topStatCard(
          title: 'Loss Cap USD',
          value: _compactNumber(limits['daily_loss_cap_usd']),
          icon: Icons.money_off_csred_outlined,
          accent: Colors.orangeAccent,
        ),
        _topStatCard(
          title: 'Exec Priority',
          value: '${execution['priority'] ?? '-'}',
          icon: Icons.priority_high,
          accent: Colors.amberAccent,
        ),
      ],
    );
  }

  Widget _riskChart(Map<String, dynamic> risk, Color accent) {
    final limits = risk['limits'] as Map<String, dynamic>? ?? {};

    final dailyPnl = _toDouble(risk['daily_pnl']).abs();
    final dailyR = _toDouble(risk['daily_r']).abs();
    final dailyTrades = _toDouble(risk['daily_trades']);
    final lossCap = _toDouble(limits['daily_loss_cap_usd']);

    final maxY =
        [dailyPnl, dailyR, dailyTrades, lossCap].reduce((a, b) => a > b ? a : b) +
        10;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY <= 0 ? 10 : maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['PnL', 'R', 'Trades', 'LossCap'];
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[i],
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: dailyPnl,
                        color: accent,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: dailyR,
                        color: Colors.orangeAccent,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: dailyTrades,
                        color: Colors.lightBlueAccent,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: lossCap,
                        color: Colors.redAccent,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _riskHeaderCard(BuildContext context) {
    final isMobile = _isMobileWidth(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Risk Overview',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Risk Calculator',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMobile
                  ? 'Estimate risk per trade and monitor live limits in a mobile-friendly view.'
                  : 'Estimate risk per trade and simple position sizing based on account size, risk percentage and stop loss distance.',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inputs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _accountSizeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Account Size'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _riskPctController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Risk %'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stopLossController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Stop Loss Distance',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _calculateRisk,
                child: const Text('Calculate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Result',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _resultRow('Risk per trade', _riskPerTrade, strong: true),
            _resultRow('Position size', _positionSize),
            _resultRow('Mode', _mode),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveCalculatorSection(BuildContext context) {
    final isMobile = _isMobileWidth(context);

    if (isMobile) {
      return Column(
        children: [
          _riskInputCard(),
          const SizedBox(height: 16),
          _riskResultCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _riskInputCard()),
        const SizedBox(width: 16),
        Expanded(child: _riskResultCard()),
      ],
    );
  }

  Widget _riskLoadingCard(String symbol) {
    final accent = _symbolColor(symbol);

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ExpansionTile(
            initiallyExpanded: _expanded[symbol] ?? false,
            onExpansionChanged: (value) {
              setState(() {
                _expanded[symbol] = value;
              });
            },
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 12),
            title: Text(
              '${_symbolLabel(symbol)} Risk Engine',
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Loading',
              style: TextStyle(color: Colors.white70),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _riskErrorCard(String symbol, Object? error) {
    final accent = _symbolColor(symbol);

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ExpansionTile(
            initiallyExpanded: _expanded[symbol] ?? false,
            onExpansionChanged: (value) {
              setState(() {
                _expanded[symbol] = value;
              });
            },
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 12),
            title: Text(
              '${_symbolLabel(symbol)} Risk Engine',
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Risk data unavailable',
              style: TextStyle(color: Colors.redAccent),
            ),
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'API/Backend error',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                error?.toString() ?? 'Unknown API error',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _riskStatusCard({
    required BuildContext context,
    required String symbol,
    required AsyncSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final accent = _symbolColor(symbol);

    if (snapshot.connectionState == ConnectionState.waiting) {
      return _riskLoadingCard(symbol);
    }

    if (snapshot.hasError || !snapshot.hasData) {
      return _riskErrorCard(symbol, snapshot.error);
    }

    final data = snapshot.data!;
    final riskRoot = data['riskEngine'] as Map<String, dynamic>? ?? {};
    final risk = riskRoot['risk_engine'] as Map<String, dynamic>? ?? {};
    final gate = data['gateCombo'] as Map<String, dynamic>? ?? {};
    final latest = data['latest'] as Map<String, dynamic>? ?? {};
    final execution = latest['execution_engine'] as Map<String, dynamic>? ?? {};
    final limits = risk['limits'] as Map<String, dynamic>? ?? {};

    final riskLevel = '${risk['risk_level'] ?? '-'}';
    final gateLevel = '${gate['gate_level'] ?? '-'}';
    final entries = _shortBool(risk['allow_new_entries']);
    final reasons = (risk['reasons'] as List?)?.map((e) => e.toString()).join(', ') ?? '-';
    final signalState = latest['has_signal'] == true
        ? 'PENDING'
        : latest['blocked'] == true
            ? 'BLOCKED'
            : 'NONE';

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ExpansionTile(
            initiallyExpanded: _expanded[symbol] ?? false,
            onExpansionChanged: (value) {
              setState(() {
                _expanded[symbol] = value;
              });
            },
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 12),
            title: Text(
              '${_symbolLabel(symbol)} Risk Engine',
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryChip('Risk $riskLevel', accent: _statusColor(riskLevel)),
                  _summaryChip('Gate $gateLevel', accent: _statusColor(gateLevel)),
                  _summaryChip('Entries $entries', accent: _statusColor(entries)),
                  _summaryChip('Signal $signalState'),
                ],
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Top Risk KPIs',
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _riskOverviewGrid(
                risk: risk,
                gate: gate,
                latest: latest,
                execution: execution,
                symbolColor: accent,
              ),
              const SizedBox(height: 18),
              _riskChart(risk, accent),
              const SizedBox(height: 14),
              _resultRow(
                'Risk Level',
                '${risk['risk_level'] ?? '-'}',
                strong: true,
              ),
              _resultRow(
                'Allow New Entries',
                '${risk['allow_new_entries'] ?? '-'}',
              ),
              _resultRow('Daily PnL', '${risk['daily_pnl'] ?? '-'}'),
              _resultRow('Daily R', '${risk['daily_r'] ?? '-'}'),
              _resultRow('Daily Trades', '${risk['daily_trades'] ?? '-'}'),
              _resultRow(
                'Daily Loss Cap USD',
                '${limits['daily_loss_cap_usd'] ?? '-'}',
              ),
              _resultRow(
                'Daily R Cap',
                '${limits['daily_r_cap'] ?? '-'}',
              ),
              _resultRow(
                'Daily Max Trades',
                '${limits['daily_max_trades'] ?? '-'}',
              ),
              _resultRow('Risk Reasons', reasons),
              const Divider(height: 24),
              _resultRow('Gate Level', '${gate['gate_level'] ?? '-'}'),
              _resultRow('Gate Multiplier', '${gate['risk_multiplier'] ?? '-'}'),
              _resultRow('Execution Priority', '${execution['priority'] ?? '-'}'),
              _resultRow('Execution Mode', '${execution['mode'] ?? '-'}'),
              _resultRow(
                'Execution Multiplier',
                '${execution['risk_multiplier'] ?? '-'}',
              ),
              _resultRow(
                'Signal State',
                signalState,
              ),
              _resultRow(
                'Signal Updated',
                _formatIsoShort(
                  (latest['signal'] as Map<String, dynamic>?)?['updated_utc'],
                ),
              ),
              _resultRow(
                'Effective Risk Multiplier',
                '${latest['effective_risk_multiplier'] ?? '-'}',
                strong: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbols = _futures.keys.toList();

    return RefreshIndicator(
      onRefresh: refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _riskHeaderCard(context),
          const SizedBox(height: 16),
          _buildResponsiveCalculatorSection(context),
          const SizedBox(height: 16),
          if (symbols.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No symbols configured for this account',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          for (final symbol in symbols) ...[
            FutureBuilder<Map<String, dynamic>>(
              future: _futures[symbol],
              builder: (context, snapshot) => _riskStatusCard(
                context: context,
                symbol: symbol,
                snapshot: snapshot,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}