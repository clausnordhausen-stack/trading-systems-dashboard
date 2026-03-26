class Trade {
  final DateTime time;
  final String symbol;
  final String side;
  final double lots;
  final double entry;
  final double exit;
  final double pnl;

  const Trade({
    required this.time,
    required this.symbol,
    required this.side,
    required this.lots,
    required this.entry,
    required this.exit,
    required this.pnl,
  });
}

List<Trade> demoTrades() {
  return [
    Trade(time: DateTime(2026, 2, 20, 9, 15), symbol: 'XAUUSD', side: 'BUY', lots: 0.10, entry: 2031.2, exit: 2036.8, pnl: 56.0),
    Trade(time: DateTime(2026, 2, 20, 10, 5), symbol: 'BTCUSD', side: 'SELL', lots: 0.02, entry: 51200, exit: 50850, pnl: 70.0),
    Trade(time: DateTime(2026, 2, 20, 11, 40), symbol: 'XAUUSD', side: 'SELL', lots: 0.08, entry: 2038.4, exit: 2042.1, pnl: -29.6),
    Trade(time: DateTime(2026, 2, 20, 13, 10), symbol: 'BTCUSD', side: 'BUY', lots: 0.03, entry: 50920, exit: 51310, pnl: 117.0),
    Trade(time: DateTime(2026, 2, 20, 14, 55), symbol: 'EURUSD', side: 'BUY', lots: 0.20, entry: 1.0812, exit: 1.0830, pnl: 36.0),
  ];
}