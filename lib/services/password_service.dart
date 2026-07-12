import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class PasswordService {
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

  Future<Map<String, dynamic>> getPasswords() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/get_passwords?user_id=$userId');
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

  Future<Map<String, dynamic>> getPasswordDetails(dynamic idAcc) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/get_password_details?user_id=$userId&id_acc=$idAcc');
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

  Future<Map<String, dynamic>> getPasswordShareList(dynamic idAcc) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/get_password_share_list?user_id=$userId&id_acc=$idAcc');
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

  Future<Map<String, dynamic>> sharePasswordAccount(dynamic idAcc, List<dynamic> userIds) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/share_password_account');
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'id_acc': idAcc.toString(),
          'user_ids': userIds.join(','),
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

  Future<Map<String, dynamic>> revokePasswordShare(dynamic idAcc, dynamic targetUserId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User not found'};

      final url = Uri.parse('$baseUrl/revoke_password_share');
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'id_acc': idAcc.toString(),
          'target_user_id': targetUserId.toString(),
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
