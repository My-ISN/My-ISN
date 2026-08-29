import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

class FinanceService {
  static const String baseUrl = AppConstants.baseUrl;
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

  Future<Map<String, dynamic>> getFinanceDashboard({String? monthYear}) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      String url = '$baseUrl/get_finance_dashboard?user_id=$userId';
      if (monthYear != null) url += '&month_year=$monthYear';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat dashboard keuangan (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFinanceAccounts({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.get(
        Uri.parse('$baseUrl/get_finance_accounts?user_id=$userId&limit=$limit&offset=$offset'),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat akun keuangan (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> storeFinanceAccount(
    Map<String, String> data,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.post(
        Uri.parse('$baseUrl/store_finance_account'),
        body: {...data, 'user_id': userId},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menyimpan akun (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteFinanceAccount(String accountId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.post(
        Uri.parse('$baseUrl/delete_finance_account'),
        body: {'account_id': accountId, 'user_id': userId},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menghapus akun (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFinanceMeta() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.get(
        Uri.parse('$baseUrl/get_finance_meta?user_id=$userId'),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat metadata keuangan (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> storeFinanceTransaction(
    Map<String, dynamic> data, {
    String? filePath,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/store_finance_transaction'),
      );

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      request.fields['user_id'] = userId;

      if (filePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment', filePath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menyimpan transaksi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFinanceTransactions({
    String? type,
    String? monthYear,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      String url = '$baseUrl/get_finance_transactions?user_id=$userId&limit=$limit&offset=$offset';
      if (type != null && type != 'all') url += '&type=$type';
      if (monthYear != null) url += '&month_year=$monthYear';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat riwayat transaksi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> getPersonalFinanceTransactions({
    required String type,
    String? monthYear,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      String url = '$baseUrl/get_personal_finance_transactions?type=$type&limit=$limit&offset=$offset';
      if (monthYear != null) url += '&month_year=$monthYear';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat transaksi pribadi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteFinanceTransaction(
    String transactionId,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      final response = await http.post(
        Uri.parse('$baseUrl/delete_finance_transaction'),
        body: {'user_id': userId, 'transaction_id': transactionId},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menghapus transaksi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateFinanceAccount(
    Map<String, dynamic> data,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      data['user_id'] = userId;
      final response = await http.post(
        Uri.parse('$baseUrl/update_finance_account'),
        body: data.map((k, v) => MapEntry(k, v.toString())),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memperbarui akun (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateFinanceTransaction(
    Map<String, dynamic> data, {
    String? filePath,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return {'status': false, 'message': 'User ID tidak ditemukan. Silakan login ulang.'};

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/update_finance_transaction'),
      );

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      request.fields['user_id'] = userId;

      if (filePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachment', filePath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memperbarui transaksi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> storePersonalFinanceTransaction(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/store_personal_finance_transaction'),
        body: {...data},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menyimpan transaksi pribadi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePersonalFinanceTransaction(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_personal_finance_transaction'),
        body: {...data},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memperbarui transaksi pribadi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePersonalFinanceTransaction(
    String transactionId,
    String type,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_personal_finance_transaction'),
        body: {
          'id': transactionId,
          'transaction_type': type,
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menghapus transaksi pribadi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> storePersonalBudget(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/store_personal_budget'),
        body: {...data},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menyimpan anggaran (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePersonalBudget(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_personal_budget'),
        body: {...data},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memperbarui anggaran (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePersonalBudget({
    required String category,
    required String budgetMonth,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_personal_budget'),
        body: {
          'category': category,
          'budget_month': budgetMonth,
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal menghapus anggaran (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> getPersonalFinanceReport({
    String? year,
  }) async {
    try {
      String url = '$baseUrl/get_personal_finance_report?';
      if (year != null) url += 'year=$year';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat laporan keuangan (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  Future<Map<String, dynamic>> getPersonalFinanceDashboard({
    String? monthYear,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_personal_finance_dashboard'),
        body: {
          'month_year': monthYear ?? '',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'status': false, 'message': 'Gagal memuat dashboard keuangan pribadi (${response.statusCode})'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }
}
