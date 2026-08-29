import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConstants {
  static const String serverRoot = 'https://istanakomputer.com/HRIS';
  static const String baseUrl = '$serverRoot/mobileapi';

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
