import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants.dart';

/// Satu baris antrean "Pesan Perlu Dibalas" (satu nomor yang menunggu dibalas).
///
/// Kontrak JSON dari server (semua kunci teks, kunci alternatif di kiri
/// `??` juga diterima agar tahan terhadap perbedaan penamaan backend):
/// {
///   "id": "12",                       // ID antrean — WAJIB, dipakai saat tandai selesai
///   "nomor": "628123456789",          // WAJIB, nomor WhatsApp (digit, tanpa '+')
///   "nama": "Budi",                   // opsional
///   "pesan": "Pak, unit masih ada?",  // kutipan pesan terakhir belum dibalas
///   "waktu": "2026-10-15 09:12:00",   // waktu pesan terakhir (opsional)
///   "belum_dibalas": 2                // opsional, jumlah pesan belum dibalas
/// }
class HandoffItem {
  final String id;
  final String nomor;
  final String nama;
  final String pesan;
  final DateTime? waktu;
  final int belumDibalas;

  HandoffItem({
    required this.id,
    required this.nomor,
    this.nama = '',
    this.pesan = '',
    this.waktu,
    this.belumDibalas = 1,
  });

  factory HandoffItem.fromJson(Map<String, dynamic> json) {
    final String rawWaktu =
        (json['waktu'] ?? json['waktu_pesan'] ?? json['created_at'] ?? json['jam'] ?? '')
            .toString()
            .trim();

    return HandoffItem(
      id: (json['id'] ?? json['antrean_id'] ?? '').toString(),
      nomor: (json['nomor'] ?? json['phone'] ?? json['whatsapp'] ?? '').toString(),
      nama: (json['nama'] ?? json['nama_pelanggan'] ?? json['name'] ?? '').toString(),
      pesan:
          (json['pesan'] ?? json['pesan_terakhir'] ?? json['kutipan'] ?? json['last_message'] ?? '')
              .toString(),
      waktu: rawWaktu.isEmpty
          ? null
          : DateTime.tryParse(rawWaktu.replaceFirst(' ', 'T')),
      belumDibalas:
          int.tryParse((json['belum_dibalas'] ?? json['jumlah_pesan'] ?? 1).toString()) ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nomor': nomor,
        'nama': nama,
        'pesan': pesan,
        'waktu': waktu?.toIso8601String(),
        'belum_dibalas': belumDibalas,
      };
}

/// Hasil pemanggilan antrean: hak akses + daftar item.
///
/// [akses] adalah keputusan SERVER (staf ber-akses menu rent_plan atau bukan).
/// Aplikasi tidak pernah menyimpan daftar staf; ia hanya menampilkan jawaban
/// server. Bila server menjawab `akses: false`, daftar & badge dikosongkan.
class HandoffRingkasan {
  final bool akses;
  final int jumlah;
  final List<HandoffItem> items;
  final String? pesan;
  final bool demo;

  /// true = server menjawab dengan JSON valid. Dipakai untuk membedakan
  /// "ditolak karena tidak punya akses menu rent_plan" (server menjawab, akses
  /// false) dari "gagal terhubung ke server" (tidak menjawab).
  final bool responsValid;

  const HandoffRingkasan({
    required this.akses,
    required this.jumlah,
    this.items = const [],
    this.pesan,
    this.demo = false,
    this.responsValid = false,
  });
}

/// Adaptor tipis ke endpoint HRIS untuk fitur "Pesan Perlu Dibalas".
///
/// Penyambungan ke backend cukup dengan mengganti [pathAntrean] /
/// [pathSelesai] di bawah bila backend menaruh endpoint di lokasi lain.
/// Base URL memakai konfigurasi yang sudah dipakai seluruh fitur lain
/// ([AppConstants.baseUrl] = https://istanakomputer.com/HRIS/mobileapi).
class HandoffService {
  static const String baseUrl = AppConstants.baseUrl;

  /// GET — antrean pesan yang perlu dibalas (+ hak akses).
  static const String pathAntrean = '/bot/handoff-antrean';

  /// POST — tandai satu antrean sudah dibalas.
  static const String pathSelesai = '/bot/handoff-selesai';

  static const Duration _timeout = Duration(seconds: 20);

  /// true = MODE UJI: memakai data contoh lokal (tanpa menyentuh server).
  /// Diatur lewat [AppConstants.handoffDemoMode].
  bool get demoMode => AppConstants.handoffDemoMode;

