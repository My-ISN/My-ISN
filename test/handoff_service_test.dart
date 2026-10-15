// Uji cepat untuk adaptor "Pesan Perlu Dibalas" — berjalan TANPA backend
// karena memakai MODE UJI (data contoh) pada HandoffService.
//
// Jalankan: flutter test test/handoff_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myisn/constants.dart';
import 'package:myisn/services/handoff_service.dart';

void main() {
  group('HandoffItem.fromJson', () {
    test('membaca kunci utama sesuai kontrak', () {
      final item = HandoffItem.fromJson({
        'id': '12',
        'nomor': '628123456789',
        'nama': 'Budi',
        'pesan': 'Pak, unit masih ada?',
        'waktu': '2026-10-15 09:12:00',
        'belum_dibalas': 2,
      });

      expect(item.id, '12');
      expect(item.nomor, '628123456789');
      expect(item.nama, 'Budi');
      expect(item.pesan, 'Pak, unit masih ada?');
      expect(item.waktu, DateTime.parse('2026-10-15 09:12:00'));
      expect(item.belumDibalas, 2);
    });

    test('tahan terhadap kunci alternatif & field kosong', () {
      final item = HandoffItem.fromJson({
        'antrean_id': 7,
        'phone': '0812345678',
        'name': 'Sari',
        'last_message': 'Halo',
        'created_at': '2026-10-14T20:00:00',
        'jumlah_pesan': '3',
      });

      expect(item.id, '7');
      expect(item.nomor, '0812345678');
      expect(item.nama, 'Sari');
      expect(item.pesan, 'Halo');
      expect(item.waktu, DateTime.parse('2026-10-14T20:00:00'));
      expect(item.belumDibalas, 3);
    });

    test('waktu tidak valid tidak membuat gagal', () {
      final item = HandoffItem.fromJson({'id': '1', 'nomor': '628', 'waktu': 'bukan tanggal'});
      expect(item.waktu, isNull);
      expect(item.belumDibalas, 1);
    });
  });

  group('HandoffService mode uji (demo)', () {
    // Mode uji dimatikan di produksi (AppConstants.handoffDemoMode = false),
    // jadi jalur demo hanya bisa diuji lewat penimpaan eksplisit. Data contoh
    // TIDAK boleh muncul lagi bagi pengguna tanpa penimpaan ini.
    final service = HandoffService(demoModeOverride: true);

    test('bawaan produksi: mode uji MATI dan memakai endpoint asli', () {
      expect(AppConstants.handoffDemoMode, isFalse,
          reason: 'endpoint produksi sudah terbukti 200 (15 Okt 2026)');
      expect(HandoffService().demoMode, isFalse);
    });

    test('mode uji aktif dan memberi data contoh + akses true', () async {
      expect(service.demoMode, isTrue);

      final hasil = await service.getAntrean();
      expect(hasil.demo, isTrue);
      expect(hasil.responsValid, isTrue);
      expect(hasil.akses, isTrue);
      expect(hasil.items, isNotEmpty);
      expect(hasil.jumlah, hasil.items.length);
    });

    test('nomor contoh fiktif (tidak pernah nomor pelanggan asli)', () async {
      final hasil = await service.getAntrean();
      for (final item in hasil.items) {
        expect(item.nomor.startsWith('6280000'), isTrue,
            reason: 'nomor contoh harus fiktif: ${item.nomor}');
        expect(item.nama.startsWith('DEMO'), isTrue);
      }
    });

    test('tandai selesai di mode uji tidak menyentuh server', () async {
      final hasil = await service.tandaiSelesai(id: 'demo-1');
      expect(hasil['status'], true);
    });
  });

  // ---------------------------------------------------------------------------
  // Jalur JARINGAN (mode nyata) dengan JSON tiruan yang PERSIS bentuk produksi.
  // Klien HTTP disuntik lewat MockClient -> uji tidak menyentuh server dan
  // tidak mengubah AppConstants.handoffDemoMode.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // BENTUK respons produksi (kunci kontrak, tab di depan JSON, bentuk alias
  // lama) dipertahankan apa adanya; ISI BARIS-nya SENGAJA disusun ulang
  // memakai data SINTETIS (nomor 6281200000001/6281200000002, nama
  // "Pelanggan Uji", kutipan rekaan). Nomor/kutipan pelanggan nyata TIDAK
  // boleh ada di repo publik.
  //
  // PENTING: badan balasan produksi diawali satu TAB (\t) sebelum '{' (quirk
  // template PHP). json.decode mengabaikannya, tetapi contoh di bawah sengaja
  // disimpan byte-exact untuk BENTUK (termasuk tab-nya) supaya perubahan
  // bentuk di server tertangkap uji ini.
  // ---------------------------------------------------------------------------

  /// Bentuk BARU hidup: user berhak (user_id=152), HTTP 200 — PRODUKSI.
  const String jsonBaru200UserBerhak =
      '\t{"status":true,"akses":true,"jumlah":0,"data":[]}';

  /// Bentuk BARU, user_id tak berhak, HTTP 403 — PRODUKSI.
  /// Catatan penting: `status` TETAP true; penolakan dibawa `akses:false`,
  /// jadi app wajib membaca `akses`, bukan `status`.
  const String jsonBaru403TakBerhak = '\t{"status":true,"akses":false,"jumlah":0,'
      '"data":[],"message":"Antrean ini hanya untuk staff dengan akses menu Rent Plan."}';

  /// Bentuk BARU tanpa user_id, HTTP 400 — PRODUKSI.
  const String jsonBaru400TanpaUserId = '\t{"status":false,"akses":false,"jumlah":0,'
      '"data":[],"message":"user_id wajib diisi."}';

  /// Bentuk ALIAS LAMA hidup: user berhak, HTTP 200 — PRODUKSI.
  const String jsonAlias200UserBerhak = '\t{"status":true,"data":'
      '{"jumlah_belum_dibalas":0,"filter_status":"belum","antrean":[]}}';

  /// Bentuk ALIAS LAMA, user_id tak berhak, HTTP 403 — PRODUKSI.
  const String jsonAlias403TakBerhak = '\t{"status":false,'
      '"message":"Antrean ini hanya untuk staff dengan akses menu Rent Plan."}';

  /// Bentuk BARU berisi DUA baris CONTOH (data sintetis, BUKAN pelanggan
  /// nyata) dengan kunci persis kontrak final: id, nomor, nama, pesan, waktu,
  /// belum_dibalas (server juga mengirim `jenis` yang belum dipakai aplikasi).
  const String jsonBaru200DenganIsiContoh = '\t{"status":true,"akses":true,"jumlah":2,"data":['
      '{"id":"2","nomor":"6281200000001","nama":"Pelanggan Uji",'
      '"pesan":"Kak, unitnya masih bisa dikirim pagi tidak ya?\\n'
      'Kalau bisa jam 07.30 sudah sampai rumah saya, soalnya saya berangkat kerja pagi",'
      '"waktu":"2026-10-14 09:12:34","belum_dibalas":1,"jenis":"pengantaran"},'
      '{"id":"1","nomor":"6281200000002","nama":"Pelanggan Uji 2","pesan":"Ini admin yang beda ya",'
      '"waktu":"2026-10-14 09:10:05","belum_dibalas":1,"jenis":"minta_admin"}]}';

  /// Bentuk ALIAS LAMA berisi DUA baris CONTOH (data sintetis). Kunci backend
  /// HRIS: `phone`, `kutipan`, `jam` (dipetakan parser); sisanya (jenis,
  /// jam_wib, status, sudah_dibalas, ...) belum dipakai aplikasi tetapi tetap
  /// disertakan supaya BENTUK balasan benar-benar sama seperti server.
  const String jsonAlias200DenganIsiContoh = '\t{"status":true,"data":'
      '{"jumlah_belum_dibalas":2,"filter_status":"belum","antrean":['
      '{"id":2,"phone":"6281200000001","nama":"Pelanggan Uji","jenis":"pengantaran",'
      '"kutipan":"Kak, unitnya masih bisa dikirim pagi tidak ya?\\n'
      'Kalau bisa jam 07.30 sudah sampai rumah saya, soalnya saya berangkat kerja pagi",'
      '"jam":"2026-10-14 09:12:34","jam_wib":"09:12","status":"belum","sudah_dibalas":false,'
      '"ditangani_oleh":null,"penangan":null,"ditangani_pada":null,"catatan":null,'
      '"wa":"https://wa.me/6281200000001"},'
      '{"id":1,"phone":"6281200000002","nama":"Pelanggan Uji 2","jenis":"minta_admin",'
      '"kutipan":"Ini admin yang beda ya","jam":"2026-10-14 09:10:05","jam_wib":"09:10",'
      '"status":"belum","sudah_dibalas":false,"ditangani_oleh":null,"penangan":null,'
      '"ditangani_pada":null,"catatan":null,"wa":"https://wa.me/6281200000002"}]}}';

  const String jsonTolak403 = '''
{"status":false,"message":"Antrean ini hanya untuk staff dengan akses menu Rent Plan."}
''';

  const String jsonSelesai = '''
{"status":true,"message":"Antrean ditandai sudah dibalas.","data":{"handoff_id":1,"ditangani_oleh":152}}
''';

  group('HandoffService jalur jaringan (JSON produksi tiruan)', () {
    test('membaca bentuk produksi data.antrean[] + memakai path FINAL', () async {
      final List<Uri> dipanggil = <Uri>[];
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async {
          dipanggil.add(request.url);
          return http.Response(jsonAlias200DenganIsiContoh, 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      final hasil = await service.getAntrean(limit: 50);

      expect(dipanggil.single.path, '/HRIS/mobileapi/bot/handoff-antrean');
      expect(dipanggil.single.queryParameters['user_id'], '152');
      expect(dipanggil.single.queryParameters['limit'], '50');
      expect(dipanggil.single.queryParameters['offset'], '0');

      expect(hasil.akses, isTrue);
      expect(hasil.responsValid, isTrue);
      expect(hasil.demo, isFalse);
      expect(hasil.jumlah, 2);
      expect(hasil.items, hasLength(2));

      final item = hasil.items.first;
      expect(item.id, '2');
      expect(item.nomor, '6281200000001');
      expect(item.nama, 'Pelanggan Uji');
      expect(item.pesan, startsWith('Kak, unitnya masih bisa'));
      expect(item.pesan, contains('jam 07.30 sudah sampai rumah'));
      expect(item.waktu, DateTime.parse('2026-10-14 09:12:34'));
      expect(item.belumDibalas, 1);

      // `kutipan`/`phone`/`jam` backend HRIS dipetakan ke `pesan`/`nomor`/`waktu`.
      final kedua = hasil.items[1];
      expect(kedua.id, '1');
      expect(kedua.nomor, '6281200000002');
      expect(kedua.pesan, 'Ini admin yang beda ya');
      expect(kedua.waktu, DateTime.parse('2026-10-14 09:10:05'));
    });

    test('HTTP 403 (tanpa hak menu rent_plan) -> akses false, bukan galat', () async {
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '900',
        client: MockClient((request) async =>
            http.Response(jsonTolak403, 403, headers: {'content-type': 'application/json'})),
      );

      final hasil = await service.getAntrean();

      expect(hasil.akses, isFalse);
      expect(hasil.responsValid, isTrue);
      expect(hasil.items, isEmpty);
      expect(hasil.pesan, contains('Rent Plan'));
    });

    test('turun ke alias lama hanya saat path final 404', () async {
      final List<String> jalur = <String>[];
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async {
          jalur.add(request.url.path);
          if (request.url.path.endsWith('/bot/handoff-antrean')) {
            return http.Response('not found', 404, headers: {'content-type': 'text/html'});
          }
          return http.Response(jsonAlias200DenganIsiContoh, 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      final hasil = await service.getAntrean();

      expect(jalur, [
        '/HRIS/mobileapi/bot/handoff-antrean',
        '/HRIS/mobileapi/get_handoff_antrean',
      ]);
      expect(hasil.akses, isTrue);
      expect(hasil.jumlah, 2);
    });

    test('bentuk pendek (data sebagai daftar langsung) tetap didukung', () async {
      const String bentukPendek =
          '{"status":true,"akses":true,"jumlah":2,"data":[{"id":"9","nomor":"6281","nama":"A"},'
          '{"id":"10","nomor":"6282","nama":"B"}]}';
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async =>
            http.Response(bentukPendek, 200, headers: {'content-type': 'application/json'})),
      );

      final hasil = await service.getAntrean();
      expect(hasil.akses, isTrue);
      expect(hasil.jumlah, 2);
      expect(hasil.items.map((e) => e.id), ['9', '10']);
    });

    test('tanpa field akses pada balasan 200 -> dianggap berhak', () async {
      const String tanpaAkses =
          '{"status":true,"data":{"jumlah_belum_dibalas":0,"antrean":[]}}';
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async =>
            http.Response(tanpaAkses, 200, headers: {'content-type': 'application/json'})),
      );

      final hasil = await service.getAntrean();
      expect(hasil.akses, isTrue);
      expect(hasil.jumlah, 0);
      expect(hasil.items, isEmpty);
    });

    test('tandai selesai: POST user_id + id + handoff_id ke /bot/handoff-selesai',
        () async {
      final List<http.Request> kiriman = <http.Request>[];
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async {
          kiriman.add(request);
          return http.Response(jsonSelesai, 200, headers: {'content-type': 'application/json'});
        }),
      );

      final hasil = await service.tandaiSelesai(id: '1', catatan: 'Sudah dihubungi');

      expect(kiriman.single.method, 'POST');
      expect(kiriman.single.url.path, '/HRIS/mobileapi/bot/handoff-selesai');
      final Map<String, String> body = Uri.splitQueryString(kiriman.single.body);
      expect(body['user_id'], '152');
      expect(body['id'], '1');
      expect(body['handoff_id'], '1');
      expect(body['catatan'], 'Sudah dihubungi');
      expect(hasil['status'], true);
    });

    test('tandai selesai turun ke alias /tandai_handoff_dibalas saat 404', () async {
      final List<String> jalur = <String>[];
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async {
          jalur.add(request.url.path);
          if (request.url.path.endsWith('/bot/handoff-selesai')) {
            return http.Response('not found', 404, headers: {'content-type': 'text/html'});
          }
          return http.Response(jsonSelesai, 200, headers: {'content-type': 'application/json'});
        }),
      );

      final hasil = await service.tandaiSelesai(id: '1');

      expect(jalur, [
        '/HRIS/mobileapi/bot/handoff-selesai',
        '/HRIS/mobileapi/tandai_handoff_dibalas',
      ]);
      expect(hasil['status'], true);
    });

    test('balasan bukan JSON tidak dianggap sukses', () async {
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async =>
            http.Response('<html>login</html>', 200, headers: {'content-type': 'text/html'})),
      );

      final hasil = await service.getAntrean();
      expect(hasil.akses, isFalse);
      expect(hasil.items, isEmpty);
      expect(hasil.pesan, contains('tidak dikenali'));
    });

    test('jumlah tetap jumlah server walau badge meminta limit=1', () async {
      // Badge di app bar memanggil getAntrean(limit: 1) (satu baris), tetapi
      // `jumlah` yang dilaporkan harus tetap total dari server — bukan dipotong
      // oleh `limit`. Balasan di bawah meniru itu: jumlah 2, data 1 baris.
      const String satuBaris = '\t{"status":true,"akses":true,"jumlah":2,"data":['
          '{"id":"2","nomor":"6281200000001","nama":"Pelanggan Uji",'
          '"pesan":"Kak, unitnya masih bisa dikirim pagi tidak ya?",'
          '"waktu":"2026-10-14 09:12:34","belum_dibalas":1}]}';
      final List<Uri> dipanggil = <Uri>[];
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async {
          dipanggil.add(request.url);
          return http.Response(satuBaris, 200, headers: {'content-type': 'application/json'});
        }),
      );

      final hasil = await service.getAntrean(limit: 1);

      expect(dipanggil.single.queryParameters['limit'], '1');
      expect(hasil.items, hasLength(1));
      expect(hasil.jumlah, 2);
      expect(hasil.akses, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Uji terhadap BENTUK respons produksi (byte-exact, termasuk tab di depan
  // JSON; ISI baris memakai data sintetis — lihat catatan di atas). Tujuannya:
  // memastikan parser benar-benar cocok dengan bentuk yang dikirim server, dan
  // bahwa 403/400 diperlakukan sebagai "tanpa akses", BUKAN sebagai galat
  // sambungan ("Tidak dapat terhubung").
  // ---------------------------------------------------------------------------
  group('HandoffService vs bentuk respons produksi', () {
    /// Semua balasan produksi harus terurai tanpa galat sambungan.
    void bukanGalatSambungan(HandoffRingkasan hasil) {
      expect(hasil.pesan ?? '', isNot(contains('Tidak dapat terhubung')),
          reason: 'server menjawab; ini bukan kegagalan koneksi');
    }

    test('bentuk BARU 200 (user berhak) — mode uji mati, tidak ada data contoh',
        () async {
      // Sengaja TANPA demoModeOverride: membuktikan bawaan produksi benar-benar
      // memanggil endpoint dan bukan mengembalikan data contoh.
      final List<Uri> dipanggil = <Uri>[];
      final service = HandoffService(
        userIdProvider: () async => '152',
        client: MockClient((request) async {
          dipanggil.add(request.url);
          return http.Response(jsonBaru200UserBerhak, 200,
              headers: {'content-type': 'application/json; charset=UTF-8'});
        }),
      );

      final hasil = await service.getAntrean();

      expect(dipanggil.single.path, '/HRIS/mobileapi/bot/handoff-antrean');
      expect(hasil.demo, isFalse, reason: 'data contoh tidak boleh muncul di produksi');
      expect(hasil.akses, isTrue);
      expect(hasil.responsValid, isTrue);
      expect(hasil.jumlah, 0);
      expect(hasil.items, isEmpty);
      bukanGalatSambungan(hasil);
    });

    test('bentuk BARU 200 berisi data — kunci kontrak final terbaca', () async {
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async => http.Response(jsonBaru200DenganIsiContoh, 200,
            headers: {'content-type': 'application/json; charset=UTF-8'})),
      );

      final hasil = await service.getAntrean();

      expect(hasil.akses, isTrue);
      expect(hasil.jumlah, 2);
      expect(hasil.items, hasLength(2));
      final item = hasil.items.first;
      expect(item.id, '2');
      expect(item.nomor, '6281200000001');
      expect(item.nama, 'Pelanggan Uji');
      expect(item.pesan, startsWith('Kak, unitnya masih bisa'));
      expect(item.pesan, contains('jam 07.30 sudah sampai rumah'));
      expect(item.waktu, DateTime.parse('2026-10-14 09:12:34'));
      expect(item.belumDibalas, 1);
      expect(hasil.items[1].id, '1');
      expect(hasil.items[1].nomor, '6281200000002');
      expect(hasil.items[1].pesan, 'Ini admin yang beda ya');
      bukanGalatSambungan(hasil);
    });

    test('bentuk ALIAS LAMA 200 (user berhak) — jumlah 0, bukan galat', () async {
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async => http.Response(jsonAlias200UserBerhak, 200,
            headers: {'content-type': 'application/json; charset=UTF-8'})),
      );

      final hasil = await service.getAntrean();

      expect(hasil.akses, isTrue);
      expect(hasil.responsValid, isTrue);
      expect(hasil.jumlah, 0);
      expect(hasil.items, isEmpty);
      bukanGalatSambungan(hasil);
    });

    test('bentuk BARU 403 (status:true, akses:false) -> tanpa akses, bukan galat',
        () async {
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '900',
        client: MockClient((request) async =>
            http.Response(jsonBaru403TakBerhak, 403,
                headers: {'content-type': 'application/json; charset=UTF-8'})),
      );

      final hasil = await service.getAntrean();

      expect(hasil.akses, isFalse);
      expect(hasil.responsValid, isTrue,
          reason: 'server menjawab dengan benar, hanya menolak akses');
      expect(hasil.items, isEmpty);
      expect(hasil.jumlah, 0);
      expect(hasil.pesan, contains('Rent Plan'));
      bukanGalatSambungan(hasil);
    });

    test('bentuk ALIAS LAMA 403 (status:false) -> tanpa akses, bukan galat', () async {
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '900',
        client: MockClient((request) async =>
            http.Response(jsonAlias403TakBerhak, 403,
                headers: {'content-type': 'application/json; charset=UTF-8'})),
      );

      final hasil = await service.getAntrean();

      expect(hasil.akses, isFalse);
      expect(hasil.responsValid, isTrue);
      expect(hasil.items, isEmpty);
      expect(hasil.pesan, contains('Rent Plan'));
      bukanGalatSambungan(hasil);
    });

    test('bentuk BARU 400 tanpa user_id -> pesan server, bukan galat sambungan',
        () async {
      final service = HandoffService(
        demoModeOverride: false,
        userIdProvider: () async => '152',
        client: MockClient((request) async =>
            http.Response(jsonBaru400TanpaUserId, 400,
                headers: {'content-type': 'application/json; charset=UTF-8'})),
      );

      final hasil = await service.getAntrean();

      expect(hasil.akses, isFalse);
      expect(hasil.responsValid, isTrue);
      expect(hasil.pesan, 'user_id wajib diisi.');
      bukanGalatSambungan(hasil);
    });
  });
}
