import 'dart:convert';
import 'package:http/http.dart' as http;

class LoginResult {
  final bool success;
  final String? token;
  final String? error;

  LoginResult({
    required this.success,
    this.token,
    this.error,
  });
}

class ApiAuthService {
  static const String baseUrl = 'https://signal-agent-api.onrender.com';

  static Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LoginResult(
          success: true,
          token: data['access_token'],
        );
      }

      if (response.statusCode == 401) {
        return LoginResult(
          success: false,
          error: 'Benutzername oder Passwort falsch',
        );
      }

      return LoginResult(
        success: false,
        error: 'Login fehlgeschlagen (${response.statusCode})',
      );
    } catch (e) {
      return LoginResult(
        success: false,
        error: 'Verbindungsfehler: $e',
      );
    }
  }
}