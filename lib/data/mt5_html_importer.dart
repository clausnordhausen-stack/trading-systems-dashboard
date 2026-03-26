import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import '../domain/trade.dart';

class Mt5HtmlImporter {
  /// Liest eine MT5 "Report" HTML-Datei und versucht Trades zu extrahieren.
  /// Robust genug für den ersten Wurf; wir verfeinern nach deinem echten HTML.
  static List<Trade> parseTradesFromHtmlFile(String filePath) {
    final html = File(filePath).readAsStringSync();
    final doc = html_parser.parse(html);

    // MT5 reports usually contain one main table with trade rows.
    // Strategy: find all tables, pick the one with headers containing "Symbol" and "Profit"/"Gewinn".
    final tables = doc.getElementsByTagName('table');

    dynamic bestTable;
    for (final t in tables) {
      final text = t.text.toLowerCase();
      if (text.contains('symbol') && (text.contains('profit') || text.contains('gewinn'))) {
        bestTable = t;
        break;
      }
    }
    if (bestTable == null) return [];

    // Extract rows
    final rows = bestTable.getElementsByTagName('tr');
    if (rows.isEmpty) return [];

    // Identify column indexes by header row
    final headerCells = rows.first.getElementsByTagName('th');
    final headers = headerCells.map((c) => c.text.trim().toLowerCase()).toList();

    int idxTime = _findHeader(headers, ['time', 'zeit', 'open time', 'öffnungszeit']);
    int idxSymbol = _findHeader(headers, ['symbol']);
    int idxType = _findHeader(headers, ['type', 'typ']);
    int idxVolume = _findHeader(headers, ['volume', 'volumen', 'lots']);
    int idxPrice = _findHeader(headers, ['price', 'preis', 'open price', 'öffnungspreis']);
    int idxClosePrice = _findHeader(headers, ['close price', 'schlusskurs', 'close', 'schließen', 'preis']);
    int idxProfit = _findHeader(headers, ['profit', 'gewinn']);

    // Fallback: if headers not found, we still try by position (typical MT5 order)
    // But keep it simple: if essential columns missing, return empty and we refine with your file.
    if (idxSymbol < 0 || idxType < 0 || idxProfit < 0) return [];

    final trades = <Trade>[];

    for (int r = 1; r < rows.length; r++) {
      final cells = rows[r].getElementsByTagName('td');
      if (cells.isEmpty) continue;

      String cell(int i) => (i >= 0 && i < cells.length) ? cells[i].text.trim() : '';

      final symbol = cell(idxSymbol);
      final sideRaw = cell(idxType).toUpperCase();
      final side = sideRaw.contains('SELL') ? 'SELL' : 'BUY';

      final lots = _toDouble(cell(idxVolume));
      final entry = _toDouble(cell(idxPrice));
      final exit = _toDouble(cell(idxClosePrice));
      final pnl = _toDouble(cell(idxProfit));

      DateTime time = DateTime.now();
      if (idxTime >= 0) {
        time = _tryParseDate(cell(idxTime)) ?? DateTime.now();
      }

      // Filter empty lines
      if (symbol.isEmpty) continue;

      trades.add(
        Trade(
          time: time,
          symbol: symbol,
          side: side,
          lots: lots,
          entry: entry,
          exit: exit,
          pnl: pnl,
        ),
      );
    }

    return trades;
  }

  static int _findHeader(List<String> headers, List<String> candidates) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      for (final c in candidates) {
        if (h == c || h.contains(c)) return i;
      }
    }
    return -1;
  }

  static double _toDouble(String s) {
    // MT5 DE locale: "1 234,56" or "1234,56"
    final cleaned = s
        .replaceAll('\u00A0', ' ')
        .replaceAll(' ', '')
        .replaceAll('.', '') // remove thousand separators (if any)
        .replaceAll(',', '.'); // decimal comma -> dot
    return double.tryParse(cleaned) ?? 0.0;
  }

  static DateTime? _tryParseDate(String s) {
    // Typical MT5: "2026.02.24 19:15" or "24.02.2026 19:15"
    final t = s.trim();

    DateTime? byIsoDots() {
      final m = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})\s+(\d{2}):(\d{2})').firstMatch(t);
      if (m == null) return null;
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    }

    DateTime? byDeDots() {
      final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})').firstMatch(t);
      if (m == null) return null;
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    }

    return byIsoDots() ?? byDeDots();
  }
}