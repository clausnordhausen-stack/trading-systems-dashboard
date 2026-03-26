import 'dart:math';

import '../app/app_session.dart';

enum TradeOutcome {
  win,
  loss,
  breakeven,
}

class SymbolLotConfig {
  final String symbol;
  final double baseLot;
  final double multiplier;
  final double maxLot;

  const SymbolLotConfig({
    required this.symbol,
    required this.baseLot,
    required this.multiplier,
    required this.maxLot,
  });
}

class SymbolLotState {
  final SymbolLotConfig config;
  int lossStreak;

  SymbolLotState({
    required this.config,
    this.lossStreak = 0,
  });

  double get currentLot {
    final lot = config.baseLot * pow(config.multiplier, lossStreak).toDouble();
    return lot > config.maxLot ? config.maxLot : lot;
  }

  void registerOutcome(TradeOutcome outcome) {
    switch (outcome) {
      case TradeOutcome.win:
      case TradeOutcome.breakeven:
        lossStreak = 0;
        break;
      case TradeOutcome.loss:
        lossStreak += 1;
        break;
    }
  }

  void reset() {
    lossStreak = 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'symbol': config.symbol,
      'baseLot': config.baseLot,
      'multiplier': config.multiplier,
      'maxLot': config.maxLot,
      'lossStreak': lossStreak,
      'currentLot': currentLot,
    };
  }
}

class LotRecoveryService {
  static const double _defaultMultiplier = 1.5;

  final Map<String, SymbolLotState> _states = {};

  LotRecoveryService({
    String? account,
  }) {
    _initialize(account ?? AppSession.selectedAccount.value);
  }

  void _initialize(String account) {
    _states.clear();

    final symbols = AppSession.availableSymbolsForAccount(account);
    for (final symbol in symbols) {
      _states[symbol] = SymbolLotState(
        config: SymbolLotConfig(
          symbol: symbol,
          baseLot: AppSession.baseLotFor(account: account, symbol: symbol),
          multiplier: _defaultMultiplier,
          maxLot: AppSession.maxLotFor(account: account, symbol: symbol),
        ),
      );
    }
  }

  void syncAccount(String account) {
    final existingLossStreaks = {
      for (final entry in _states.entries) entry.key: entry.value.lossStreak,
    };

    _initialize(account);

    for (final entry in existingLossStreaks.entries) {
      if (_states.containsKey(entry.key)) {
        _states[entry.key]!.lossStreak = entry.value;
      }
    }
  }

  double currentLotFor(String symbol) {
    final state = _states[symbol];
    if (state == null) {
      throw Exception('No lot config defined for symbol: $symbol');
    }
    return state.currentLot;
  }

  int lossStreakFor(String symbol) {
    final state = _states[symbol];
    if (state == null) {
      throw Exception('No lot config defined for symbol: $symbol');
    }
    return state.lossStreak;
  }

  void registerTradeResult({
    required String symbol,
    required double pnl,
  }) {
    final state = _states[symbol];
    if (state == null) {
      throw Exception('No lot config defined for symbol: $symbol');
    }

    if (pnl > 0) {
      state.registerOutcome(TradeOutcome.win);
    } else if (pnl < 0) {
      state.registerOutcome(TradeOutcome.loss);
    } else {
      state.registerOutcome(TradeOutcome.breakeven);
    }
  }

  void resetSymbol(String symbol) {
    final state = _states[symbol];
    if (state == null) {
      throw Exception('No lot config defined for symbol: $symbol');
    }
    state.reset();
  }

  void resetAll() {
    for (final state in _states.values) {
      state.reset();
    }
  }

  Map<String, dynamic> snapshot() {
    return {
      for (final entry in _states.entries) entry.key: entry.value.toMap(),
    };
  }
}