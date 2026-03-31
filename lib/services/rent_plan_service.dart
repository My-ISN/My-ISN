import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

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

  Future<Map<String, dynamic>> updateRentPlanDetail(int rentalId, Map<String, dynamic> data, {List<http.MultipartFile>? files}) async {
    try {
      final url = Uri.parse('$baseUrl/update_rent_plan_detail');
      var request = http.MultipartRequest('POST', url);
      
      request.fields['rental_id'] = rentalId.toString();
      request.fields['data'] = json.encode(data);

      if (files != null && files.isNotEmpty) {
        request.files.addAll(files);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getRentFormData() async {
    try {
      final url = Uri.parse('$baseUrl/get_rent_form_data');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getRegencies(String provinceId) async {
    try {
      final url = Uri.parse('$baseUrl/get_regencies?province_id=$provinceId');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDistricts(String regencyId) async {
    try {
      final url = Uri.parse('$baseUrl/get_districts?regency_id=$regencyId');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getVillages(String districtId) async {
    try {
      final url = Uri.parse('$baseUrl/get_villages?district_id=$districtId');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> storeRentPlan(Map<String, String> body, Map<String, String> files) async {
    try {
      final url = Uri.parse('$baseUrl/store_rent_plan');
      var request = http.MultipartRequest('POST', url);
      
      request.fields.addAll(body);
      
      for (var entry in files.entries) {
        if (entry.value.isNotEmpty) {
          request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
        }
      }
      
      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveDebt(Map<String, String> data) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];
      
      data['user_id'] = userId.toString();
      
      final url = Uri.parse('$baseUrl/save_debt');
      final response = await http.post(url, body: data);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> payInstallment(int installmentId, double amount, String notes, File? proofFile) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      final url = Uri.parse('$baseUrl/pay_installment');
      var request = http.MultipartRequest('POST', url);
      
      request.fields['installment_id'] = installmentId.toString();
      request.fields['amount'] = amount.toString();
      request.fields['catatan'] = notes;
      request.fields['user_id'] = userId.toString();

      if (proofFile != null) {
        request.files.add(await http.MultipartFile.fromPath('payment_proof', proofFile.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
  Future<Map<String, dynamic>> deleteDebt(int debtId) async {
    try {
      final url = Uri.parse('$baseUrl/delete_debt');
      final response = await http.post(url, body: {
        'debt_id': debtId.toString(),
      });
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteRentPlan(int rentalId) async {
    try {
      final url = Uri.parse('$baseUrl/delete_rent_plan');
      final response = await http.post(url, body: {
        'rental_id': rentalId.toString(),
      });
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> extendRental(int rentalId, Map<String, dynamic> data, Map<String, File?> files) async {
    try {
      final url = Uri.parse('$baseUrl/extend_rental');
      final request = http.MultipartRequest('POST', url);
      
      request.fields['rental_id'] = rentalId.toString();
      data.forEach((key, value) {
        if (value is List) {
          request.fields[key] = json.encode(value);
        } else {
          request.fields[key] = value.toString();
        }
      });

      for (var entry in files.entries) {
        if (entry.value != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'file_jaminan_${entry.key}', entry.value!.path
          ));
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
