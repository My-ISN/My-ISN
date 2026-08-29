import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  /// Get reminders for user
  /// [filter] can be 'all', 'today', 'upcoming', 'completed', 'active'
  Future<Map<String, dynamic>> getReminders({
    required int userId,
    String filter = 'all',
    String? search,
  }) async {
    try {
      String url = '${AppConstants.baseUrl}/get_reminders?user_id=$userId&filter=$filter';
      if (search != null && search.trim().isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search.trim())}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Gagal mengambil data reminder (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'status': false,
        'message': 'Koneksi error: $e',
      };
    }
  }

  /// Add a new reminder
  Future<Map<String, dynamic>> addReminder({
    required int userId,
    required String title,
    required String reminderDate, // YYYY-MM-DD
    String? reminderTime, // HH:MM
  }) async {
    try {
      final bodyData = {
        'user_id': userId.toString(),
        'title': title.trim(),
        'reminder_date': reminderDate,
      };

      if (reminderTime != null && reminderTime.trim().isNotEmpty) {
        bodyData['reminder_time'] = reminderTime.trim();
      }

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/add_reminder'),
        body: bodyData,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Gagal menyimpan reminder (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'status': false,
        'message': 'Koneksi error: $e',
      };
    }
  }

  /// Update an existing reminder
  Future<Map<String, dynamic>> updateReminder({
    required int reminderId,
    required int userId,
    required String title,
    required String reminderDate,
    String? reminderTime,
  }) async {
    try {
      final bodyData = {
        'reminder_id': reminderId.toString(),
        'user_id': userId.toString(),
        'title': title.trim(),
        'reminder_date': reminderDate,
      };

      if (reminderTime != null && reminderTime.trim().isNotEmpty) {
        bodyData['reminder_time'] = reminderTime.trim();
      } else {
        bodyData['reminder_time'] = '';
      }

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/update_reminder'),
        body: bodyData,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Gagal memperbarui reminder (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'status': false,
        'message': 'Koneksi error: $e',
      };
    }
  }

  /// Toggle Done / Undone status
  Future<Map<String, dynamic>> toggleReminder({
    required int reminderId,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/toggle_reminder'),
        body: {
          'reminder_id': reminderId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Gagal mengubah status reminder (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'status': false,
        'message': 'Koneksi error: $e',
      };
    }
  }

  /// Delete a reminder
  Future<Map<String, dynamic>> deleteReminder({
    required int reminderId,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/delete_reminder'),
        body: {
          'reminder_id': reminderId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': false,
          'message': 'Gagal menghapus reminder (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'status': false,
        'message': 'Koneksi error: $e',
      };
    }
  }
}
