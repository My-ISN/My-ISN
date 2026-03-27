import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RentPlanService {
  static const String baseUrl = 'https://foxgeen.com/HRIS/mobileapi';
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> getRentPlans({String status = 'all', String? search, int limit = 10, int offset = 0}) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      final Map<String, String> params = {
        'user_id': userId.toString(),
        'status': status,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }

      final url = Uri.parse('$baseUrl/get_rent_plans').replace(queryParameters: params);

      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getRentPlanDetail(int rentalId) async {
    try {
      final url = Uri.parse('$baseUrl/get_rent_plan_detail?rental_id=$rentalId');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateRentPlanStatus(int rentalId, String field, dynamic value) async {
    try {
      final url = Uri.parse('$baseUrl/update_rent_plan_status');
      final response = await http.post(
        url,
        body: {
          'rental_id': rentalId.toString(),
          'field': field,
          'value': value.toString(),
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
