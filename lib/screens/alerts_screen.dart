import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_session.dart';
import '../service/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ApiService _api = ApiService();

  late Future<List<_SymbolAlertsGroup>> _future;
  Timer? _timer;
  final Map<String, bool> _expanded = {};

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
    AppSession.selectedAccount.removeListener(_accountChanged);
    AppSession.refreshSeconds.removeListener(_refreshChanged);
    AppSession.settingsVersion.removeListener(_settingsChanged);
    super.dispose();
  }

  void _accountChanged() {
    if (mounted) {
      setState(_load);
    }
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
      (_) {
        if (mounted) {
          setState(_load);
        }
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
    _future = _collectAlerts();
  }

  Future<void> refreshData() async {
    setState(_load);
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

  Color _levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return Colors.redAccent;
      case 'WARNING':
        return Colors.orangeAccent;
      case 'INFO':
        return Colors.lightBlueAccent;
      case 'OK':
        return Colors.greenAccent;
      case 'ERROR':
        return Colors.redAccent;
      default:
        return const Color(0xFFE6C86E);
    }
  }

  IconData _levelIcon(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return Icons.error_outline_rounded;
      case 'WARNING':
        return Icons.warning_amber_rounded;
      case 'INFO':
        return Icons.info_outline_rounded;
      case 'OK':
        return Icons.check_circle_outline_rounded;
      case 'ERROR':
        return Icons.cloud_off_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Widget _summaryChip(String label, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (accent ?? Colors.white12).withOpacity(0.35),
        ),
        color: accent == null ? null : accent.withOpacity(0.06),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: accent ?? Colors.white,
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
    final cardAccent = accent ?? const Color(0xFFE6C86E);

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

  Widget _alertsOverviewGrid(_SymbolAlertsGroup group, Color symbolColor) {
    final alertItems = group.items
        .where((item) => item.kind == _FeedItemKind.alert)
        .toList();

    final criticalCount =
        alertItems.where((item) => item.level == 'CRITICAL').length;
    final warningCount =
        alertItems.where((item) => item.level == 'WARNING').length;
    final infoCount = alertItems.where((item) => item.level == 'INFO').length;

    final overallStatus = switch (group.status) {
      _SymbolGroupStatus.error => 'ERROR',
      _SymbolGroupStatus.empty => 'OK',
      _SymbolGroupStatus.alerts =>
        criticalCount > 0
            ? 'CRITICAL'
            : warningCount > 0
                ? 'WARNING'
                : infoCount > 0
                    ? 'INFO'
                    : 'OK',
    };

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _topStatCard(
          title: 'Status',
          value: overallStatus,
          icon: _levelIcon(overallStatus),
          accent: _levelColor(overallStatus),
        ),
        _topStatCard(
          title: 'Total Alerts',
          value: '${alertItems.length}',
          icon: Icons.notifications_active_outlined,
          accent: alertItems.isEmpty ? Colors.greenAccent : symbolColor,
        ),
        _topStatCard(
          title: 'Critical',
          value: '$criticalCount',
          icon: Icons.error_outline_rounded,
          accent: criticalCount > 0 ? Colors.redAccent : Colors.white54,
        ),
        _topStatCard(
          title: 'Warning',
          value: '$warningCount',
          icon: Icons.warning_amber_rounded,
          accent: warningCount > 0 ? Colors.orangeAccent : Colors.white54,
        ),
        _topStatCard(
          title: 'Info',
          value: '$infoCount',
          icon: Icons.info_outline_rounded,
          accent: infoCount > 0 ? Colors.lightBlueAccent : Colors.white54,
        ),
        _topStatCard(
          title: 'Backend',
          value: group.status == _SymbolGroupStatus.error ? 'ERROR' : 'OK',
          icon: group.status == _SymbolGroupStatus.error
              ? Icons.cloud_off_rounded
              : Icons.cloud_done_outlined,
          accent: group.status == _SymbolGroupStatus.error
              ? Colors.redAccent
              : symbolColor,
        ),
      ],
    );
  }

  Future<List<_SymbolAlertsGroup>> _collectAlerts() async {
    final account = AppSession.selectedAccount.value;
    final symbols = AppSession.trackedSymbolsForSelectedAccount;

    _syncExpandedState(symbols);

    final results = await Future.wait<_SymbolAlertResult>(
      symbols.map((symbol) async {
        try {
          final data = await _api.fetchAlertsBundle(
            symbol: symbol,
            account: account,
            magic: AppSession.magicFor(
              account: account,
              symbol: symbol,
            ),
          );

          return _SymbolAlertResult(
            symbol: symbol,
            data: data,
          );
        } catch (e) {
          return _SymbolAlertResult(
            symbol: symbol,
            errorMessage: e.toString(),
          );
        }
      }),
    );

    final groups = <_SymbolAlertsGroup>[];
    int activeAlertCount = 0;

    for (final result in results) {
      if (result.hasError) {
        groups.add(
          _SymbolAlertsGroup(
            symbol: result.symbol,
            status: _SymbolGroupStatus.error,
            items: [
              _AlertFeedItem.error(
                symbol: result.symbol,
                title: '${_symbolLabel(result.symbol)} data unavailable',
                message: result.errorMessage ?? 'Unknown API error',
              ),
            ],
          ),
        );
        continue;
      }

      final alerts = _buildAlertsForSymbol(result.symbol, result.data!);
      activeAlertCount += alerts.length;

      if (alerts.isEmpty) {
        groups.add(
          _SymbolAlertsGroup(
            symbol: result.symbol,
            status: _SymbolGroupStatus.empty,
            items: [
              _AlertFeedItem.empty(
                symbol: result.symbol,
                title: '${_symbolLabel(result.symbol)} no active alerts',
                message: 'No active alerts for this symbol.',
              ),
            ],
          ),
        );
      } else {
        groups.add(
          _SymbolAlertsGroup(
            symbol: result.symbol,
            status: _SymbolGroupStatus.alerts,
            items: alerts
                .map(
                  (alert) => _AlertFeedItem.alert(
                    symbol: result.symbol,
                    level: alert['level'] ?? 'INFO',
                    title: alert['title'] ?? '-',
                    message: alert['message'] ?? '-',
                  ),
                )
                .toList(),
          ),
        );
      }
    }

    AppSession.alertCount.value = activeAlertCount;
    return groups;
  }

  List<Map<String, String>> _buildAlertsForSymbol(
    String symbol,
    Map<String, dynamic> data,
  ) {
    final alerts = <Map<String, String>>[];
    final symbolLabel = _symbolLabel(symbol);

    final gate = data['gateCombo'] as Map<String, dynamic>? ?? {};
    final riskRoot = data['riskEngine'] as Map<String, dynamic>? ?? {};
    final risk = riskRoot['risk_engine'] as Map<String, dynamic>? ?? {};
    final heartbeat = data['heartbeat'] as Map<String, dynamic>? ?? {};
    final latest = data['latest'] as Map<String, dynamic>? ?? {};
    final filter = latest['filter'] as Map<String, dynamic>? ?? {};
    final debugState = data['debugState'] as Map<String, dynamic>? ?? {};
    final recentAcks = data['recentAcks'] as Map<String, dynamic>? ?? {};

    final hbItems = (heartbeat['items'] as List?) ?? [];
    final connectedCount = heartbeat['connected_count'];

    if (hbItems.isEmpty && !(connectedCount is num && connectedCount > 0)) {
      alerts.add({
        'level': 'CRITICAL',
        'title': '$symbolLabel heartbeat offline',
        'message': 'No connected heartbeat detected.',
      });
    }

    final gateLevel = (gate['gate_level'] ?? '').toString().toUpperCase();

    if (gateLevel == 'RED') {
      alerts.add({
        'level': 'CRITICAL',
        'title': '$symbolLabel gate RED',
        'message': 'Combined gate is blocking new entries.',
      });
    } else if (gateLevel == 'YELLOW') {
      alerts.add({
        'level': 'WARNING',
        'title': '$symbolLabel gate YELLOW',
        'message': 'Trading allowed with reduced risk.',
      });
    }

    if ((risk['allow_new_entries'] ?? true) == false) {
      final reasons = (risk['reasons'] as List?)
          ?.map((e) => e.toString())
          .join(', ');

      alerts.add({
        'level': 'CRITICAL',
        'title': '$symbolLabel risk engine blocked',
        'message': reasons?.isNotEmpty == true ? reasons! : 'Risk limit hit',
      });
    }

    if ((latest['blocked'] ?? false) == true) {
      alerts.add({
        'level': 'WARNING',
        'title': '$symbolLabel signal blocked',
        'message':
            '${latest['reason'] ?? filter['reason'] ?? 'Signal filtered'}',
      });
    }

    if ((latest['has_signal'] ?? false) == true) {
      final signal = latest['signal'] as Map<String, dynamic>? ?? {};
      alerts.add({
        'level': 'INFO',
        'title': '$symbolLabel signal available',
        'message': 'Side=${signal['side'] ?? '-'}',
      });
    }

    if (debugState['debug_available'] == true) {
      final pendingCount = debugState['pending_count'];
      if (pendingCount is num && pendingCount > 0) {
        alerts.add({
          'level': 'INFO',
          'title': '$symbolLabel pending signals in backend',
          'message': 'Pending count=$pendingCount',
        });
      }
    }

    if (recentAcks['debug_available'] == true) {
      final items = (recentAcks['items'] as List?) ?? [];
      if (items.isNotEmpty) {
        alerts.add({
          'level': 'INFO',
          'title': '$symbolLabel recent ACK activity',
          'message': 'Recent ACK entries=${items.length}',
        });
      }
    }

    return alerts;
  }

  Widget _buildFeedCard(_AlertFeedItem item, Color symbolColor) {
    final color =
        item.kind == _FeedItemKind.alert ? _levelColor(item.level) : symbolColor;

    if (item.kind == _FeedItemKind.empty) {
      return Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: symbolColor.withOpacity(0.20)),
          ),
          child: ListTile(
            leading: Icon(Icons.check_circle_outline, color: symbolColor),
            title: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.message,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            trailing: Chip(
              label: Text(
                'OK',
                style: TextStyle(color: symbolColor),
              ),
            ),
          ),
        ),
      );
    }

    if (item.kind == _FeedItemKind.error) {
      return Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.35),
            ),
          ),
          child: ListTile(
            leading:
                const Icon(Icons.cloud_off_rounded, color: Colors.redAccent),
            title: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.message,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            trailing: const Chip(label: Text('ERROR')),
          ),
        ),
      );
    }

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(0.35),
          ),
        ),
        child: ListTile(
          leading: Icon(_levelIcon(item.level), color: color),
          title: Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              item.message,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.level,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolGroup(_SymbolAlertsGroup group) {
    final accent = _symbolColor(group.symbol);
    final hasCritical = group.items.any((item) => item.level == 'CRITICAL');
    final hasWarning = group.items.any((item) => item.level == 'WARNING');

    final statusLabel = switch (group.status) {
      _SymbolGroupStatus.alerts =>
        '${group.items.where((e) => e.kind == _FeedItemKind.alert).length} Alerts',
      _SymbolGroupStatus.empty => 'No Alerts',
      _SymbolGroupStatus.error => 'Error',
    };

    final severityChip = hasCritical
        ? _summaryChip('Critical')
        : hasWarning
            ? _summaryChip('Warning')
            : _summaryChip(
                group.status == _SymbolGroupStatus.error ? 'Error' : 'Stable',
                accent: accent,
              );

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ExpansionTile(
            initiallyExpanded: _expanded[group.symbol] ?? false,
            onExpansionChanged: (value) {
              setState(() {
                _expanded[group.symbol] = value;
              });
            },
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 12),
            title: Text(
              '${_symbolLabel(group.symbol)} Alerts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryChip(statusLabel, accent: accent),
                  severityChip,
                ],
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Alert Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ),
              _alertsOverviewGrid(group, accent),
              const SizedBox(height: 18),
              for (int i = 0; i < group.items.length; i++) ...[
                _buildFeedCard(group.items[i], accent),
                if (i < group.items.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: FutureBuilder<List<_SymbolAlertsGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              children: const [
                SizedBox(height: 280),
                Center(
                  child: Text(
                    'Alerts unavailable',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 280),
                Center(
                  child: Text(
                    'No symbols configured',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildSymbolGroup(groups[index]);
            },
          );
        },
      ),
    );
  }
}

