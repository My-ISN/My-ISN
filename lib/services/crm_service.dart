import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class CrmService {
  static const String baseUrl = AppConstants.baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<String?> _getUserId() async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return null;
      final userData = json.decode(userDataString);
      if (userData is Map) {
        return (userData['id'] ?? userData['user_id'] ?? userData['sup_user_id'])?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // --- CRM LEADS ---
  Future<Map<String, dynamic>> getLeads({
    String? userId,
    int page = 1,
    int limit = 10,
    String? search,
    String? categoryId,
    String? status,
  }) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      String urlStr = '$baseUrl/get_crm_leads?user_id=$uId&page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) {
        urlStr += '&search=${Uri.encodeComponent(search)}';
      }
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        urlStr += '&category_id=$categoryId';
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        urlStr += '&status=${Uri.encodeComponent(status)}';
      }

      final response = await http.get(Uri.parse(urlStr));
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getLeadDetail(int leadId, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/get_crm_lead_detail?user_id=$uId&lead_id=$leadId'),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveLead(Map<String, String> data, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final body = Map<String, String>.from(data);
      body['user_id'] = uId;

      final response = await http.post(
        Uri.parse('$baseUrl/save_crm_lead'),
        body: body,
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteLead(int leadId, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/delete_crm_lead'),
        body: {'user_id': uId, 'lead_id': leadId.toString()},
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addLeadFollowup({
    required int leadId,
    required String followupNotes,
    String? nextFollowup,
    String? newStatus,
    String? userId,
  }) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final body = {
        'user_id': uId,
        'lead_id': leadId.toString(),
        'followup_notes': followupNotes,
        if (nextFollowup != null && nextFollowup.isNotEmpty) 'next_followup': nextFollowup,
        if (newStatus != null && newStatus.isNotEmpty) 'new_status': newStatus,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/add_crm_lead_followup'),
        body: body,
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  // --- CRM CUSTOMERS ---
  Future<Map<String, dynamic>> getCustomers({
    String? userId,
    int page = 1,
    int limit = 10,
    String? search,
    String? categoryId,
    String? status,
    String? customerType,
  }) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      String urlStr = '$baseUrl/get_crm_customers?user_id=$uId&page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) {
        urlStr += '&search=${Uri.encodeComponent(search)}';
      }
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        urlStr += '&category_id=$categoryId';
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        urlStr += '&status=${Uri.encodeComponent(status)}';
      }
      if (customerType != null && customerType.isNotEmpty && customerType != 'all') {
        urlStr += '&customer_type=${Uri.encodeComponent(customerType)}';
      }

      final response = await http.get(Uri.parse(urlStr));
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getCustomerDetail(int customerId, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/get_crm_customer_detail?user_id=$uId&customer_id=$customerId'),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveCustomer(Map<String, String> data, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final body = Map<String, String>.from(data);
      body['user_id'] = uId;

      final response = await http.post(
        Uri.parse('$baseUrl/save_crm_customer'),
        body: body,
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteCustomer(int customerId, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/delete_crm_customer'),
        body: {'user_id': uId, 'customer_id': customerId.toString()},
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addCustomerFollowup({
    required int customerId,
    required String followupNotes,
    String? nextFollowup,
    String? newStatus,
    String? userId,
  }) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final body = {
        'user_id': uId,
        'customer_id': customerId.toString(),
        'followup_notes': followupNotes,
        if (nextFollowup != null && nextFollowup.isNotEmpty) 'next_followup': nextFollowup,
        if (newStatus != null && newStatus.isNotEmpty) 'new_status': newStatus,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/add_crm_customer_followup'),
        body: body,
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  // --- CRM COMPETITORS ---
  Future<Map<String, dynamic>> getCompetitors({
    String? userId,
    int page = 1,
    int limit = 10,
    String? search,
    String? typeCategory,
    String? status,
  }) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      String urlStr = '$baseUrl/get_crm_competitors?user_id=$uId&page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) {
        urlStr += '&search=${Uri.encodeComponent(search)}';
      }
      if (typeCategory != null && typeCategory.isNotEmpty && typeCategory != 'all') {
        urlStr += '&type_category=${Uri.encodeComponent(typeCategory)}';
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        urlStr += '&status=${Uri.encodeComponent(status)}';
      }

      final response = await http.get(Uri.parse(urlStr));
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getCompetitorDetail(int competitorId, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/get_crm_competitor_detail?user_id=$uId&competitor_id=$competitorId'),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveCompetitor(Map<String, String> data, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final body = Map<String, String>.from(data);
      body['user_id'] = uId;

      final response = await http.post(
        Uri.parse('$baseUrl/save_crm_competitor'),
        body: body,
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteCompetitor(int competitorId, {String? userId}) async {
    try {
      final uId = userId ?? await _getUserId();
      if (uId == null) return {'status': false, 'message': 'User not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/delete_crm_competitor'),
        body: {'user_id': uId, 'competitor_id': competitorId.toString()},
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
