import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  // ── GET Notes ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getNotes({
    required int userId,
    String? search,
  }) async {
    try {
      String url = '${AppConstants.baseUrl}/get_notes?user_id=$userId';
      if (search != null && search.trim().isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search.trim())}';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': false, 'message': 'Error ${response.statusCode}'};
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  // ── SAVE Note (create or update) ─────────────────────────────────────────
  Future<Map<String, dynamic>> saveNote({
    required int userId,
    int? noteId,
    required String text,
    String title = '',
    String color = '#ffffff',
  }) async {
    try {
      final body = <String, String>{
        'user_id': userId.toString(),
        'title': title,
        'text': text,
        'color': color,
      };
      if (noteId != null) body['note_id'] = noteId.toString();

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/save_note'),
        body: body,
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  // ── DELETE Note ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> deleteNote({
    required int userId,
    required int noteId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/delete_note'),
        body: {
          'user_id': userId.toString(),
          'note_id': noteId.toString(),
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }

  // ── TOGGLE Pin ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> togglePin({
    required int userId,
    required int noteId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/toggle_note_pin'),
        body: {
          'user_id': userId.toString(),
          'note_id': noteId.toString(),
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': 'Koneksi error: $e'};
    }
  }
}
