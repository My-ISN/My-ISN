import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CreativeIdeaService {
  static const String baseUrl = 'https://foxgeen.com/HRIS/mobileapi';
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> _getUserData() async {
    String? userDataString = await _storage.read(key: 'user_data');
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return {};
  }

  Future<Map<String, dynamic>> getLeaderboard() async {
    try {
      final userData = await _getUserData();
      final userId = (userData['id'] ?? userData['user_id']).toString();
      final url = Uri.parse('$baseUrl/get_creative_leaderboard?user_id=$userId');
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

  Future<Map<String, dynamic>> getIdeas({String type = 'all', int page = 1, int limit = 10}) async {
    try {
      final userData = await _getUserData();
      final userId = (userData['id'] ?? userData['user_id']).toString();
      final url = Uri.parse('$baseUrl/get_creative_ideas?user_id=$userId&type=$type&page=$page&limit=$limit');
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

  Future<Map<String, dynamic>> submitIdea(String title, String description) async {
    try {
      final userData = await _getUserData();
      final userId = (userData['id'] ?? userData['user_id']).toString();
      final url = Uri.parse('$baseUrl/submit_creative_idea');
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'title': title,
          'description': description,
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

  Future<Map<String, dynamic>> updateIdea(String ideaId, String title, String description, int status) async {
    try {
      final url = Uri.parse('$baseUrl/update_creative_idea');
      final response = await http.post(
        url,
        body: {
          'idea_id': ideaId,
          'title': title,
          'description': description,
          'status': status.toString(),
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': false, 'message': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteIdea(String ideaId) async {
    try {
      final url = Uri.parse('$baseUrl/delete_creative_idea');
      final response = await http.post(
        url,
        body: {'idea_id': ideaId},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': false, 'message': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
