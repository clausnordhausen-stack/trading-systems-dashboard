import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_session.dart';
import '../service/api_service.dart';
import 'activity_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'risk_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ApiService _api = ApiService();

  int _currentIndex = 0;
  Timer? _statusTimer;
  bool _loadingBackendStatus = false;
  DateTime? _lastBackendCheck;
  List<_ShellSymbolStatus> _backendStatuses = [];

  final List<Widget> _screens = const [
    DashboardScreen(),
    AlertsScreen(),
    ActivityScreen(),
    RiskScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Overview',
    'Alerts',
    'Activity',
    'Risk',
    'Settings',
  ];

  final List<String> _subtitles = const [
    'Trading Systems Dashboard',
    'Operational monitoring and system warnings',
    'System history and recent monitoring events',
    'Risk overview and calculator',
    'Global configuration and visibility',
  ];

  @override
  void initState() {
    super.initState();
    _refreshBackendStatus();
    _startStatusTimer();
    AppSession.selectedAccount.addListener(_onSessionChanged);
    AppSession.refreshSeconds.addListener(_onRefreshChanged);
    AppSession.settingsVersion.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    AppSession.selectedAccount.removeListener(_onSessionChanged);
    AppSession.refreshSeconds.removeListener(_onRefreshChanged);
    AppSession.settingsVersion.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _refreshBackendStatus();
    setState(() {});
  }

  void _onRefreshChanged() {
    _startStatusTimer();
    if (!mounted) return;
    setState(() {});
  }

  void _startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(
      Duration(seconds: AppSession.refreshSeconds.value),
      (_) => _refreshBackendStatus(),
    );
  }

  Future<void> _refreshBackendStatus() async {
    if (_loadingBackendStatus) return;

    final account = AppSession.selectedAccount.value;
    final symbols = AppSession.trackedSymbolsForSelectedAccount;

    if (symbols.isEmpty) {
      if (!mounted) return;
      setState(() {
        _backendStatuses = [];
        _lastBackendCheck = DateTime.now();
      });
      return;
    }

    _loadingBackendStatus = true;

    try {
      final results = await Future.wait(
        symbols.map((symbol) async {
          try {
            final heartbeat = await _api.fetchHeartbeatStatus(symbol: symbol);
            final items = (heartbeat['items'] as List?) ?? [];
            final connectedCount = heartbeat['connected_count'];

            final online = items.isNotEmpty ||
                (connectedCount is num && connectedCount > 0);

            return _ShellSymbolStatus(
              symbol: symbol,
              displayName: AppSession.displayNameForSymbol(
                account: account,
                symbol: symbol,
              ),
              status:
                  online ? _ShellBackendState.online : _ShellBackendState.offline,
              detail: online
                  ? 'connected ${connectedCount ?? items.length}'
                  : 'no heartbeat',
            );
          } catch (_) {
            return _ShellSymbolStatus(
              symbol: symbol,
              displayName: AppSession.displayNameForSymbol(
                account: account,
                symbol: symbol,
              ),
              status: _ShellBackendState.error,
              detail: 'API error',
            );
          }
        }),
      );

      if (!mounted) return;

      setState(() {
        _backendStatuses = results;
        _lastBackendCheck = DateTime.now();
      });
    } finally {
      _loadingBackendStatus = false;
    }
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '-';
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }

  Color _backendColor(_ShellBackendState state) {
    switch (state) {
      case _ShellBackendState.online:
        return Colors.greenAccent;
      case _ShellBackendState.offline:
        return Colors.orangeAccent;
      case _ShellBackendState.error:
        return Colors.redAccent;
    }
  }

  IconData _backendIcon(_ShellBackendState state) {
    switch (state) {
      case _ShellBackendState.online:
        return Icons.cloud_done_outlined;
      case _ShellBackendState.offline:
        return Icons.cloud_off_outlined;
      case _ShellBackendState.error:
        return Icons.error_outline_rounded;
    }
  }

  String _backendLabel(_ShellBackendState state) {
    switch (state) {
      case _ShellBackendState.online:
        return 'ONLINE';
      case _ShellBackendState.offline:
        return 'OFFLINE';
      case _ShellBackendState.error:
        return 'ERROR';
    }
  }

  Widget _statusChip(
    BuildContext context,
    IconData icon,
    String label, {
    Color? accent,
  }) {
    final theme = Theme.of(context);
    final chipColor = accent ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent != null
              ? accent.withOpacity(0.35)
              : theme.dividerColor.withOpacity(0.18),
        ),
        color: accent != null ? accent.withOpacity(0.08) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backendChip(_ShellSymbolStatus status) {
    final color = _backendColor(status.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.45)),
        color: color.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_backendIcon(status.status), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '${status.displayName}: ${_backendLabel(status.status)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backendStatusBar(BuildContext context) {
    final theme = Theme.of(context);

    final hasError =
        _backendStatuses.any((s) => s.status == _ShellBackendState.error);
    final hasOffline =
        _backendStatuses.any((s) => s.status == _ShellBackendState.offline);

    final summary = hasError
        ? 'Backend issue detected'
        : hasOffline
            ? 'Partial heartbeat'
            : 'Backend stable';

    final summaryColor = hasError
        ? Colors.redAccent
        : hasOffline
            ? Colors.orangeAccent
            : Colors.greenAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar_outlined, size: 16, color: summaryColor),
                  const SizedBox(width: 6),
                  Text(
                    summary,
                    style: TextStyle(
                      color: summaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              _statusChip(
                context,
                Icons.sync_outlined,
                'Check ${AppSession.refreshSeconds.value}s',
              ),
              _statusChip(
                context,
                Icons.access_time_outlined,
                'Last ${_formatTime(_lastBackendCheck)}',
              ),
              if (_loadingBackendStatus)
                _statusChip(
                  context,
                  Icons.hourglass_top_rounded,
                  'Updating...',
                ),
            ],
          ),
          if (_backendStatuses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _backendStatuses.map(_backendChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountDropdown(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: AppSession.selectedAccount,
      builder: (context, selected, child) {
        return Container(
          constraints: const BoxConstraints(minWidth: 170, maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              dropdownColor: theme.colorScheme.surface,
              style: const TextStyle(color: Colors.white),
              items: AppSession.accountConfigs.map((account) {
                return DropdownMenuItem<String>(
                  value: account.accountNumber,
                  child: Text(
                    account.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  AppSession.selectAccount(value);
                  await AppSession.persistSelectedAccount(value);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderTopRow(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titles[_currentIndex],
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitles[_currentIndex],
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildAccountDropdown(context)),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: AppSession.alertCount,
                builder: (context, count, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() => _currentIndex = 1);
                        },
                        icon: const Icon(
                          Icons.notifications_active_outlined,
                          color: Colors.white,
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titles[_currentIndex],
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitles[_currentIndex],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.72),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildAccountDropdown(context),
        const SizedBox(width: 8),
        ValueListenableBuilder<int>(
          valueListenable: AppSession.alertCount,
          builder: (context, count, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => _currentIndex = 1);
                  },
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionInfoBar(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: AppSession.selectedAccount,
      builder: (context, account, child) {
        return ValueListenableBuilder<int>(
          valueListenable: AppSession.refreshSeconds,
          builder: (context, refreshSeconds, child) {
            return ValueListenableBuilder<int>(
              valueListenable: AppSession.settingsVersion,
              builder: (context, _, child) {
                final symbols = AppSession.trackedSymbolsForSelectedAccount;
                final symbolLabels = symbols
                    .map(
                      (symbol) => AppSession.displayNameForSymbol(
                        account: account,
                        symbol: symbol,
                      ),
                    )
                    .join(' • ');

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color:
                        theme.colorScheme.surfaceContainerHighest.withOpacity(0.12),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.22),
                    ),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _statusChip(
                        context,
                        Icons.account_balance_wallet_outlined,
                        'Account ${AppSession.labelForAccount(account)}',
                      ),
                      _statusChip(
                        context,
                        Icons.schedule_outlined,
                        'Refresh ${refreshSeconds}s',
                      ),
                      _statusChip(
                        context,
                        Icons.candlestick_chart_outlined,
                        'Symbols ${symbols.length}',
                      ),
                      if (symbolLabels.isNotEmpty)
                        _statusChip(
                          context,
                          Icons.hub_outlined,
                          symbolLabels,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 16,
        16,
        isMobile ? 12 : 16,
        14,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.18),
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeaderTopRow(context, isMobile),
          const SizedBox(height: 12),
          _buildSessionInfoBar(context),
          const SizedBox(height: 12),
          _backendStatusBar(context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isMobile),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: isMobile ? 72 : 80,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_toggle_off_outlined),
            selectedIcon: Icon(Icons.history_toggle_off_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Risk',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

enum _ShellBackendState {
  online,
  offline,
  error,
}

class _ShellSymbolStatus {
  final String symbol;
  final String displayName;
  final _ShellBackendState status;
  final String detail;

  const _ShellSymbolStatus({
    required this.symbol,
    required this.displayName,
    required this.status,
    required this.detail,
  });
}