enum _FeedItemKind {
  alert,
  empty,
  error,
}

enum _SymbolGroupStatus {
  alerts,
  empty,
  error,
}

class _AlertFeedItem {
  final _FeedItemKind kind;
  final String symbol;
  final String level;
  final String title;
  final String message;

  const _AlertFeedItem._({
    required this.kind,
    required this.symbol,
    required this.level,
    required this.title,
    required this.message,
  });

  factory _AlertFeedItem.alert({
    required String symbol,
    required String level,
    required String title,
    required String message,
  }) {
    return _AlertFeedItem._(
      kind: _FeedItemKind.alert,
      symbol: symbol,
      level: level,
      title: title,
      message: message,
    );
  }

  factory _AlertFeedItem.empty({
    required String symbol,
    required String title,
    required String message,
  }) {
    return _AlertFeedItem._(
      kind: _FeedItemKind.empty,
      symbol: symbol,
      level: 'OK',
      title: title,
      message: message,
    );
  }

  factory _AlertFeedItem.error({
    required String symbol,
    required String title,
    required String message,
  }) {
    return _AlertFeedItem._(
      kind: _FeedItemKind.error,
      symbol: symbol,
      level: 'ERROR',
      title: title,
      message: message,
    );
  }
}

class _SymbolAlertsGroup {
  final String symbol;
  final _SymbolGroupStatus status;
  final List<_AlertFeedItem> items;

  const _SymbolAlertsGroup({
    required this.symbol,
    required this.status,
    required this.items,
  });
}

class _SymbolAlertResult {
  final String symbol;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const _SymbolAlertResult({
    required this.symbol,
    this.data,
    this.errorMessage,
  });

  bool get hasError => data == null;
}