import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://signal-agent-api.onrender.com';
  static const Duration _timeout = Duration(seconds: 20);

  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final url = _buildUri(path, queryParameters: queryParameters);

    late http.Response res;
    try {
      res = await http.get(url).timeout(_timeout);
    } on TimeoutException {
      throw Exception('API timeout: ${url.toString()}');
    } catch (e) {
      throw Exception('Network/API error: ${url.toString()} | $e');
    }

    if (res.statusCode != 200) {
      final body = res.body.length > 250
          ? '${res.body.substring(0, 250)}...'
          : res.body;
      throw Exception(
        'API error ${res.statusCode}: ${url.toString()} | $body',
      );
    }

    try {
      final decoded = json.decode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      throw Exception('Invalid JSON from ${url.toString()} | $e');
    }

    throw Exception('Unexpected API response format for ${url.toString()}');
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final url = _buildUri(path, queryParameters: queryParameters);

    late http.Response res;
    try {
      res = await http.get(url).timeout(_timeout);
    } on TimeoutException {
      throw Exception('API timeout: ${url.toString()}');
    } catch (e) {
      throw Exception('Network/API error: ${url.toString()} | $e');
    }

    if (res.statusCode != 200) {
      final body = res.body.length > 250
          ? '${res.body.substring(0, 250)}...'
          : res.body;
      throw Exception(
        'API error ${res.statusCode}: ${url.toString()} | $body',
      );
    }

    try {
      final decoded = json.decode(res.body);
      if (decoded is List<dynamic>) {
        return decoded;
      }
    } catch (e) {
      throw Exception('Invalid JSON from ${url.toString()} | $e');
    }

    throw Exception('Unexpected API response format for ${url.toString()}');
  }

  Future<Map<String, dynamic>> fetchHeartbeatStatus({
    required String symbol,
  }) async {
    return _get(
      '/status/heartbeat',
      queryParameters: {
        'symbol': symbol,
      },
    );
  }

  Future<Map<String, dynamic>> fetchOverviewBundle({
    required String symbol,
    required String account,
    required String magic,
  }) async {
    final results = await Future.wait<Map<String, dynamic>>([
      _get(
        '/status/system_overview',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/latest',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/status/gate_combo',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/status/risk_engine',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/status/heartbeat',
        queryParameters: {
          'symbol': symbol,
        },
      ),
      _get(
        '/debug/state',
        queryParameters: {
          'symbol': symbol,
        },
      ),
      _get(
        '/debug/recent_acks',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
    ]);

    return {
      'systemOverview': results[0],
      'latest': results[1],
      'gateCombo': results[2],
      'riskEngine': results[3],
      'heartbeat': results[4],
      'debugState': results[5],
      'recentAcks': results[6],
    };
  }

  Future<Map<String, dynamic>> fetchAlertsBundle({
    required String symbol,
    required String account,
    required String magic,
  }) async {
    final results = await Future.wait<Map<String, dynamic>>([
      _get(
        '/latest',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/status/gate_combo',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/status/risk_engine',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/status/heartbeat',
        queryParameters: {
          'symbol': symbol,
        },
      ),
      _get(
        '/debug/state',
        queryParameters: {
          'symbol': symbol,
        },
      ),
      _get(
        '/debug/recent_acks',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
    ]);

    return {
      'latest': results[0],
      'gateCombo': results[1],
      'riskEngine': results[2],
      'heartbeat': results[3],
      'debugState': results[4],
      'recentAcks': results[5],
    };
  }

  Future<Map<String, dynamic>> fetchActivityBundle({
    required String symbol,
    required String account,
    required String magic,
  }) async {
    final results = await Future.wait<Map<String, dynamic>>([
      _get(
        '/status/system_overview',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/latest',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/kpis/rolling',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/debug/state',
        queryParameters: {
          'symbol': symbol,
        },
      ),
      _get(
        '/debug/recent_acks',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/debug/pending_by_consumer',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
    ]);

    return {
      'systemOverview': results[0],
      'latest': results[1],
      'kpis': results[2],
      'debugState': results[3],
      'recentAcks': results[4],
      'pendingByConsumer': results[5],
    };
  }

  Future<Map<String, dynamic>> fetchRiskBundle({
    required String symbol,
    required String account,
    required String magic,
  }) async {
    final results = await Future.wait<Map<String, dynamic>>([
      _get(
        '/status/risk_engine',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/status/gate_combo',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/latest',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
      _get(
        '/debug/state',
        queryParameters: {
          'symbol': symbol,
        },
      ),
      _get(
        '/debug/recent_acks',
        queryParameters: {
          'symbol': symbol,
          'account': account,
          'magic': magic,
        },
      ),
    ]);

    return {
      'riskEngine': results[0],
      'gateCombo': results[1],
      'latest': results[2],
      'debugState': results[3],
      'recentAcks': results[4],
    };
  }

  Future<Map<String, dynamic>> fetchDebugSymbolState({
    required String symbol,
  }) async {
    return _get(
      '/debug/state',
      queryParameters: {
        'symbol': symbol,
      },
    );
  }

  Future<Map<String, dynamic>> fetchDebugRecentAcks({
    String? symbol,
    String? account,
    String? magic,
  }) async {
    final params = <String, String>{};

    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.trim();
    }
    if (account != null && account.trim().isNotEmpty) {
      params['account'] = account.trim();
    }
    if (magic != null && magic.trim().isNotEmpty) {
      params['magic'] = magic.trim();
    }

    return _get(
      '/debug/recent_acks',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, dynamic>> fetchDebugDeliveryStatus({
    required int signalId,
  }) async {
    return _get(
      '/debug/delivery_status',
      queryParameters: {
        'signal_id': '$signalId',
      },
    );
  }

  Future<Map<String, dynamic>> fetchPendingByConsumer({
    required String symbol,
    required String account,
    required String magic,
  }) async {
    return _get(
      '/debug/pending_by_consumer',
      queryParameters: {
        'symbol': symbol,
        'account': account,
        'magic': magic,
      },
    );
  }

  Future<Map<String, dynamic>> fetchConsumers({
    String? symbol,
  }) async {
    final params = <String, String>{};
    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.trim();
    }

    return _get(
      '/consumers',
      queryParameters: params.isEmpty ? null : params,
    );
  }
}