import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _savingRefresh = false;
  bool _savingSymbols = false;

  Future<void> _saveRefresh(int value) async {
    setState(() {
      _savingRefresh = true;
    });

    try {
      AppSession.setRefreshSeconds(value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dashboard_refresh_seconds', value);
    } finally {
      if (mounted) {
        setState(() {
          _savingRefresh = false;
        });
      }
    }
  }

  Future<void> _setSymbolVisible({
    required String account,
    required String symbol,
    required bool visible,
  }) async {
    setState(() {
      _savingSymbols = true;
    });

    try {
      await AppSession.setSymbolVisible(
        account: account,
        symbol: symbol,
        visible: visible,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingSymbols = false;
        });
      }
    }
  }

  Future<void> _resetSymbols(String account) async {
    setState(() {
      _savingSymbols = true;
    });

    try {
      await AppSession.resetVisibleSymbolsForAccount(account);
    } finally {
      if (mounted) {
        setState(() {
          _savingSymbols = false;
        });
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _summaryChip(
    String label, {
    IconData? icon,
    Color? borderColor,
    Color? textColor,
    Color? fillColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.white12),
        color: fillColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: textColor ?? Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Zentrale Einstellungen für Refresh, Symbolsichtbarkeit und Account-Konfiguration.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ValueListenableBuilder<int>(
          valueListenable: AppSession.refreshSeconds,
          builder: (context, refreshSeconds, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Refresh'),
                const SizedBox(height: 10),
                const Text(
                  'Globales Auto-Refresh-Intervall für alle Seiten der App.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _summaryChip(
                      'Aktuell: ${refreshSeconds}s',
                      icon: Icons.schedule_outlined,
                    ),
                    if (_savingRefresh)
                      _summaryChip(
                        'Speichern...',
                        icon: Icons.sync,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: refreshSeconds,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: const TextStyle(color: Colors.white),
                  items: AppSession.refreshOptions.map((seconds) {
                    return DropdownMenuItem<int>(
                      value: seconds,
                      child: Text(
                        '$seconds Sekunden',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: _savingRefresh
                      ? null
                      : (value) async {
                          if (value == null) return;
                          await _saveRefresh(value);
                        },
                  decoration: const InputDecoration(
                    labelText: 'Refresh-Intervall',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    return ValueListenableBuilder<String>(
      valueListenable: AppSession.selectedAccount,
      builder: (context, selectedAccount, child) {
        return ValueListenableBuilder<int>(
          valueListenable: AppSession.refreshSeconds,
          builder: (context, refreshSeconds, child) {
            return ValueListenableBuilder<int>(
              valueListenable: AppSession.settingsVersion,
              builder: (context, _, child) {
                final visibleSymbols =
                    AppSession.trackedSymbolsForSelectedAccount;
                final allSymbols =
                    AppSession.availableSymbolsForSelectedAccount;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Session Info'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _summaryChip(
                              'Aktiver Account: ${AppSession.labelForAccount(selectedAccount)}',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            _summaryChip(
                              'Refresh: ${refreshSeconds}s',
                              icon: Icons.timer_outlined,
                            ),
                            _summaryChip(
                              'Sichtbar: ${visibleSymbols.length}/${allSymbols.length}',
                              icon: Icons.visibility_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (visibleSymbols.isEmpty)
                          const Text(
                            'Keine sichtbaren Symbole konfiguriert.',
                            style: TextStyle(color: Colors.white70),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: visibleSymbols.map((symbol) {
                              final color = AppSession.colorForSymbol(
                                account: selectedAccount,
                                symbol: symbol,
                              );

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: color.withOpacity(0.45),
                                  ),
                                  color: color.withOpacity(0.06),
                                ),
                                child: Text(
                                  '${AppSession.displayNameForSelectedAccountSymbol(symbol)} ($symbol)',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAccountOverviewCard() {
    return ValueListenableBuilder<int>(
      valueListenable: AppSession.settingsVersion,
      builder: (context, _, child) {
        final accounts = AppSession.accountConfigs;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Accounts Overview'),
                const SizedBox(height: 12),
                for (int i = 0; i < accounts.length; i++) ...[
                  _buildSingleAccountOverview(accounts[i]),
                  if (i < accounts.length - 1) const Divider(height: 24),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleAccountOverview(AccountConfig account) {
    final visible = AppSession.trackedSymbolsForAccount(account.accountNumber);
    final all = AppSession.availableSymbolsForAccount(account.accountNumber);
    final isSelected = AppSession.selectedAccount.value == account.accountNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              account.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            _summaryChip(
              account.accountNumber,
              icon: Icons.badge_outlined,
            ),
            if (isSelected)
              _summaryChip(
                'Aktiv',
                icon: Icons.check_circle_outline,
                borderColor: Colors.greenAccent.withOpacity(0.45),
                textColor: Colors.greenAccent,
                fillColor: Colors.greenAccent.withOpacity(0.06),
              ),
            _summaryChip(
              'Sichtbar ${visible.length}/${all.length}',
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: account.symbols.map((symbolConfig) {
            final isVisible = AppSession.isSymbolVisibleForAccount(
              account: account.accountNumber,
              symbol: symbolConfig.symbol,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isVisible
                      ? symbolConfig.color.withOpacity(0.45)
                      : Colors.white12,
                ),
                color: isVisible
                    ? symbolConfig.color.withOpacity(0.06)
                    : null,
              ),
              child: Text(
                '${symbolConfig.displayName} (${symbolConfig.symbol}) • Magic ${symbolConfig.magic}',
                style: TextStyle(
                  color: isVisible ? symbolConfig.color : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSymbolConfigCard({
    required String account,
    required SymbolConfig config,
  }) {
    final visible = AppSession.isSymbolVisibleForAccount(
      account: account,
      symbol: config.symbol,
    );

    final color = config.color;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${config.displayName} (${config.symbol})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                _summaryChip('Magic ${config.magic}', icon: Icons.key_outlined),
                _summaryChip(
                  visible ? 'Sichtbar' : 'Ausgeblendet',
                  icon: visible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  borderColor: visible
                      ? color.withOpacity(0.45)
                      : Colors.white12,
                  textColor: visible ? color : Colors.white,
                  fillColor: visible ? color.withOpacity(0.06) : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _summaryChip(
                  'Base Lot ${config.baseLot.toStringAsFixed(2)}',
                  icon: Icons.play_arrow_outlined,
                ),
                _summaryChip(
                  'Max Lot ${config.maxLot.toStringAsFixed(2)}',
                  icon: Icons.trending_up_outlined,
                ),
                _summaryChip(
                  'Sort ${config.sortOrder}',
                  icon: Icons.sort,
                ),
                _summaryChip(
                  config.refreshOverrideSeconds == null
                      ? 'Refresh global'
                      : 'Refresh ${config.refreshOverrideSeconds}s',
                  icon: Icons.update_outlined,
                ),
                _summaryChip(
                  'Color ${config.colorHex}',
                  icon: Icons.palette_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Symbol in der App anzeigen',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Steuert die Sichtbarkeit in Overview, Alerts, Activity und Risk.',
                style: TextStyle(color: Colors.white70),
              ),
              value: visible,
              onChanged: _savingSymbols
                  ? null
                  : (value) async {
                      await _setSymbolVisible(
                        account: account,
                        symbol: config.symbol,
                        visible: value,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbolsCard() {
    return ValueListenableBuilder<int>(
      valueListenable: AppSession.settingsVersion,
      builder: (context, _, child) {
        final accounts = AppSession.accountConfigs;

        return Column(
          children: [
            for (int i = 0; i < accounts.length; i++) ...[
              _buildPerAccountSymbolSection(accounts[i]),
              if (i < accounts.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPerAccountSymbolSection(AccountConfig account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Symbole – ${account.label}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_savingSymbols)
                  _summaryChip(
                    'Speichern...',
                    icon: Icons.sync,
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _savingSymbols
                      ? null
                      : () async {
                          await _resetSymbols(account.accountNumber);
                        },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Zurücksetzen'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < account.symbols.length; i++) ...[
          _buildSymbolConfigCard(
            account: account.accountNumber,
            config: account.symbols[i],
          ),
          if (i < account.symbols.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildJsonHintCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Config Source'),
            const SizedBox(height: 10),
            const Text(
              'Accounts und Symbolparameter werden aus assets/config/accounts.json geladen.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _summaryChip(
                  'Pfad: assets/config/accounts.json',
                  icon: Icons.folder_open_outlined,
                ),
                _summaryChip(
                  'Felder: Magic, Lots, Color, Sortierung',
                  icon: Icons.description_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 16),
        _buildRefreshCard(),
        const SizedBox(height: 16),
        _buildSessionInfoCard(),
        const SizedBox(height: 16),
        _buildAccountOverviewCard(),
        const SizedBox(height: 16),
        _buildSymbolsCard(),
        const SizedBox(height: 16),
        _buildJsonHintCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}