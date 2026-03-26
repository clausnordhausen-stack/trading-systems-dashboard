import 'dart:async';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../service/api_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService api = ApiService();

  bool loading = true;
  String? errorMessage;

  Map<String, dynamic>? dashboardData;
  Timer? refreshTimer;
  DateTime? lastRefreshTime;

  @override
  void initState() {
    super.initState();
    loadAnalysis();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      loadAnalysis(silent: true);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadAnalysis({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final result = await api.getJson(
        '/dashboard?symbols=BTCUSD,XAUUSD&limit_deals=12&limit_risks=12&n_gate=40',
      );

      if (!mounted) return;

      setState(() {
        dashboardData = result;
        lastRefreshTime = DateTime.now();
        loading = false;
        errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Analysis data unavailable';
        loading = false;
      });
    }
  }

  Map<String, dynamic>? asMap(dynamic raw) {
    return api.asMap(raw);
  }

  List<Map<String, dynamic>> asMapList(dynamic raw) {
    return api.asMapList(raw);
  }

  String safeValue(dynamic value) {
    return api.safeValue(value);
  }

  num? toNum(dynamic raw) {
    if (raw is num) return raw;
    return double.tryParse(raw.toString());
  }

  String normalizeLevel(dynamic value) {
    final text = safeValue(value).toUpperCase();
    if (text == 'GREEN' || text == 'YELLOW' || text == 'RED') {
      return text;
    }
    return 'UNKNOWN';
  }

  Color levelColor(String level) {
    switch (level) {
      case 'GREEN':
        return AppColors.green;
      case 'YELLOW':
        return AppColors.yellow;
      case 'RED':
        return AppColors.red;
      default:
        return AppColors.textMuted;
    }
  }

  Color valueColorBySign(num? value) {
    if (value == null) return AppColors.textPrimary;
    if (value > 0) return AppColors.green;
    if (value < 0) return AppColors.red;
    return AppColors.textPrimary;
  }

  String formatMoney(dynamic raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (value == null) return '-';
    final sign = value > 0 ? '+' : '';
    return '$sign\$${value.toStringAsFixed(2)}';
  }

  String formatR(dynamic raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (value == null) return '-';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}R';
  }

  String formatPercent(dynamic raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (value == null) return '-';
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String formatNumber(dynamic raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (value == null) return '-';
    return value.toStringAsFixed(2);
  }

  Widget shellCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget metricRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget statusPill(String level) {
    final color = levelColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Map<String, dynamic>? get portfolio => asMap(dashboardData?['portfolio']);
  Map<String, dynamic>? get portfolioKpis => asMap(portfolio?['kpis']);
  Map<String, dynamic>? get portfolioCombo => asMap(portfolio?['combo']);
  Map<String, dynamic>? get perSymbol => asMap(dashboardData?['per_symbol']);

  Map<String, dynamic>? symbolData(String symbol) {
    return asMap(perSymbol?[symbol]);
  }

  Map<String, dynamic>? symbolKpis(String symbol) {
    return asMap(symbolData(symbol)?['kpis']);
  }

  Map<String, dynamic>? symbolGate(String symbol) {
    return asMap(symbolData(symbol)?['gate_combo']);
  }

  List<Map<String, dynamic>> symbolDeals(String symbol) {
    return asMapList(symbolData(symbol)?['last_deals']);
  }

  List<Map<String, dynamic>> symbolRisks(String symbol) {
    return asMapList(symbolData(symbol)?['last_risks']);
  }

  Widget headerCard() {
    final level = normalizeLevel(portfolioCombo?['portfolio_level']);

    return shellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analysis',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              statusPill(level),
              const SizedBox(width: 10),
              Text(
                lastRefreshTime != null
                    ? 'Last refresh ${lastRefreshTime!.toLocal().toString().substring(11, 19)}'
                    : 'No refresh yet',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Institutional KPI view for portfolio and symbol-level monitoring.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget portfolioKpiCard() {
    final dailyPnl = toNum(portfolioKpis?['daily_pnl']);
    final dailyR = toNum(portfolioKpis?['daily_r']);
    final openRisk = toNum(portfolioKpis?['open_risk_usd']);
    final maxDd = toNum(portfolioKpis?['max_drawdown_usd']);

    return shellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Portfolio KPIs'),
          const SizedBox(height: 14),
          metricRow(
            'Daily PnL',
            formatMoney(portfolioKpis?['daily_pnl']),
            valueColor: valueColorBySign(dailyPnl),
          ),
          metricRow(
            'Daily R',
            formatR(portfolioKpis?['daily_r']),
            valueColor: valueColorBySign(dailyR),
          ),
          metricRow(
            'Open Risk',
            formatMoney(portfolioKpis?['open_risk_usd']),
            valueColor: valueColorBySign(openRisk == null ? null : -openRisk),
          ),
          metricRow(
            'Trades Today',
            safeValue(portfolioKpis?['trade_count_today']),
          ),
          metricRow(
            'Winrate',
            formatPercent(portfolioKpis?['winrate_last_n']),
          ),
          metricRow(
            'Profit Factor',
            formatNumber(portfolioKpis?['profit_factor_last_n']),
          ),
          metricRow(
            'Max Drawdown',
            formatMoney(portfolioKpis?['max_drawdown_usd']),
            valueColor: valueColorBySign(maxDd == null ? null : -maxDd),
          ),
          metricRow(
            'Max Drawdown R',
            formatR(portfolioKpis?['max_drawdown_r']),
          ),
        ],
      ),
    );
  }

  Widget symbolComparisonCard() {
    final xau = symbolKpis('XAUUSD');
    final btc = symbolKpis('BTCUSD');

    return shellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Symbol Comparison'),
          const SizedBox(height: 14),
          comparisonRow(
            'Daily PnL',
            formatMoney(xau?['daily_pnl']),
            formatMoney(btc?['daily_pnl']),
            xauColor: valueColorBySign(toNum(xau?['daily_pnl'])),
            btcColor: valueColorBySign(toNum(btc?['daily_pnl'])),
          ),
          comparisonRow(
            'Daily R',
            formatR(xau?['daily_r']),
            formatR(btc?['daily_r']),
            xauColor: valueColorBySign(toNum(xau?['daily_r'])),
            btcColor: valueColorBySign(toNum(btc?['daily_r'])),
          ),
          comparisonRow(
            'Open Risk',
            formatMoney(xau?['open_risk_usd']),
            formatMoney(btc?['open_risk_usd']),
          ),
          comparisonRow(
            'Trades Today',
            safeValue(xau?['trade_count_today']),
            safeValue(btc?['trade_count_today']),
          ),
          comparisonRow(
            'Winrate',
            formatPercent(xau?['winrate_last_n']),
            formatPercent(btc?['winrate_last_n']),
          ),
          comparisonRow(
            'Profit Factor',
            formatNumber(xau?['profit_factor_last_n']),
            formatNumber(btc?['profit_factor_last_n']),
          ),
        ],
      ),
    );
  }

  Widget comparisonRow(
    String label,
    String xauValue,
    String btcValue, {
    Color? xauColor,
    Color? btcColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              xauValue,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: xauColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              btcValue,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: btcColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget symbolAnalysisCard(String symbol) {
    final kpis = symbolKpis(symbol);
    final gate = symbolGate(symbol);
    final level = normalizeLevel(gate?['combo_level']);

    final dailyPnl = toNum(kpis?['daily_pnl']);
    final dailyR = toNum(kpis?['daily_r']);
    final openRisk = toNum(kpis?['open_risk_usd']);

    return shellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                symbol,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              statusPill(level),
            ],
          ),
          const SizedBox(height: 14),
          metricRow(
            'Daily PnL',
            formatMoney(kpis?['daily_pnl']),
            valueColor: valueColorBySign(dailyPnl),
          ),
          metricRow(
            'Daily R',
            formatR(kpis?['daily_r']),
            valueColor: valueColorBySign(dailyR),
          ),
          metricRow(
            'Rolling PnL',
            formatMoney(kpis?['rolling_pnl_last_n']),
          ),
          metricRow(
            'Rolling R',
            formatR(kpis?['rolling_r_last_n']),
          ),
          metricRow(
            'Open Risk',
            formatMoney(kpis?['open_risk_usd']),
            valueColor: valueColorBySign(openRisk == null ? null : -openRisk),
          ),
          metricRow(
            'Trades Today',
            safeValue(kpis?['trade_count_today']),
          ),
          metricRow(
            'Winrate',
            formatPercent(kpis?['winrate_last_n']),
          ),
          metricRow(
            'Profit Factor',
            formatNumber(kpis?['profit_factor_last_n']),
          ),
          metricRow(
            'Loss Streak',
            safeValue(kpis?['loss_streak_last_n']),
          ),
          metricRow(
            'Max DD USD',
            formatMoney(kpis?['max_drawdown_usd']),
          ),
          metricRow(
            'Max DD R',
            formatR(kpis?['max_drawdown_r']),
          ),
        ],
      ),
    );
  }

  Widget recentTradesCard(String symbol) {
    final deals = symbolDeals(symbol);

    return shellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('$symbol Recent Trades'),
          const SizedBox(height: 12),
          if (deals.isEmpty)
            const Text(
              'No trades recorded',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            )
          else
            Column(
              children: deals.take(5).map((deal) {
                final rMultiple = toNum(deal['r_multiple']);
                final profit = safe_float_for_ui(deal['profit']);
                final commission = safe_float_for_ui(deal['commission']);
                final swap = safe_float_for_ui(deal['swap']);
                final net = profit + commission + swap;

                final resultText = rMultiple != null
                    ? '${rMultiple >= 0 ? '+' : ''}${rMultiple.toStringAsFixed(2)}R'
                    : '${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(2)}';

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          resultText,
                          style: TextStyle(
                            color: net > 0
                                ? AppColors.green
                                : net < 0
                                    ? AppColors.red
                                    : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          safeValue(deal['close_time']),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget recentRisksCard(String symbol) {
    final risks = symbolRisks(symbol);

    return shellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('$symbol Risk Snapshots'),
          const SizedBox(height: 12),
          if (risks.isEmpty)
            const Text(
              'No risk data available',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            )
          else
            Column(
              children: risks.take(5).map((risk) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMoney(risk['risk_usd']),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lots: ${safeValue(risk['lots'])} · Entry: ${safeValue(risk['entry_price'])}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  double safe_float_for_ui(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        color: AppColors.bg,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        color: AppColors.bg,
        child: Center(
          child: shellCard(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.bg,
      child: RefreshIndicator(
        onRefresh: loadAnalysis,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            headerCard(),
            const SizedBox(height: 12),
            portfolioKpiCard(),
            const SizedBox(height: 12),
            symbolComparisonCard(),
            const SizedBox(height: 12),
            symbolAnalysisCard('XAUUSD'),
            const SizedBox(height: 12),
            recentTradesCard('XAUUSD'),
            const SizedBox(height: 12),
            recentRisksCard('XAUUSD'),
            const SizedBox(height: 12),
            symbolAnalysisCard('BTCUSD'),
            const SizedBox(height: 12),
            recentTradesCard('BTCUSD'),
            const SizedBox(height: 12),
            recentRisksCard('BTCUSD'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}