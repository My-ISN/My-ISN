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
///
/// Backend HRIS mengirim kunci `phone`, `nama`, `kutipan`, `jam` — semuanya
/// sudah dipetakan di [HandoffItem.fromJson].
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
      id: (json['id'] ?? json['antrean_id'] ?? json['handoff_id'] ?? '').toString(),
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
/// Kontrak FINAL yang dipakai aplikasi:
///   GET  {baseUrl}/bot/handoff-antrean?user_id=&limit=&offset=
///   POST {baseUrl}/bot/handoff-selesai   (user_id, id, catatan)
///
/// Backend masih menjaga ALIAS lama `/get_handoff_antrean` dan
/// `/tandai_handoff_dibalas`. Adaptor mencoba bentuk FINAL lebih dulu dan
/// otomatis jatuh ke alias hanya bila server menjawab 404 (endpoint final
/// belum dipasang di server). Base URL memakai konfigurasi yang sudah dipakai
/// seluruh fitur lain ([AppConstants.baseUrl]).
///
/// Bentuk balasan yang diterima (keduanya diuji di
/// `test/handoff_service_test.dart`):
///   a) bentuk FINAL/pendek : {"status":true,"akses":true,"jumlah":1,"data":[{...}]}
///   b) bentuk backend HRIS  : {"status":true,"data":{"jumlah_belum_dibalas":1,
///                              "antrean":[{...}]}}
class HandoffService {
  static const String baseUrl = AppConstants.baseUrl;

  /// GET — antrean pesan yang perlu dibalas (+ hak akses).
  static const String pathAntrean = '/bot/handoff-antrean';

  /// POST — tandai satu antrean sudah dibalas.
  static const String pathSelesai = '/bot/handoff-selesai';

  /// Alias lama yang masih dijaga backend (dipakai hanya bila bentuk di atas 404).
  static const String aliasAntrean = '/get_handoff_antrean';
  static const String aliasSelesai = '/tandai_handoff_dibalas';

  static const Duration _timeout = Duration(seconds: 20);

  /// Klien HTTP yang bisa disuntik di uji (null = pakai `http` biasa).
  final http.Client? _client;

  /// Penimpaan mode uji (dipakai uji supaya jalur jaringan bisa diuji tanpa
  /// mengubah [AppConstants.handoffDemoMode]).
  final bool? _demoOverride;

  /// Pengambil user_id (default: dari secure storage `user_data`).
  final Future<String?> Function()? _userIdProvider;

  HandoffService({
    http.Client? client,
    bool? demoModeOverride,
    Future<String?> Function()? userIdProvider,
  })  : _client = client,
        _demoOverride = demoModeOverride,
        _userIdProvider = userIdProvider;

  /// true = MODE UJI: memakai data contoh lokal (tanpa menyentuh server).
  /// Diatur lewat [AppConstants.handoffDemoMode].
  bool get demoMode => _demoOverride ?? AppConstants.handoffDemoMode;

  Future<http.Response> _get(Uri url) {
    final http.Client? klien = _client;
    return klien != null ? klien.get(url) : http.get(url);
  }

  Future<http.Response> _post(Uri url, Map<String, String> body) {
    final http.Client? klien = _client;
    return klien != null ? klien.post(url, body: body) : http.post(url, body: body);
  }

