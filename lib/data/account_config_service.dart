import 'dart:convert';
import 'package:flutter/services.dart';

class AccountConfigService {
  static Future<Map<String, dynamic>> loadConfig() async {
    final jsonString =
        await rootBundle.loadString('assets/config/accounts.json');
    return json.decode(jsonString);
  }
}