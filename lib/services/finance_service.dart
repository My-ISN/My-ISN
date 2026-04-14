import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

class FinanceService {
  static const String baseUrl = AppConstants.baseUrl;
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> getFinanceDashboard({String? monthYear}) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'];

    if (userId == null) throw Exception('User ID not found');

    String url = '$baseUrl/get_finance_dashboard?user_id=$userId';
    if (monthYear != null) url += '&month_year=$monthYear';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load finance dashboard');
    }
  }

  Future<Map<String, dynamic>> getFinanceAccounts({
    int limit = 10,
    int offset = 0,
  }) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse(
        '$baseUrl/get_finance_accounts?user_id=$userId&limit=$limit&offset=$offset',
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to connect to server');
    }
  }

  Future<Map<String, dynamic>> storeFinanceAccount(
    Map<String, String> data,
  ) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/store_finance_account'),
      body: {...data, 'user_id': userId.toString()},
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
      body: {'account_id': accountId, 'user_id': userId.toString()},
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

  Future<Map<String, dynamic>> storeFinanceTransaction(
    Map<String, dynamic> data, {
    String? filePath,
  }) async {
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
      request.files.add(
        await http.MultipartFile.fromPath('attachment', filePath),
      );
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

    String url =
        '$baseUrl/get_finance_transactions?user_id=$userId&limit=$limit&offset=$offset';
    if (type != null && type != 'all') url += '&type=$type';
    if (monthYear != null) url += '&month_year=$monthYear';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  Future<Map<String, dynamic>> getPersonalFinanceTransactions({
    required String type,
    String? monthYear,
    int limit = 10,
    int offset = 0,
  }) async {
    String url =
        '$baseUrl/get_personal_finance_transactions?type=$type&limit=$limit&offset=$offset';
    if (monthYear != null) url += '&month_year=$monthYear';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal memuat transaksi pribadi');
    }
  }

  Future<Map<String, dynamic>> deleteFinanceTransaction(
    String transactionId,
  ) async {
    final userDataString = await storage.read(key: 'user_data');
    final userData = json.decode(userDataString ?? '{}');
    final userId = userData['id'] ?? userData['user_id'];

    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/delete_finance_transaction'),
      body: {'user_id': userId.toString(), 'transaction_id': transactionId},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to delete transaction');
    }
  }

  Future<Map<String, dynamic>> updateFinanceAccount(
    Map<String, dynamic> data,
  ) async {
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

  Future<Map<String, dynamic>> updateFinanceTransaction(
    Map<String, dynamic> data, {
    String? filePath,
  }) async {
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
      request.files.add(
        await http.MultipartFile.fromPath('attachment', filePath),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update transaction');
    }
  }

  Future<Map<String, dynamic>> storePersonalFinanceTransaction(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/store_personal_finance_transaction'),
      body: {...data},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal menyimpan transaksi pribadi');
    }
  }

  Future<Map<String, dynamic>> updatePersonalFinanceTransaction(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_personal_finance_transaction'),
      body: {...data},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal memperbarui transaksi pribadi');
    }
  }

  Future<Map<String, dynamic>> deletePersonalFinanceTransaction(
    String transactionId,
    String type,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/delete_personal_finance_transaction'),
      body: {
        'id': transactionId,
        'transaction_type': type,
      },
    );
    

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal menghapus transaksi pribadi');
    }
  }

  Future<Map<String, dynamic>> storePersonalBudget(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/store_personal_budget'),
      body: {...data},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal menyimpan anggaran');
    }
  }

  Future<Map<String, dynamic>> updatePersonalBudget(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_personal_budget'),
      body: {...data},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal memperbarui anggaran');
    }
  }

  Future<Map<String, dynamic>> deletePersonalBudget({
    required String category,
    required String budgetMonth,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/delete_personal_budget'),
      body: {
        'category': category,
        'budget_month': budgetMonth,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal menghapus anggaran');
    }
  }

  Future<Map<String, dynamic>> getPersonalFinanceReport({
    String? year,
  }) async {
    String url = '$baseUrl/get_personal_finance_report?';
    if (year != null) url += 'year=$year';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal memuat laporan keuangan');
    }
  }

  Future<Map<String, dynamic>> getPersonalFinanceDashboard({
    String? monthYear,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/get_personal_finance_dashboard'),
      body: {
        'month_year': monthYear ?? '',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal memuat dashboard keuangan pribadi');
    }
  }
}
