import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConstants {
  static const String serverRoot = 'https://istanakomputer.com/HRIS';
  static const String baseUrl = '$serverRoot/mobileapi';

  /// Endpoint JSON versi aplikasi terbaru (dibuat di sisi HRIS/ERP).
  /// Bentuk respons: {"versi":"1.3.1","build":26,"wajib":false,"catatan":"...","tautan":"..."}
  static const String appVersionUrl = '$serverRoot/erp/app-version';

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
