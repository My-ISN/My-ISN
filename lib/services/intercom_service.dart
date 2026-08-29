import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IntercomService {
  static String baseUrl = AppConstants.baseUrl;
  final storage = const FlutterSecureStorage(
    aOptions: AppConstants.kAndroidOptions,
  );

  Future<String?> _getUserId() async {
    try {
      final userDataString = await storage.read(key: 'user_data');
      if (userDataString == null) return null;
      final userData = json.decode(userDataString);
      if (userData is Map) {
        return (userData['id'] ?? userData['user_id'] ?? userData['sup_user_id'])
            ?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getIntercomCompany() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.get(
        Uri.parse('$baseUrl/intercom_get_company?user_id=$userId'),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat data intercom (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> sendIntercomMessage(String message, {int? companyId}) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.post(
        Uri.parse('$baseUrl/intercom_send'),
        body: {
          'user_id': userId,
          'message': message,
          if (companyId != null) 'company_id': companyId.toString(),
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal mengirim pesan (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<List<dynamic>> getIntercomHistory() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/intercom_history?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          return result['data'] ?? [];
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getIntercomPresets() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/intercom_presets?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          return result['data'] ?? [];
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addIntercomPreset(String message, {String icon = '💬'}) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.post(
        Uri.parse('$baseUrl/intercom_add_preset'),
        body: {
          'user_id': userId,
          'message': message,
          'icon': icon,
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menambah preset (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }
}
