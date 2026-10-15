// Uji cepat untuk adaptor "Pesan Perlu Dibalas" — berjalan TANPA backend
// karena memakai MODE UJI (data contoh) pada HandoffService.
//
// Jalankan: flutter test test/handoff_service_test.dart

import 'package:flutter_test/flutter_test.dart';
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
    final service = HandoffService();

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
}
