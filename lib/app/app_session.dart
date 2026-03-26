import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SymbolConfig {
  final String symbol;
  final String displayName;
  final String magic;
  final bool enabled;
  final int sortOrder;
  final double baseLot;
  final double maxLot;
  final String colorHex;
  final int? refreshOverrideSeconds;

  const SymbolConfig({
    required this.symbol,
    required this.displayName,
    required this.magic,
    required this.enabled,
    required this.sortOrder,
    required this.baseLot,
    required this.maxLot,
    required this.colorHex,
    required this.refreshOverrideSeconds,
  });

  factory SymbolConfig.fromJson(Map<String, dynamic> json) {
    return SymbolConfig(
      symbol: json['symbol']?.toString().trim() ?? '',
      displayName: json['displayName']?.toString().trim() ?? '',
      magic: json['magic']?.toString().trim() ?? '',
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? '') ?? 999,
      baseLot: _parseDouble(json['baseLot'], 0.0),
      maxLot: _parseDouble(json['maxLot'], 0.0),
      colorHex: json['color']?.toString().trim().isNotEmpty == true
          ? json['color'].toString().trim()
          : '#D4AF37',
      refreshOverrideSeconds: json['refreshOverrideSeconds'] == null
          ? null
          : int.tryParse(json['refreshOverrideSeconds'].toString()),
    );
  }

  static double _parseDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool get isValid =>
      symbol.isNotEmpty && displayName.isNotEmpty && magic.isNotEmpty;

  Color get color {
    final hex = colorHex.replaceAll('#', '').trim();
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFFD4AF37);
  }
}

class AccountConfig {
  final String accountNumber;
  final String label;
  final bool enabled;
  final List<SymbolConfig> symbols;

  const AccountConfig({
    required this.accountNumber,
    required this.label,
    required this.enabled,
    required this.symbols,
  });

  factory AccountConfig.fromJson(Map<String, dynamic> json) {
    final rawSymbols = json['symbols'] as List<dynamic>? ?? <dynamic>[];

    final parsedSymbols = rawSymbols
        .map((item) => SymbolConfig.fromJson(item as Map<String, dynamic>))
        .where((symbol) => symbol.isValid)
        .toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.symbol.compareTo(b.symbol);
      });

    return AccountConfig(
      accountNumber: json['accountNumber']?.toString().trim() ?? '',
      label: json['label']?.toString().trim() ?? '',
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      symbols: parsedSymbols,
    );
  }

  bool get isValid =>
      accountNumber.isNotEmpty && label.isNotEmpty && symbols.isNotEmpty;

  Map<String, String> get symbolMagics => {
        for (final symbol in symbols.where((s) => s.enabled))
          symbol.symbol: symbol.magic,
      };

  List<String> get availableSymbols =>
      symbols.where((s) => s.enabled).map((s) => s.symbol).toList();
}

class AppSession {
  static const List<int> refreshOptions = [
    10,
    30,
    60,
    120,
    180,
    240,
    300,
    350,
  ];

  static final ValueNotifier<String> selectedAccount = ValueNotifier<String>('');
  static final ValueNotifier<int> alertCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> refreshSeconds = ValueNotifier<int>(10);
  static final ValueNotifier<int> settingsVersion = ValueNotifier<int>(0);

  static final Map<String, Set<String>> _hiddenSymbolsByAccount = {};
  static List<AccountConfig> _accounts = [];

  static List<String> get availableAccounts =>
      _accounts.map((a) => a.accountNumber).toList();

  static List<AccountConfig> get accountConfigs => List.unmodifiable(_accounts);

  static String get currentAccount => selectedAccount.value;

  static AccountConfig get selectedAccountConfig {
    return accountByNumber(selectedAccount.value);
  }

  static AccountConfig accountByNumber(String accountNumber) {
    try {
      return _accounts.firstWhere((a) => a.accountNumber == accountNumber);
    } catch (_) {
      throw Exception('Unknown account: $accountNumber');
    }
  }

  static bool hasAccount(String accountNumber) {
    return _accounts.any((a) => a.accountNumber == accountNumber);
  }

  static String labelForAccount(String accountNumber) {
    return accountByNumber(accountNumber).label;
  }

  static Map<String, String> symbolsForAccount(String accountNumber) {
    return Map<String, String>.from(
      accountByNumber(accountNumber).symbolMagics,
    );
  }

  static Map<String, String> symbolsForSelectedAccount() {
    return symbolsForAccount(selectedAccount.value);
  }

  static List<String> availableSymbolsForAccount(String accountNumber) {
    return accountByNumber(accountNumber).availableSymbols;
  }

  static List<String> get availableSymbolsForSelectedAccount =>
      availableSymbolsForAccount(selectedAccount.value);

  static SymbolConfig symbolConfigFor({
    required String account,
    required String symbol,
  }) {
    final accountConfig = accountByNumber(account);

    try {
      return accountConfig.symbols.firstWhere(
        (entry) => entry.symbol == symbol && entry.enabled,
      );
    } catch (_) {
      throw Exception('Unknown symbol $symbol for account $account');
    }
  }

  static String displayNameForSymbol({
    required String account,
    required String symbol,
  }) {
    return symbolConfigFor(account: account, symbol: symbol).displayName;
  }

  static String displayNameForSelectedAccountSymbol(String symbol) {
    return displayNameForSymbol(
      account: selectedAccount.value,
      symbol: symbol,
    );
  }

  static Color colorForSymbol({
    required String account,
    required String symbol,
  }) {
    return symbolConfigFor(account: account, symbol: symbol).color;
  }

