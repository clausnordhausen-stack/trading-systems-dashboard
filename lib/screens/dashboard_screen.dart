import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_session.dart';
import '../service/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _refreshPrefKey = 'dashboard_refresh_seconds';

  final ApiService _api = ApiService();

  Map<String, Future<Map<String, dynamic>>> _futures = {};
  final Map<String, bool> _expanded = {};

  Timer? _timer;
  DateTime? _lastRefresh;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _initRefreshSettings();
    AppSession.selectedAccount.addListener(_accountChanged);
    AppSession.refreshSeconds.addListener(_refreshChanged);
    AppSession.settingsVersion.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    if (!mounted) return;
    _startTimer();
    setState(() {});
  }

  void _settingsChanged() {
    if (!mounted) return;
    setState(_load);
  }

  Future<void> _initRefreshSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getInt(_refreshPrefKey);

    if (!mounted) return;

    if (savedValue != null && AppSession.refreshOptions.contains(savedValue)) {
      AppSession.setRefreshSeconds(savedValue);
    }

    setState(() {
      _settingsLoaded = true;
    });

    _startTimer();
  }

  Future<void> _saveRefreshSettings(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_refreshPrefKey, seconds);
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
    _lastRefresh = DateTime.now();

    _futures = {
      for (final symbol in symbols)
        symbol: _api.fetchOverviewBundle(
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

  Future<void> _updateRefreshInterval(int value) async {
    AppSession.setRefreshSeconds(value);
    await _saveRefreshSettings(value);
    if (!mounted) return;
    setState(() {});
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

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _shortBool(dynamic value) {
    if (value == true) return 'YES';
    if (value == false) return 'NO';
    return '-';
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
    if (v == 'NONE' || v == 'NO SIGNAL') {
      return Colors.white70;
    }
    return Colors.lightBlueAccent;
  }

  String _debugSignalState(Map<String, dynamic> latest) {
    final hasSignal = latest['has_signal'] == true;
    final blocked = latest['blocked'] == true;

    if (hasSignal) return 'PENDING';
    if (blocked) return 'BLOCKED';
    return 'NONE';
  }

  Color _debugSignalStateColor(Map<String, dynamic> latest) {
    final state = _debugSignalState(latest);
    if (state == 'PENDING') return Colors.lightBlueAccent;
    if (state == 'BLOCKED') return Colors.redAccent;
    return Colors.white70;
  }

  String _debugReason(Map<String, dynamic> latest) {
    return latest['reason']?.toString() ??
        (latest['filter'] as Map<String, dynamic>?)?['reason']?.toString() ??
        '-';
  }

  String _signalUpdatedUtc(Map<String, dynamic> latest) {
    final signal = latest['signal'] as Map<String, dynamic>?;
    return signal?['updated_utc']?.toString() ?? '-';
  }

  String _signalCreatedUtc(Map<String, dynamic> latest) {
    final signal = latest['signal'] as Map<String, dynamic>?;
    return signal?['created_utc']?.toString() ?? '-';
  }

  Widget _pill(String label, String value, {Color? accent}) {
    final color = accent ?? _statusColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.28)),
        color: color.withOpacity(0.08),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool emphasize = false}) {
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
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                fontSize: emphasize ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _signalCard(Map<String, dynamic> latest, Color accent) {
    final signal = latest['signal'] as Map<String, dynamic>?;
    final filter = latest['filter'] as Map<String, dynamic>? ?? {};
    final payload = signal?['payload'] as Map<String, dynamic>? ?? {};

    final side = signal?['side']?.toString() ?? '-';
    final score =
        payload['score']?.toString() ?? filter['score']?.toString() ?? '-';
    final approved = filter['approved']?.toString() ?? '-';
    final reason = filter['reason']?.toString() ?? latest['reason']?.toString() ?? '-';
    final created = _formatIsoShort(_signalCreatedUtc(latest));
    final updated = _formatIsoShort(_signalUpdatedUtc(latest));

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Signal Card', color: accent),
              _metricRow('Signal State', _debugSignalState(latest), emphasize: true),
              _metricRow('Has Signal', '${latest['has_signal'] ?? false}'),
              _metricRow('Blocked', '${latest['blocked'] ?? false}'),
              _metricRow('Side', side, emphasize: side != '-'),
              _metricRow('Score', score),
              _metricRow('Approved', approved),
              _metricRow('Reason', reason),
              _metricRow('Created', created),
              _metricRow('Updated', updated),
            ],
          ),
        ),
      ),
    );
  }

  Widget _executionCard(
    Map<String, dynamic> latest,
    Map<String, dynamic> gate,
    Color accent,
  ) {
    final execution = latest['execution_engine'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Execution Card', color: accent),
              _metricRow('Priority', '${execution['priority'] ?? '-'}'),
              _metricRow('Mode', '${execution['mode'] ?? '-'}'),
              _metricRow(
                'Execution Multiplier',
                '${execution['risk_multiplier'] ?? '-'}',
              ),
              _metricRow('Gate Multiplier', '${gate['risk_multiplier'] ?? '-'}'),
              _metricRow(
                'Effective Multiplier',
                '${latest['effective_risk_multiplier'] ?? gate['risk_multiplier'] ?? '-'}',
                emphasize: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugCard(
    Map<String, dynamic> latest,
    Map<String, dynamic> heartbeat,
    Color accent,
  ) {
    final signal = latest['signal'] as Map<String, dynamic>?;
    final hbItems = (heartbeat['items'] as List?) ?? [];
    final connectedCount = heartbeat['connected_count'];
    final state = _debugSignalState(latest);
    final stateColor = _debugSignalStateColor(latest);
    final reason = _debugReason(latest);
    final latestSide = signal?['side']?.toString() ?? '-';
    final latestUpdated = _formatIsoShort(_signalUpdatedUtc(latest));
    final latestCreated = _formatIsoShort(_signalCreatedUtc(latest));

    final consumerInfo = hbItems.isNotEmpty
        ? '${hbItems.length} consumer(s)'
        : (connectedCount is num && connectedCount > 0)
            ? '$connectedCount consumer(s)'
            : '0 consumer';

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Debug Signal Monitor', color: accent),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('Signal State', state, accent: stateColor),
                  _pill('Consumers', consumerInfo, accent: accent),
                  _pill(
                    'Heartbeat',
                    (hbItems.isNotEmpty ||
                            (connectedCount is num && connectedCount > 0))
                        ? 'ONLINE'
                        : 'OFFLINE',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _metricRow('Latest Side', latestSide),
              _metricRow('Reason', reason),
              _metricRow('Created', latestCreated),
              _metricRow('Updated', latestUpdated),
              _metricRow(
                'Consumer Count',
                connectedCount?.toString() ?? '${hbItems.length}',
              ),
              if (hbItems.isNotEmpty) ...[
                const Divider(height: 24),
                _sectionTitle('Connected Consumers'),
                for (final item in hbItems.take(4))
                  _metricRow(
                    '${item['account'] ?? '-'} / ${item['magic'] ?? '-'}',
                    '${item['ea_name'] ?? 'EA'} | ${item['connected'] == true ? 'ONLINE' : 'OFFLINE'}',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiChart(Map<String, dynamic> kpis, Color accent) {
    final trades = _toDouble(kpis['total_trades']);
    final winrate = _toDouble(kpis['winrate_pct']);
    final pnl = _toDouble(kpis['net_pnl']).abs();
    final pf = _toDouble(kpis['profit_factor']);

    final maxY =
        [trades, winrate, pnl, pf].reduce((a, b) => a > b ? a : b) + 10;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('KPI Snapshot', color: accent),
              SizedBox(
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
                            const labels = ['Trades', 'Win%', 'PnL', 'PF'];
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
                            toY: trades,
                            color: accent,
                            borderRadius: BorderRadius.circular(6),
                            width: 18,
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: winrate,
                            color: Colors.orangeAccent,
                            borderRadius: BorderRadius.circular(6),
                            width: 18,
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: pnl,
                            color: Colors.greenAccent,
                            borderRadius: BorderRadius.circular(6),
                            width: 18,
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 3,
                        barRods: [
                          BarChartRodData(
                            toY: pf,
                            color: Colors.lightBlueAccent,
                            borderRadius: BorderRadius.circular(6),
                            width: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  Widget _overviewStatsGrid({
    required Map<String, dynamic> system,
    required Map<String, dynamic> latest,
    required Map<String, dynamic> gateCombo,
    required Map<String, dynamic> risk,
    required Map<String, dynamic> heartbeat,
    required Color symbolColor,
  }) {
    final kpis = system['kpis'] as Map<String, dynamic>? ?? {};
    final hbItems = (heartbeat['items'] as List?) ?? [];
    final signal = latest['signal'] as Map<String, dynamic>? ?? {};
    final filter = latest['filter'] as Map<String, dynamic>? ?? {};

    final gateLevel = '${gateCombo['gate_level'] ?? '-'}';
    final riskLevel = '${risk['risk_level'] ?? '-'}';
    final heartbeatState =
        hbItems.isNotEmpty || (heartbeat['connected_count'] ?? 0) != 0
            ? 'ONLINE'
            : 'OFFLINE';

    final signalSide = signal['side']?.toString() ?? '-';
    final signalScore =
        signal['payload']?['score']?.toString() ??
            filter['score']?.toString() ??
            '-';

    final signalState = _debugSignalState(latest);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _topStatCard(
          title: 'Gate',
          value: gateLevel,
          icon: Icons.traffic_outlined,
          accent: _statusColor(gateLevel),
        ),
        _topStatCard(
          title: 'Risk',
          value: riskLevel,
          icon: Icons.shield_outlined,
          accent: _statusColor(riskLevel),
        ),
        _topStatCard(
          title: 'Heartbeat',
          value: heartbeatState,
          icon: Icons.favorite_border,
          accent: _statusColor(heartbeatState),
        ),
        _topStatCard(
          title: 'Signal',
          value: signalSide,
          icon: Icons.show_chart,
          accent: signalSide == '-' ? symbolColor : Colors.lightBlueAccent,
        ),
        _topStatCard(
          title: 'Signal State',
          value: signalState,
          icon: Icons.bug_report_outlined,
          accent: _debugSignalStateColor(latest),
        ),
        _topStatCard(
          title: 'PnL',
          value: _compactNumber(kpis['net_pnl']),
          icon: Icons.attach_money,
          accent: _toDouble(kpis['net_pnl']) >= 0
              ? Colors.greenAccent
              : Colors.redAccent,
        ),
        _topStatCard(
          title: 'Trades',
          value: _compactNumber(kpis['total_trades'], fractionDigits: 0),
          icon: Icons.swap_horiz,
          accent: symbolColor,
        ),
        _topStatCard(
          title: 'Score',
          value: signalScore,
          icon: Icons.analytics_outlined,
          accent: Colors.lightBlueAccent,
        ),
      ],
    );
  }

  Widget _symbolLoadingCard(String symbol) {
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
              '${_symbolLabel(symbol)} Overview',
              style: TextStyle(
                color: accent,
                fontSize: 20,
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

  Widget _symbolErrorCard(String symbol, Object? error) {
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
              '${_symbolLabel(symbol)} Overview',
              style: TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Data unavailable',
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

  Widget _buildResponsiveSection({
    required BuildContext context,
    required Widget left,
    required Widget right,
  }) {
    final isMobile = _isMobileWidth(context);

    if (isMobile) {
      return Column(
        children: [
          left,
          const SizedBox(height: 14),
          right,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildSymbolCard({
    required BuildContext context,
    required String symbol,
    required AsyncSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final accent = _symbolColor(symbol);

    if (snapshot.connectionState == ConnectionState.waiting) {
      return _symbolLoadingCard(symbol);
    }

    if (snapshot.hasError || !snapshot.hasData) {
      return _symbolErrorCard(symbol, snapshot.error);
    }

    final data = snapshot.data!;
    final system = data['systemOverview'] as Map<String, dynamic>? ?? {};
    final latest = data['latest'] as Map<String, dynamic>? ?? {};
    final gateCombo = data['gateCombo'] as Map<String, dynamic>? ?? {};
    final riskRoot = data['riskEngine'] as Map<String, dynamic>? ?? {};
    final risk = riskRoot['risk_engine'] as Map<String, dynamic>? ?? {};
    final heartbeat = data['heartbeat'] as Map<String, dynamic>? ?? {};

    final kpis = system['kpis'] as Map<String, dynamic>? ?? {};
    final hbItems = (heartbeat['items'] as List?) ?? [];
    final latestSignal = latest['signal'] as Map<String, dynamic>?;
    final latestPayload = latestSignal?['payload'] as Map<String, dynamic>?;
    final filter = latest['filter'] as Map<String, dynamic>? ?? {};

    final latestSide = latestSignal?['side']?.toString() ?? '-';
    final latestScore =
        latestPayload?['score']?.toString() ?? filter['score']?.toString() ?? '-';
    final effectiveMultiplier =
        latest['effective_risk_multiplier']?.toString() ??
            gateCombo['risk_multiplier']?.toString() ??
            '-';

    final gateLevel = '${gateCombo['gate_level'] ?? '-'}';
    final riskLevel = '${risk['risk_level'] ?? '-'}';
    final heartbeatState = hbItems.isNotEmpty ||
            ((heartbeat['connected_count'] is num) &&
                (heartbeat['connected_count'] as num) > 0)
        ? 'ONLINE'
        : 'OFFLINE';

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
              '${_symbolLabel(symbol)} Overview',
              style: TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('Gate', gateLevel),
                  _pill('Risk', riskLevel),
                  _pill('Heartbeat', heartbeatState),
                  _pill(
                    'Signal State',
                    _debugSignalState(latest),
                    accent: _debugSignalStateColor(latest),
                  ),
                ],
              ),
            ),
            children: [
              _sectionTitle('Top KPIs', color: accent),
              _overviewStatsGrid(
                system: system,
                latest: latest,
                gateCombo: gateCombo,
                risk: risk,
                heartbeat: heartbeat,
                symbolColor: accent,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _pill(
                    'Entries',
                    _shortBool(gateCombo['allow_new_entries']),
                    accent: accent,
                  ),
                  _pill('Approved', _shortBool(filter['approved'])),
                  _pill(
                    'Trades',
                    '${kpis['total_trades'] ?? 0}',
                    accent: accent,
                  ),
                  _pill(
                    'Winrate',
                    '${kpis['winrate_pct'] ?? 0}%',
                    accent: Colors.orangeAccent,
                  ),
                  _pill(
                    'PnL',
                    '${kpis['net_pnl'] ?? 0}',
                    accent: _toDouble(kpis['net_pnl']) >= 0
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _kpiChart(kpis, accent),
              const SizedBox(height: 14),
              _buildResponsiveSection(
                context: context,
                left: _signalCard(latest, accent),
                right: _executionCard(latest, gateCombo, accent),
              ),
              const SizedBox(height: 14),
              _debugCard(latest, heartbeat, accent),
              const SizedBox(height: 14),
              _sectionTitle('System', color: accent),
              _metricRow('Connected EAs', '${heartbeat['connected_count'] ?? 0}'),
              _metricRow(
                'Latest Signal Side',
                latestSide,
                emphasize: latestSide != '-',
              ),
              _metricRow('Latest Signal Score', latestScore),
              _metricRow(
                'Signal Created',
                _formatIsoShort(_signalCreatedUtc(latest)),
              ),
              _metricRow(
                'Signal Updated',
                _formatIsoShort(_signalUpdatedUtc(latest)),
              ),
              _metricRow('Signal Reason', _debugReason(latest)),
              _metricRow('Daily Trades', '${risk['daily_trades'] ?? '-'}'),
              _metricRow('Daily PnL', '${risk['daily_pnl'] ?? '-'}'),
              _metricRow(
                'Allow New Entries',
                _shortBool(risk['allow_new_entries']),
              ),
              _metricRow('Server Time', '${system['server_time_utc'] ?? '-'}'),
              _metricRow(
                'Effective Risk Multiplier',
                effectiveMultiplier,
                emphasize: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewHeaderCard(String refreshed) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 760;

            final left = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Monitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Responsive overview with live signal debug visibility.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Auto-refresh',
                        style: TextStyle(color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: ValueListenableBuilder<int>(
                            valueListenable: AppSession.refreshSeconds,
                            builder: (context, refreshSeconds, child) {
                              return DropdownButton<int>(
                                value: refreshSeconds,
                                dropdownColor:
                                    Theme.of(context).colorScheme.surface,
                                style: const TextStyle(color: Colors.white),
                                items: AppSession.refreshOptions.map((seconds) {
                                  return DropdownMenuItem<int>(
                                    value: seconds,
                                    child: Text(
                                      '$seconds s',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                                onChanged: !_settingsLoaded
                                    ? null
                                    : (value) async {
                                        if (value == null) return;
                                        await _updateRefreshInterval(value);
                                      },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final right = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: AppSession.selectedAccount,
                  builder: (context, account, child) {
                    return Chip(
                      label: Text(AppSession.labelForAccount(account)),
                    );
                  },
                ),
                Chip(label: Text('Refreshed: $refreshed')),
              ],
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  left,
                  const SizedBox(height: 12),
                  right,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(width: 8),
                right,
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final refreshed = _lastRefresh == null
        ? '-'
        : '${_lastRefresh!.hour.toString().padLeft(2, '0')}:'
            '${_lastRefresh!.minute.toString().padLeft(2, '0')}:'
            '${_lastRefresh!.second.toString().padLeft(2, '0')}';

    final symbols = _futures.keys.toList();

    return RefreshIndicator(
      onRefresh: refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _overviewHeaderCard(refreshed),
          const SizedBox(height: 16),
          if (symbols.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No symbols configured for this account',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          for (final symbol in symbols) ...[
            FutureBuilder<Map<String, dynamic>>(
              future: _futures[symbol],
              builder: (context, snapshot) => _buildSymbolCard(
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