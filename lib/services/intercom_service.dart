import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IntercomService {
  static const String baseUrl = 'https://foxgeen.com/HRIS/mobileapi';
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> getIntercomCompany() async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('$baseUrl/intercom_get_company?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load intercom company');
    }
  }

  Future<Map<String, dynamic>> sendIntercomMessage(String message, {int? companyId}) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/intercom_send'),
      body: {
        'user_id': userId.toString(),
        'message': message,
        if (companyId != null) 'company_id': companyId.toString(),
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send intercom message');
    }
  }

  Future<List<dynamic>> getIntercomHistory() async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('$baseUrl/intercom_history?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['status'] == true) {
        return result['data'] ?? [];
      }
      return [];
    } else {
      throw Exception('Failed to load intercom history');
    }
  }
}
