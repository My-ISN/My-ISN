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
  /// Ubah ke `false` setelah endpoint di server aktif (terbukti menjawab 200
  /// untuk user_id yang berhak) dan hak akses `mobile_rent_plan_enable` sudah
  /// diisi untuk staf yang berhak. 15 Okt 2026: BELUM terbukti — keempat
  /// endpoint (baru & alias) masih 404 di produksi, jadi tetap `true`.
  static const bool handoffDemoMode = true;

  /// Helper: buat storage instance dengan opsi standar
  static FlutterSecureStorage get storage => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}
