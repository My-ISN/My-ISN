import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class QuickSendService {
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

  Future<Map<String, dynamic>> getQuickSendData() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/get_quicksend_data?user_id=$userId');
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

  Future<Map<String, dynamic>> sendWhatsApp({
    required int contactId,
    required String phone,
    required String message,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/send_quicksend_wa');
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'contact_id': contactId.toString(),
          'phone': phone,
          'message': message,
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on TimeoutException catch (_) {
      return {'status': false, 'message': 'Request timeout. Silakan coba lagi.'};
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveContact({
    required String nama,
    required String phone,
    String? emoji,
    String? color,
    String? template,
    List<Map<String, String>>? items,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/save_quicksend_contact');
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'nama': nama,
          'no_hp': phone,
          if (emoji != null) 'icon_emoji': emoji,
          if (color != null) 'color': color,
          if (template != null) 'msg_template': template,
          if (items != null) 'items': json.encode(items),
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on TimeoutException catch (_) {
      return {'status': false, 'message': 'Request timeout. Silakan coba lagi.'};
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteContact(int contactId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/delete_quicksend_contact');
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'contact_id': contactId.toString(),
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on TimeoutException catch (_) {
      return {'status': false, 'message': 'Request timeout. Silakan coba lagi.'};
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