  static double baseLotFor({
    required String account,
    required String symbol,
  }) {
    return symbolConfigFor(account: account, symbol: symbol).baseLot;
  }

  static double maxLotFor({
    required String account,
    required String symbol,
  }) {
    return symbolConfigFor(account: account, symbol: symbol).maxLot;
  }

  static int? refreshOverrideFor({
    required String account,
    required String symbol,
  }) {
    return symbolConfigFor(account: account, symbol: symbol)
        .refreshOverrideSeconds;
  }

  static List<String> _orderedSymbolsForAccount(String accountNumber) {
    final config = accountByNumber(accountNumber);
    return config.availableSymbols;
  }

  static List<String> trackedSymbolsForAccount(String accountNumber) {
    final ordered = _orderedSymbolsForAccount(accountNumber);
    final hidden = _hiddenSymbolsByAccount[accountNumber] ?? <String>{};

    final visible = ordered.where((symbol) => !hidden.contains(symbol)).toList();

    if (visible.isNotEmpty) {
      return visible;
    }

    return ordered.isNotEmpty ? [ordered.first] : <String>[];
  }

  static List<String> get trackedSymbolsForSelectedAccount =>
      trackedSymbolsForAccount(selectedAccount.value);

  static bool hasSymbolForAccount({
    required String account,
    required String symbol,
  }) {
    return accountByNumber(account).availableSymbols.contains(symbol);
  }

  static bool isSymbolVisibleForAccount({
    required String account,
    required String symbol,
  }) {
    final hidden = _hiddenSymbolsByAccount[account] ?? <String>{};
    return !hidden.contains(symbol);
  }

  static String magicFor({
    required String account,
    required String symbol,
  }) {
    final config = symbolConfigFor(account: account, symbol: symbol);
    return config.magic;
  }

  static String magicForSelectedAccount(String symbol) {
    return magicFor(
      account: selectedAccount.value,
      symbol: symbol,
    );
  }

  static void selectAccount(String accountNumber) {
    if (!hasAccount(accountNumber)) {
      throw Exception('Unknown account: $accountNumber');
    }
    selectedAccount.value = accountNumber;
  }

  static void setRefreshSeconds(int seconds) {
    if (!refreshOptions.contains(seconds)) {
      throw Exception('Unsupported refresh interval: $seconds');
    }
    refreshSeconds.value = seconds;
    settingsVersion.value++;
  }

  static String _hiddenSymbolsPrefsKey(String account) =>
      'hidden_symbols_$account';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    await _loadAccountsFromAsset();

    if (_accounts.isEmpty) {
      throw Exception(
        'No valid enabled accounts found in assets/config/accounts.json',
      );
    }

    final savedRefresh = prefs.getInt('dashboard_refresh_seconds');
    if (savedRefresh != null && refreshOptions.contains(savedRefresh)) {
      refreshSeconds.value = savedRefresh;
    }

    final savedSelectedAccount = prefs.getString('selected_account');
    if (savedSelectedAccount != null && hasAccount(savedSelectedAccount)) {
      selectedAccount.value = savedSelectedAccount;
    } else {
      final fallback = _accounts.first.accountNumber;
      selectedAccount.value = fallback;
      await prefs.setString('selected_account', fallback);
    }

    _hiddenSymbolsByAccount.clear();

    for (final account in _accounts) {
      final hidden = prefs.getStringList(
            _hiddenSymbolsPrefsKey(account.accountNumber),
          ) ??
          <String>[];

      final validHidden = hidden
          .where((symbol) => account.availableSymbols.contains(symbol))
          .toSet();

      _hiddenSymbolsByAccount[account.accountNumber] = validHidden;
    }

    settingsVersion.value++;
  }

  static Future<void> _loadAccountsFromAsset() async {
    const path = 'assets/config/accounts.json';
    final jsonString = await rootBundle.loadString(path);
    final decoded = json.decode(jsonString) as Map<String, dynamic>;

    final rawAccounts = decoded['accounts'] as List<dynamic>? ?? <dynamic>[];

    _accounts = rawAccounts
        .map((item) => AccountConfig.fromJson(item as Map<String, dynamic>))
        .where((account) => account.isValid && account.enabled)
        .toList();
  }

  static Future<void> persistSelectedAccount(String accountNumber) async {
    if (!hasAccount(accountNumber)) {
      throw Exception('Unknown account: $accountNumber');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_account', accountNumber);
  }

  static Future<void> setSymbolVisible({
    required String account,
    required String symbol,
    required bool visible,
  }) async {
    if (!hasSymbolForAccount(account: account, symbol: symbol)) {
      throw Exception('Unknown symbol $symbol for account $account');
    }

    final allSymbols = _orderedSymbolsForAccount(account);
    final hidden = _hiddenSymbolsByAccount.putIfAbsent(account, () => <String>{});

    if (visible) {
      hidden.remove(symbol);
    } else {
      final currentlyVisible =
          allSymbols.where((s) => !hidden.contains(s)).toList();

      if (currentlyVisible.length <= 1 && currentlyVisible.contains(symbol)) {
        return;
      }

      hidden.add(symbol);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _hiddenSymbolsPrefsKey(account),
      hidden.toList(),
    );

    settingsVersion.value++;
  }

  static Future<void> resetVisibleSymbolsForAccount(String account) async {
    _hiddenSymbolsByAccount[account] = <String>{};

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hiddenSymbolsPrefsKey(account));

    settingsVersion.value++;
  }
}