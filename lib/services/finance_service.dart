import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FinanceService {
  static const String baseUrl = 'http://17.5.45.192/KODINGAN/PKL/mobileapi';
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> getFinanceDashboard() async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('$baseUrl/get_finance_dashboard?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load finance dashboard');
    }
  }

  Future<Map<String, dynamic>> getFinanceAccounts({int limit = 10, int offset = 0}) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('$baseUrl/get_finance_accounts?user_id=$userId&limit=$limit&offset=$offset'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to connect to server');
    }
  }

  Future<Map<String, dynamic>> storeFinanceAccount(Map<String, String> data) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/store_finance_account'),
      body: {
        ...data,
        'user_id': userId.toString(),
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to save account');
    }
  }

  Future<Map<String, dynamic>> deleteFinanceAccount(String accountId) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/delete_finance_account'),
      body: {
        'account_id': accountId,
        'user_id': userId.toString(),
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to delete account');
    }
  }

  Future<Map<String, dynamic>> getFinanceMeta() async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('$baseUrl/get_finance_meta?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load metadata');
    }
  }

  Future<Map<String, dynamic>> storeFinanceTransaction(Map<String, dynamic> data, {String? filePath}) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/store_finance_transaction'),
    );

    // Add text fields
    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    request.fields['user_id'] = userId.toString();

    // Add file if exists
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('attachment', filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to save transaction');
    }
  }

  Future<Map<String, dynamic>> getFinanceTransactions({
    String? type,
    String? monthYear,
    int limit = 10,
    int offset = 0,
  }) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    String url = '$baseUrl/get_finance_transactions?user_id=$userId&limit=$limit&offset=$offset';
    if (type != null && type != 'all') url += '&type=$type';
    if (monthYear != null) url += '&month_year=$monthYear';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  Future<Map<String, dynamic>> deleteFinanceTransaction(String transactionId) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/delete_finance_transaction'),
      body: {
        'user_id': userId.toString(),
        'transaction_id': transactionId,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to delete transaction');
    }
  }

  Future<Map<String, dynamic>> updateFinanceAccount(Map<String, dynamic> data) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    data['user_id'] = userId.toString();

    final response = await http.post(
      Uri.parse('$baseUrl/update_finance_account'),
      body: data,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update account');
    }
  }

  Future<Map<String, dynamic>> updateFinanceTransaction(Map<String, dynamic> data, {String? filePath}) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/update_finance_transaction'),
    );

    // Add text fields
    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    request.fields['user_id'] = userId.toString();

    // Add file if exists
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('attachment', filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update transaction');
    }
  }
}
