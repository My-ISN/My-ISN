import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../constants.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hasil panggilan perintah suara ke speaker PC kantor (intercom_say).
class IntercomSayResult {
  final bool ok;
  final String message;
  final int playMs;
  final DateTime at;
  final int? httpStatus;

  const IntercomSayResult({
    required this.ok,
    required this.message,
    this.playMs = 0,
    required this.at,
    this.httpStatus,
  });

  /// Contoh: "diputar 3,4 detik"
  String get playLabel {
    if (playMs <= 0) return '';
    final detik = (playMs / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return 'diputar $detik detik';
  }
}

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

  /// Kirim perintah agar speaker PC kantor mengucapkan [text] dan/atau [preset].
  ///
  /// Endpoint HRIS: POST /mobileapi/intercom_say (form-urlencoded).
  /// Timeout 40 detik karena proses TTS di server butuh sekitar 8 detik.
  /// Tidak pernah melempar exception: semua kegagalan dikembalikan sebagai
  /// [IntercomSayResult] dengan pesan yang ramah untuk ditampilkan ke pengguna.
  Future<IntercomSayResult> sayToPc({
    String? text,
    String? preset,
    String suara = 'gadis',
    String? userId,
  }) async {
    final now = DateTime.now();
    final id = userId ?? await _getUserId();
    if (id == null) {
      return IntercomSayResult(
        ok: false,
        message: 'User ID tidak ditemukan. Silakan login ulang.',
        at: now,
      );
    }

    final teks = (text ?? '').trim();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/intercom_say'),
            headers: const {'Accept': 'application/json'},
            body: <String, String>{
              'user_id': id,
              if (teks.isNotEmpty) 'teks': teks,
              if ((preset ?? '').isNotEmpty) 'preset': preset!,
              if (suara.isNotEmpty) 'suara': suara,
            },
          )
          .timeout(const Duration(seconds: 40));
      return _parseSayResponse(response, now);
    } on TimeoutException {
      return IntercomSayResult(
        ok: false,
        message: 'Server tidak merespons dalam 40 detik. Coba lagi.',
        at: now,
      );
    } on SocketException {
      return IntercomSayResult(
        ok: false,
        message: 'Tidak bisa menghubungi server HRIS. Periksa jaringan internet.',
        at: now,
      );
    } on http.ClientException {
      return IntercomSayResult(
        ok: false,
        message: 'Koneksi ke server terputus. Coba lagi.',
        at: now,
      );
    } catch (_) {
      return IntercomSayResult(
        ok: false,
        message: 'Gagal mengirim perintah suara. Coba lagi.',
        at: now,
      );
    }
  }

  IntercomSayResult _parseSayResponse(http.Response response, DateTime now) {
    Map<String, dynamic>? data;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      data = null;
    }

    final sukses = response.statusCode == 200 &&
        data != null &&
        (data['ok'] == true || data['status'] == true);

    if (sukses) {
      final pesan = data['msg'] ?? data['message'];
      return IntercomSayResult(
        ok: true,
        message: (pesan ?? 'Perintah suara terkirim.').toString(),
        playMs: _asInt(data['play_ms']),
        at: _parseAt(data['at'], now),
        httpStatus: response.statusCode,
      );
    }

    return IntercomSayResult(
      ok: false,
      message: _pesanGalat(response.statusCode, data),
      at: now,
      httpStatus: response.statusCode,
    );
  }

  String _pesanGalat(int status, Map<String, dynamic>? data) {
    final dariServer = (data?['message'] ?? data?['msg'])?.toString().trim();
    if (dariServer != null && dariServer.isNotEmpty) return dariServer;

    if (status == 200) {
      return 'Balasan server tidak dikenali (HTTP 200). Coba lagi.';
    }
    switch (status) {
      case 400:
        return 'Permintaan ditolak server (400). Periksa teks atau preset.';
      case 403:
        return 'Akun ini tidak berhak memakai panggil suara (403).';
      case 404:
        return 'Fitur panggil suara belum tersedia di server (404).';
      case 429:
        return 'Terlalu sering memanggil. Tunggu sebentar lalu coba lagi.';
    }
    if (status >= 500) {
      return 'Server HRIS sedang bermasalah (HTTP $status). Coba lagi nanti.';
    }
    return 'Gagal mengirim perintah suara (HTTP $status).';
  }

  int _asInt(dynamic nilai) {
    if (nilai is int) return nilai;
    if (nilai is num) return nilai.round();
    return int.tryParse(nilai?.toString() ?? '') ?? 0;
  }

  DateTime _parseAt(dynamic nilai, DateTime fallback) {
    if (nilai is String && nilai.isNotEmpty) {
      return DateTime.tryParse(nilai)?.toLocal() ?? fallback;
    }
    return fallback;
  }
}