  Future<String?> _userId() async {
    final Future<String?> Function()? penyedia = _userIdProvider;
    if (penyedia != null) {
      try {
        return await penyedia();
      } catch (_) {
        return null;
      }
    }
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
  /// Bila server tidak mengirim `akses` (backend HRIS memakai HTTP 403 untuk
  /// menolak), balasan 200 + `status: true` dianggap berhak.
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

    final Map<String, String> query = {
      'user_id': userId,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    try {
      final Uri url = Uri.parse('$baseUrl$pathAntrean').replace(queryParameters: query);
      http.Response res = await _get(url).timeout(_timeout);
      if (res.statusCode == 404) {
        // Endpoint bentuk final belum ada di server -> pakai alias lama.
        final Uri urlAlias =
            Uri.parse('$baseUrl$aliasAntrean').replace(queryParameters: query);
        res = await _get(urlAlias).timeout(_timeout);
      }
      return _uraiAntrean(res);
    } catch (e) {
      return HandoffRingkasan(
        akses: false,
        jumlah: 0,
        pesan: 'Tidak dapat terhubung ke server: $e',
      );
    }
  }

  /// Menerjemahkan balasan server menjadi [HandoffRingkasan].
  HandoffRingkasan _uraiAntrean(http.Response res) {
    dynamic body;
    try {
      body = json.decode(res.body);
    } catch (_) {
      body = null;
    }

    if (body is! Map) {
      return HandoffRingkasan(
        akses: false,
        jumlah: 0,
        responsValid: res.statusCode < 500,
        pesan: res.statusCode == 403
            ? 'Tidak berakses menu Rent Plan'
            : 'Balasan server tidak dikenali',
      );
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(body);
    final String pesanServer =
        (map['message'] ?? map['pesan'] ?? '').toString().trim();

    // 403 = server menolak: staf ini tidak punya hak akses menu rent_plan.
    // Backend HRIS memakai 403 (tidak mengirim field `akses`).
    if (res.statusCode == 403) {
      return HandoffRingkasan(
        akses: false,
        jumlah: 0,
        responsValid: true,
        pesan: pesanServer.isEmpty
            ? 'Antrean ini hanya untuk staf dengan akses menu Rent Plan.'
            : pesanServer,
      );
    }

    if (res.statusCode >= 400 || map['status'] != true) {
      return HandoffRingkasan(
        akses: false,
        jumlah: 0,
        responsValid: res.statusCode < 500,
        pesan: pesanServer.isEmpty ? 'Gagal memuat antrean' : pesanServer,
      );
    }

    final dynamic rawAkses = map['akses'] ?? map['has_access'];
    bool akses = rawAkses == true || rawAkses == 1 || rawAkses == '1';
    // Server tidak mengirim field `akses` (backend HRIS menjaga hak akses
    // lewat HTTP 403): balasan 200 + status true berarti staf berhak.
    if (rawAkses == null) akses = res.statusCode == 200;

    if (!akses) {
      return HandoffRingkasan(
        akses: false,
        jumlah: 0,
        responsValid: true,
        pesan: pesanServer,
      );
    }

    final List<dynamic> raw = _daftarMentah(map);
    final List<HandoffItem> items = raw
        .whereType<Map>()
        .map((e) => HandoffItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final int jumlah = int.tryParse(
          (map['jumlah'] ?? map['jumlah_belum_dibalas'] ?? _jumlahDalamData(map) ?? items.length)
              .toString(),
        ) ??
        items.length;

    return HandoffRingkasan(
      akses: true,
      jumlah: jumlah,
      items: items,
      responsValid: true,
    );
  }

  /// Menerima `data` sebagai daftar langsung maupun sebagai objek
  /// `{"antrean": [...]}` (bentuk backend HRIS).
  List<dynamic> _daftarMentah(Map<String, dynamic> map) {
    for (final dynamic kandidat in [
      map['data'],
      map['items'],
      map['antrean'],
    ]) {
      if (kandidat is List) return kandidat;
      if (kandidat is Map) {
        final Map<String, dynamic> dalam = Map<String, dynamic>.from(kandidat);
        for (final dynamic isi in [
          dalam['antrean'],
          dalam['items'],
          dalam['data'],
          dalam['list'],
        ]) {
          if (isi is List) return isi;
        }
      }
    }
    return const [];
  }

  /// `data.jumlah_belum_dibalas` / `data.jumlah` / `data.total` (bila ada).
  int? _jumlahDalamData(Map<String, dynamic> map) {
    final dynamic data = map['data'];
    if (data is! Map) return null;
    final Map<String, dynamic> dalam = Map<String, dynamic>.from(data);
    for (final dynamic nilai in [
      dalam['jumlah_belum_dibalas'],
      dalam['jumlah'],
      dalam['total'],
      dalam['unread_count'],
    ]) {
      final int? angka = int.tryParse('$nilai');
      if (angka != null) return angka;
    }
    return null;
  }

  /// Tandai satu antrean sudah dibalas.
  ///
  /// Balasan yang diharapkan: {"status": true, "message": "..."}.
  /// Body memuat `id` DAN `handoff_id` karena backend HRIS membaca
  /// `handoff_id` pada alias lama.
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

    final Map<String, String> body = {
      'user_id': userId,
      'id': id,
      'handoff_id': id,
      if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
    };

    try {
      http.Response res =
          await _post(Uri.parse('$baseUrl$pathSelesai'), body).timeout(_timeout);
      if (res.statusCode == 404) {
        // Endpoint bentuk final belum ada di server -> pakai alias lama.
        res = await _post(Uri.parse('$baseUrl$aliasSelesai'), body).timeout(_timeout);
      }

      dynamic hasil;
      try {
        hasil = json.decode(res.body);
      } catch (_) {
        hasil = null;
      }
      if (hasil is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(hasil);
        if (map['status'] != true && map['message'] == null) {
          map['message'] = 'Gagal menandai antrean (HTTP ${res.statusCode})';
        }
        return map;
      }
      return {
        'status': false,
        'message': 'Balasan server tidak dikenali (HTTP ${res.statusCode})',
      };
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
