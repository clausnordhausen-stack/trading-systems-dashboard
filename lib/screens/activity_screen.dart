import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_session.dart';
import '../service/api_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ApiService _api = ApiService();

  late Future<List<_SymbolActivityGroup>> _future;
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
    _future = _buildActivity();
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

  Color _tagColor(String tag) {
    switch (tag.toUpperCase()) {
      case 'SYSTEM':
        return Colors.blueAccent;
      case 'KPI':
        return Colors.greenAccent;
      case 'GATE':
        return Colors.orangeAccent;
      case 'HB':
        return Colors.tealAccent;
      case 'SIGNAL':
        return Colors.purpleAccent;
      case 'TRADE':
        return Colors.cyanAccent;
      case 'EXEC':
        return Colors.amberAccent;
      case 'ACK':
        return Colors.lightBlueAccent;
      case 'DEBUG':
        return const Color(0xFFE6C86E);
      case 'ERROR':
        return Colors.redAccent;
      case 'OK':
        return Colors.greenAccent;
      default:
        return const Color(0xFFE6C86E);
    }
  }

  IconData _tagIcon(String tag) {
    switch (tag.toUpperCase()) {
      case 'SYSTEM':
        return Icons.settings_ethernet;
      case 'KPI':
        return Icons.analytics_outlined;
      case 'GATE':
        return Icons.traffic_outlined;
      case 'HB':
        return Icons.favorite_border;
      case 'SIGNAL':
        return Icons.show_chart;
      case 'TRADE':
        return Icons.swap_horiz;
      case 'EXEC':
        return Icons.bolt_outlined;
      case 'ACK':
        return Icons.done_all;
      case 'DEBUG':
        return Icons.bug_report_outlined;
      case 'ERROR':
        return Icons.cloud_off_rounded;
      case 'OK':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.history;
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

  Widget _activityOverviewGrid(_SymbolActivityGroup group, Color symbolColor) {
    final eventItems = group.items
        .where((item) => item.kind == _ActivityItemKind.event)
        .toList();

    final systemCount = eventItems.where((item) => item.tag == 'SYSTEM').length;
    final kpiCount = eventItems.where((item) => item.tag == 'KPI').length;
    final signalCount = eventItems.where((item) => item.tag == 'SIGNAL').length;
    final execCount = eventItems.where((item) => item.tag == 'EXEC').length;

    final overallStatus = switch (group.status) {
      _SymbolActivityStatus.error => 'ERROR',
      _SymbolActivityStatus.empty => 'OK',
      _SymbolActivityStatus.events => 'ACTIVE',
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
          icon: group.status == _SymbolActivityStatus.error
              ? Icons.cloud_off_rounded
              : Icons.timeline_outlined,
          accent: group.status == _SymbolActivityStatus.error
              ? Colors.redAccent
              : group.status == _SymbolActivityStatus.empty
                  ? Colors.greenAccent
                  : symbolColor,
        ),
        _topStatCard(
          title: 'Events',
          value: '${eventItems.length}',
          icon: Icons.history,
          accent: eventItems.isEmpty ? Colors.greenAccent : symbolColor,
        ),
        _topStatCard(
          title: 'System',
          value: '$systemCount',
          icon: Icons.settings_ethernet,
          accent: systemCount > 0 ? Colors.blueAccent : Colors.white54,
        ),
        _topStatCard(
          title: 'KPI',
          value: '$kpiCount',
          icon: Icons.analytics_outlined,
          accent: kpiCount > 0 ? Colors.greenAccent : Colors.white54,
        ),
        _topStatCard(
          title: 'Signal',
          value: '$signalCount',
          icon: Icons.show_chart,
          accent: signalCount > 0 ? Colors.purpleAccent : Colors.white54,
        ),
        _topStatCard(
          title: 'Execution',
          value: '$execCount',
          icon: Icons.bolt_outlined,
          accent: execCount > 0 ? symbolColor : Colors.white54,
        ),
      ],
    );
  }

  Future<List<_SymbolActivityGroup>> _buildActivity() async {
    final account = AppSession.selectedAccount.value;
    final symbols = AppSession.trackedSymbolsForSelectedAccount;

    _syncExpandedState(symbols);

    final results = await Future.wait<_SymbolActivityResult>(
      symbols.map((symbol) async {
        try {
          final data = await _api.fetchActivityBundle(
            symbol: symbol,
            account: account,
            magic: AppSession.magicFor(
              account: account,
              symbol: symbol,
            ),
          );

          return _SymbolActivityResult(
            symbol: symbol,
            data: data,
          );
        } catch (e) {
          return _SymbolActivityResult(
            symbol: symbol,
            errorMessage: e.toString(),
          );
        }
      }),
    );

    final groups = <_SymbolActivityGroup>[];

    for (final result in results) {
      if (result.hasError) {
        groups.add(
          _SymbolActivityGroup(
            symbol: result.symbol,
            status: _SymbolActivityStatus.error,
            items: [
              _ActivityFeedItem.error(
                symbol: result.symbol,
                title: '${_symbolLabel(result.symbol)} activity unavailable',
                subtitle: result.errorMessage ?? 'Unknown API error',
              ),
            ],
          ),
        );
        continue;
      }

      final extracted = _extractActivity(result.symbol, result.data!);

      if (extracted.isEmpty) {
        groups.add(
          _SymbolActivityGroup(
            symbol: result.symbol,
            status: _SymbolActivityStatus.empty,
            items: [
              _ActivityFeedItem.empty(
                symbol: result.symbol,
                title: '${_symbolLabel(result.symbol)} no activity',
                subtitle: 'No activity entries available.',
              ),
            ],
          ),
        );
      } else {
        groups.add(
          _SymbolActivityGroup(
            symbol: result.symbol,
            status: _SymbolActivityStatus.events,
            items: extracted
                .map(
                  (event) => _ActivityFeedItem.event(
                    symbol: result.symbol,
                    title: event['title'] ?? '-',
                    subtitle: event['subtitle'] ?? '-',
                    tag: event['tag'] ?? 'INFO',
                  ),
                )
                .toList(),
          ),
        );
      }
    }

    return groups;
  }

  List<Map<String, String>> _extractActivity(
    String symbol,
    Map<String, dynamic> data,
  ) {
    final items = <Map<String, String>>[];
    final symbolLabel = _symbolLabel(symbol);

    final system = data['systemOverview'] as Map<String, dynamic>? ?? {};
    final latest = data['latest'] as Map<String, dynamic>? ?? {};
    final kpisRoot = data['kpis'] as Map<String, dynamic>? ?? {};
    final kpis = kpisRoot['kpis'] as Map<String, dynamic>? ?? {};
    final debugState = data['debugState'] as Map<String, dynamic>? ?? {};
    final recentAcks = data['recentAcks'] as Map<String, dynamic>? ?? {};

    final heartbeat = system['heartbeat'] as Map<String, dynamic>? ?? {};
    final gate = system['gate'] as Map<String, dynamic>? ?? {};

    items.add({
      'title': '$symbolLabel system overview refreshed',
      'subtitle': 'Server time: ${system['server_time_utc'] ?? '-'}',
      'tag': 'SYSTEM',
    });

    items.add({
      'title': '$symbolLabel rolling KPIs',
      'subtitle':
          'Trades=${kpis['total_trades'] ?? 0}, Winrate=${kpis['winrate_pct'] ?? 0}%, PnL=${kpis['net_pnl'] ?? 0}',
      'tag': 'KPI',
    });

    items.add({
      'title': '$symbolLabel gate status',
      'subtitle':
          'Gate=${gate['gate_level'] ?? '-'}, Allow=${gate['allow_new_entries'] ?? '-'}',
      'tag': 'GATE',
    });

    items.add({
      'title': '$symbolLabel heartbeat',
      'subtitle': 'Connected count=${heartbeat['connected_count'] ?? 0}',
      'tag': 'HB',
    });

    items.add({
      'title': '$symbolLabel latest signal state',
      'subtitle':
          'has_signal=${latest['has_signal'] ?? false}, blocked=${latest['blocked'] ?? false}',
      'tag': 'SIGNAL',
    });

    final signal = latest['signal'] as Map<String, dynamic>?;
    if (signal != null) {
      items.add({
        'title': '$symbolLabel signal ${signal['side'] ?? '-'}',
        'subtitle': 'updated=${signal['updated_utc'] ?? '-'}',
        'tag': 'TRADE',
      });
    }

    final execution = latest['execution_engine'] as Map<String, dynamic>?;
    if (execution != null) {
      items.add({
        'title': '$symbolLabel execution engine',
        'subtitle':
            'Priority=${execution['priority'] ?? '-'}, Multiplier=${execution['risk_multiplier'] ?? '-'}',
        'tag': 'EXEC',
      });
    }

    if (debugState['debug_available'] == true) {
      items.add({
        'title': '$symbolLabel debug state available',
        'subtitle': 'Pending count=${debugState['pending_count'] ?? '-'}',
        'tag': 'DEBUG',
      });
    } else {
      items.add({
        'title': '$symbolLabel debug state',
        'subtitle': '${debugState['message'] ?? 'Debug endpoint not available'}',
        'tag': 'DEBUG',
      });
    }

    if (recentAcks['debug_available'] == true) {
      final ackItems = (recentAcks['items'] as List?) ?? [];
      items.add({
        'title': '$symbolLabel recent ACK entries',
        'subtitle': 'ACK count=${ackItems.length}',
        'tag': 'ACK',
      });
    } else {
      items.add({
        'title': '$symbolLabel recent ACK state',
        'subtitle': '${recentAcks['message'] ?? 'Recent ACK endpoint not available'}',
        'tag': 'ACK',
      });
    }

    return items;
  }

  Widget _buildFeedCard(_ActivityFeedItem item, Color symbolColor) {
    if (item.kind == _ActivityItemKind.empty) {
      return Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: symbolColor.withOpacity(0.20)),
          ),
          child: ListTile(
            leading: Icon(Icons.inbox_outlined, color: symbolColor),
            title: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.subtitle,
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

    if (item.kind == _ActivityItemKind.error) {
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
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.subtitle,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            trailing: const Chip(label: Text('ERROR')),
          ),
        ),
      );
    }

    final color = _tagColor(item.tag);

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(0.20),
          ),
        ),
        child: ListTile(
          leading: Icon(_tagIcon(item.tag), color: color),
          title: Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.subtitle,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.tag,
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

  Widget _buildSymbolGroup(_SymbolActivityGroup group) {
    final accent = _symbolColor(group.symbol);

    final statusLabel = switch (group.status) {
      _SymbolActivityStatus.events =>
        '${group.items.where((e) => e.kind == _ActivityItemKind.event).length} Events',
      _SymbolActivityStatus.empty => 'No Events',
      _SymbolActivityStatus.error => 'Error',
    };

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
              '${_symbolLabel(group.symbol)} Activity',
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
                  _summaryChip(
                    group.status == _SymbolActivityStatus.error
                        ? 'Backend Error'
                        : group.status == _SymbolActivityStatus.empty
                            ? 'Stable'
                            : 'Active',
                    accent: accent,
                  ),
                ],
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Activity Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ),
              _activityOverviewGrid(group, accent),
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
      child: FutureBuilder<List<_SymbolActivityGroup>>(
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
                    'Activity data unavailable',
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

enum _ActivityItemKind {
  event,
  empty,
  error,
}

enum _SymbolActivityStatus {
  events,
  empty,
  error,
}

class _ActivityFeedItem {
  final _ActivityItemKind kind;
  final String symbol;
  final String title;
  final String subtitle;
  final String tag;

  const _ActivityFeedItem._({
    required this.kind,
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.tag,
  });

  factory _ActivityFeedItem.event({
    required String symbol,
    required String title,
    required String subtitle,
    required String tag,
  }) {
    return _ActivityFeedItem._(
      kind: _ActivityItemKind.event,
      symbol: symbol,
      title: title,
      subtitle: subtitle,
      tag: tag,
    );
  }

  factory _ActivityFeedItem.empty({
    required String symbol,
    required String title,
    required String subtitle,
  }) {
    return _ActivityFeedItem._(
      kind: _ActivityItemKind.empty,
      symbol: symbol,
      title: title,
      subtitle: subtitle,
      tag: 'OK',
    );
  }

  factory _ActivityFeedItem.error({
    required String symbol,
    required String title,
    required String subtitle,
  }) {
    return _ActivityFeedItem._(
      kind: _ActivityItemKind.error,
      symbol: symbol,
      title: title,
      subtitle: subtitle,
      tag: 'ERROR',
    );
  }
}

class _SymbolActivityGroup {
  final String symbol;
  final _SymbolActivityStatus status;
  final List<_ActivityFeedItem> items;

  const _SymbolActivityGroup({
    required this.symbol,
    required this.status,
    required this.items,
  });
}

class _SymbolActivityResult {
  final String symbol;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const _SymbolActivityResult({
    required this.symbol,
    this.data,
    this.errorMessage,
  });

  bool get hasError => data == null;
}