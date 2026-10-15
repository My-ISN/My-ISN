import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConstants {
  static const String serverRoot = 'https://istanakomputer.com/HRIS';
  static const String baseUrl = '$serverRoot/mobileapi';

  /// Endpoint JSON versi aplikasi terbaru (dibuat di sisi HRIS/ERP).
  /// Bentuk respons: {"versi":"1.3.1","build":26,"wajib":false,"catatan":"...","tautan":"..."}
  /// `?format=json` WAJIB: tanpa itu server menjawab halaman login (307/HTML),
  /// bukan JSON, sehingga fitur update di HP tidak pernah muncul (galatnya
  /// diabaikan diam-diam).
  static const String appVersionUrl = '$serverRoot/erp/app-version?format=json';

  /// Gunakan opsi ini secara konsisten di SEMUA FlutterSecureStorage instance
  /// di seluruh app agar storage backend Android sama (encryptedSharedPreferences).
  static const AndroidOptions kAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// MODE UJI fitur "Pesan Perlu Dibalas" (menu hanya untuk staf ber-akses
  /// menu rent_plan).
  ///
  /// `true`  = aplikasi memakai DATA CONTOH lokal sehingga bisa dibangun &
  ///           diuji sebelum endpoint backend siap (tidak menyentuh server,
  ///           nomor contoh fiktif 6280000xxxxxx).
  /// `false` = memakai endpoint asli:
  ///           GET  $baseUrl/bot/handoff-antrean?user_id=&limit=&offset=
  ///           POST $baseUrl/bot/handoff-selesai  (user_id, id, catatan)
  ///           (bila server menjawab 404, adaptor otomatis mencoba alias lama
  ///           $baseUrl/get_handoff_antrean & $baseUrl/tandai_handoff_dibalas)
  ///
  /// 15 Okt 2026 ±18:50 WIB — sudah TERBUKTI 200 di produksi, karena itu
  /// nilai sekarang `false` (mode uji dimatikan):
  ///   GET .../bot/handoff-antrean?user_id=152 -> 200
  ///       {"status":true,"akses":true,"jumlah":0,"data":[]}
  ///   user_id tak berhak                      -> 403 (akses:false)
  ///   tanpa user_id                           -> 400 "user_id wajib diisi."
  /// Alias lama /get_handoff_antrean juga sudah hidup (200 untuk user berhak,
  /// 403 untuk yang tidak berhak), jadi cadangan jatuh-ke-alias saat 404 tetap
  /// tidak terpakai dan aman.
  static const bool handoffDemoMode = false;

  /// Helper: buat storage instance dengan opsi standar
  static FlutterSecureStorage get storage => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}
