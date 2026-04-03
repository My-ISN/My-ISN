import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiBotService {
  static const String baseUrl = 'https://foxgeen.com/HRIS/mobileapi';
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      String? userId;
      if (userDataString != null) {
        final userData = json.decode(userDataString);
        userId = (userData['id'] ?? userData['user_id']).toString();
      }

      final url = Uri.parse('$baseUrl/ai_bot');
      final response = await http.post(
        url,
        body: {
          'message': message,
          'user_id': ?userId,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
