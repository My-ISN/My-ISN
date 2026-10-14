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

  /// Helper: buat storage instance dengan opsi standar
  static FlutterSecureStorage get storage => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}
