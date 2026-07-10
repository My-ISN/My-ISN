import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class AiChatIsnService {
  static const String baseUrl = AppConstants.baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<String?> _getUserId() async {
    String? userDataString = await _storage.read(key: 'user_data');
    if (userDataString != null) {
      final userData = json.decode(userDataString);
      return (userData['id'] ?? userData['user_id']).toString();
    }
    return null;
  }

  Future<Map<String, dynamic>> getHistory() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan'};
      final url = Uri.parse('$baseUrl/ai_chat_isn/history?user_id=$userId');
      final response = await http.get(url);

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

  Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan'};
      final url = Uri.parse('$baseUrl/ai_chat_isn/send');
      final response = await http.post(
        url,
        body: {'message': message, 'user_id': userId},
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

  Future<Map<String, dynamic>> clearHistory() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan'};
      final url = Uri.parse('$baseUrl/ai_chat_isn/clear');
      final response = await http.post(
        url,
        body: {'user_id': userId},
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
