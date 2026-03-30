import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FinanceService {
  static const String baseUrl = 'https://foxgeen.com/HRIS/mobileapi';
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> getFinanceDashboard() async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('$baseUrl/get_finance_dashboard?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load finance dashboard');
    }
  }

  Future<List<dynamic>> getFinanceAccounts() async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('$baseUrl/get_finance_accounts?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['status'] == true) {
        return result['data'];
      } else {
        throw Exception(result['message'] ?? 'Failed to load accounts');
      }
    } else {
      throw Exception('Failed to connect to server');
    }
  }
}