  Future<String?> _userId() async {
    try {
      final String? raw = await AppConstants.storage.read(key: 'user_data');
      if (raw == null) return null;
      final dynamic data = json.decode(raw);
      return (data['id'] ?? data['user_id'])?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Ambil antrean "Pesan Perlu Dibalas".
  ///
  /// Server WAJIB memfilter berdasarkan hak akses menu rent_plan milik
  /// `user_id`; field `akses` pada balasan adalah sumber kebenaran bagi app.
  Future<HandoffRingkasan> getAntrean({int limit = 50, int offset = 0}) async {
    if (demoMode) return _dataContoh();

    final String? userId = await _userId();
    if (userId == null) {
      return const HandoffRingkasan(
        akses: false,
        jumlah: 0,
        pesan: 'User not logged in',
      );
    }

    try {
      final Uri url = Uri.parse('$baseUrl$pathAntrean').replace(
        queryParameters: {
          'user_id': userId,
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );
      final http.Response res = await http.get(url).timeout(_timeout);
      final dynamic body = json.decode(res.body);
      if (body is! Map) {
        return const HandoffRingkasan(
          akses: false,
          jumlah: 0,
          pesan: 'Balasan server tidak dikenali',
        );
      }

      final Map<String, dynamic> map = Map<String, dynamic>.from(body);
      if (map['status'] != true) {
        return HandoffRingkasan(
          akses: false,
          jumlah: 0,
          pesan: (map['message'] ?? 'Gagal memuat antrean').toString(),
        );
      }

      final dynamic rawAkses = map['akses'];
      final bool akses =
          rawAkses == true || rawAkses == 1 || rawAkses == '1';
      if (!akses) {
        return HandoffRingkasan(
          akses: false,
          jumlah: 0,
          responsValid: true,
          pesan: (map['message'] ?? '').toString(),
        );
      }

      final List<dynamic> raw =
          (map['data'] ?? map['items'] ?? const []) as List<dynamic>;
      final List<HandoffItem> items = raw
          .whereType<Map>()
          .map((e) => HandoffItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final int jumlah =
          int.tryParse((map['jumlah'] ?? items.length).toString()) ?? items.length;

      return HandoffRingkasan(
        akses: true,
        jumlah: jumlah,
        items: items,
        responsValid: true,
      );
    } catch (e) {
      return HandoffRingkasan(
        akses: false,
        jumlah: 0,
        pesan: 'Tidak dapat terhubung ke server: $e',
      );
    }
  }

  /// Tandai satu antrean sudah dibalas.
  ///
  /// Balasan yang diharapkan: {"status": true, "message": "..."}.
  Future<Map<String, dynamic>> tandaiSelesai({
    required String id,
    String? catatan,
  }) async {
    if (demoMode) {
      return const {
        'status': true,
        'message': 'Mode uji: ditandai selesai (tidak dikirim ke server).',
      };
    }

    final String? userId = await _userId();
    if (userId == null) {
      return const {'status': false, 'message': 'User not logged in'};
    }

    try {
      final http.Response res = await http
          .post(
            Uri.parse('$baseUrl$pathSelesai'),
            body: {
              'user_id': userId,
              'id': id,
              if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
            },
          )
          .timeout(_timeout);
      final dynamic body = json.decode(res.body);
      if (body is Map) return Map<String, dynamic>.from(body);
      return const {'status': false, 'message': 'Balasan server tidak dikenali'};
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  /// Data contoh untuk MODE UJI — nomor sengaja fiktif (6280000xxxxxx) dan
  /// nama diberi awalan DEMO agar tidak pernah tertukar dengan pelanggan asli.
  HandoffRingkasan _dataContoh() {
    final DateTime now = DateTime.now();
    final List<HandoffItem> items = [
      HandoffItem(
        id: 'demo-1',
        nomor: '6280000000001',
        nama: 'DEMO Andi',
        pesan: 'Pak, unit laptop untuk sewa mingguan masih ada?',
        waktu: now.subtract(const Duration(minutes: 12)),
        belumDibalas: 2,
      ),
      HandoffItem(
        id: 'demo-2',
        nomor: '6280000000002',
        nama: 'DEMO Sari',
        pesan: 'Kak, invoice sewa bulan ini sudah bisa saya terima?',
        waktu: now.subtract(const Duration(hours: 3)),
        belumDibalas: 1,
      ),
      HandoffItem(
        id: 'demo-3',
        nomor: '6280000000003',
        nama: 'DEMO Rudi',
        pesan: 'Mau tanya harga sewa unit untuk 3 bulan.',
        waktu: now.subtract(const Duration(days: 1, hours: 2)),
        belumDibalas: 1,
      ),
    ];
    return HandoffRingkasan(
      akses: true,
      jumlah: items.length,
      items: items,
      pesan: 'MODE UJI',
      demo: true,
      responsValid: true,
    );
  }
}
