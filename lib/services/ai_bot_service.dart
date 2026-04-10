import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

class AiBotService {
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

  Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      final userId = await _getUserId();
      final url = Uri.parse('$baseUrl/ai_bot');
      final response = await http.post(
        url,
        body: {'message': message, 'user_id': userId ?? ''},
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

  Future<Map<String, dynamic>> getKnowledgeList({String search = '', int page = 1, int limit = 10}) async {
    try {
      final url = Uri.parse('$baseUrl/get_ai_knowledge?search=$search&page=$page&limit=$limit');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          return data;
        }
      }
      return {'status': false, 'data': [], 'pagination': {'total': 0}};
    } catch (e) {
      return {'status': false, 'data': [], 'pagination': {'total': 0}};
    }
  }

  Future<Map<String, dynamic>> saveKnowledge(Map<String, String> data) async {
    try {
      final userId = await _getUserId();
      final url = Uri.parse('$baseUrl/save_ai_knowledge');
      
      final body = Map<String, String>.from(data);
      if (userId != null) body['user_id'] = userId;

      final response = await http.post(url, body: body);

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

  Future<Map<String, dynamic>> deleteKnowledge(int id) async {
    try {
      final url = Uri.parse('$baseUrl/delete_ai_knowledge');
      final response = await http.post(
        url,
        body: {'id': id.toString()},
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
