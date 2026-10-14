import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'log_service.dart';
import '../constants.dart';


class AppUpdateInfo {
  final String version;
  final int? build;
  final String downloadLink;
  final bool isForceUpdate;
  final String? releaseNotes;

  AppUpdateInfo({
    required this.version,
    required this.downloadLink,
    this.build,
    this.isForceUpdate = false,
    this.releaseNotes,
  });

  /// Mendukung dua bentuk JSON:
  ///  - Endpoint baru `/erp/app-version`: {versi, build, wajib, catatan, tautan}
  ///  - Endpoint lama: {version, link, force, notes}
  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['versi'] ?? json['version'] ?? '0.0.0';
    final rawLink = json['tautan'] ?? json['link'] ?? '';
    final rawForce = json['wajib'] ?? json['force'] ?? false;
    final rawNotes = json['catatan'] ?? json['notes'];
    final rawBuild = json['build'] ?? json['build_number'];

    return AppUpdateInfo(
      version: rawVersion.toString(),
      build: rawBuild == null ? null : int.tryParse(rawBuild.toString()),
      downloadLink: rawLink.toString(),
      isForceUpdate: rawForce == true ||
          rawForce.toString().toLowerCase() == 'true' ||
          rawForce.toString() == '1',
      releaseNotes: rawNotes?.toString(),
    );
  }
}

class VersionCheckService {
  // Sumber versi terbaru: endpoint JSON HRIS/ERP.
  static const String _updateUrl = AppConstants.appVersionUrl;

  // Timeout pendek supaya aplikasi tidak menunggu lama bila server lambat/mati.
  static const Duration _timeout = Duration(seconds: 5);

  /// Kunci penyimpanan versi yang sudah ditolak pengguna ("Nanti").
  static const String _dismissedVersionKey = 'dismissed_app_update';

  /// Storage yang sama dengan bagian lain aplikasi (encryptedSharedPreferences).
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AppConstants.kAndroidOptions,
  );

  /// Mengembalikan [AppUpdateInfo] bila ada versi lebih baru dari aplikasi
  /// yang terpasang, atau `null` bila tidak ada / gagal memeriksa.
  ///
  /// Semua kesalahan (timeout, koneksi, JSON rusak, dll.) diabaikan agar
  /// aplikasi tetap berjalan normal.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    final latestUpdate = await getLatestVersionInfo();
    if (latestUpdate == null) return null;

    PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      Log.w('VersionCheckService: gagal membaca PackageInfo: $e');
      return null;
    }

    final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    AppUpdateInfo? newer;

    // Bandingkan versionCode (build number) bila server mengirim `build`.
    if (latestUpdate.build != null) {
      if (latestUpdate.build! > currentBuild) newer = latestUpdate;
    } else {
      // Fallback: bandingkan string versi bila `build` tidak tersedia.
      final String currentVersion =
          "${packageInfo.version}+${packageInfo.buildNumber}";
      if (_isVersionNewer(currentVersion, latestUpdate.version)) {
        newer = latestUpdate;
      }
    }

    if (newer == null) return null;

    // Update wajib selalu ditampilkan. Update opsional tidak diulang bila
    // pengguna sudah menekan "Nanti" untuk versi/build yang sama.
    if (!newer.isForceUpdate && await _isDismissed(newer)) {
      return null;
    }
    return newer;
  }

  /// Menandai pembaruan sebagai "sudah ditolak" (tombol "Nanti") supaya dialog
  /// tidak muncul berulang-ulang di setiap pembukaan aplikasi.
  static Future<void> markAsDismissed(AppUpdateInfo info) async {
    try {
      await _storage.write(
        key: _dismissedVersionKey,
        value: _dismissKey(info),
      );
    } catch (e) {
      Log.w('VersionCheckService: gagal menyimpan status "Nanti": $e');
    }
  }

  /// `true` bila pengguna sudah menekan "Nanti" untuk versi/build yang sama.
  static Future<bool> _isDismissed(AppUpdateInfo info) async {
    try {
      final String? dismissed = await _storage.read(key: _dismissedVersionKey);
      return dismissed != null && dismissed == _dismissKey(info);
    } catch (e) {
      Log.w('VersionCheckService: gagal membaca status "Nanti": $e');
      return false;
    }
  }

  /// Penanda versi: pakai versionCode (`build`) bila ada, jika tidak pakai
  /// string versi. Versi yang lebih baru menampilkan dialog kembali.
  static String _dismissKey(AppUpdateInfo info) =>
      info.build?.toString() ?? info.version;

  /// Mengambil JSON versi terbaru. Mengembalikan `null` pada SEMUA kegagalan.
  static Future<AppUpdateInfo?> getLatestVersionInfo() async {
    try {
      final response = await http
          .get(Uri.parse(_updateUrl))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          // Dukung bentuk bertingkat lama {version_info: {...}} dan bentuk datar.
          if (data['version_info'] != null) {
            return AppUpdateInfo.fromJson(
              Map<String, dynamic>.from(data['version_info']),
            );
          }
          return AppUpdateInfo.fromJson(data);
        }
      } else {
        Log.w('VersionCheckService: Server returned ${response.statusCode}');
      }
    } catch (e) {
      // Endpoint mati / tidak terjangkau: abaikan, aplikasi tetap jalan normal.
      Log.w('VersionCheckService: gagal mengambil info versi: $e');
    }
    return null;
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      // Normalize versions (remove build number + if present)
      String cleanCurrent = current.split('+')[0];
      String cleanLatest = latest.split('+')[0];

      List<int> currentParts = cleanCurrent
          .split('.')
          .map((s) => int.tryParse(s) ?? 0)
          .toList();
      List<int> latestParts = cleanLatest
          .split('.')
          .map((s) => int.tryParse(s) ?? 0)
          .toList();

      for (int i = 0; i < latestParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }

      // If version parts are equal, check build number if available
      if (current.contains('+') && latest.contains('+')) {
        int currentBuild = int.tryParse(current.split('+')[1]) ?? 0;
        int latestBuild = int.tryParse(latest.split('+')[1]) ?? 0;
        return latestBuild > currentBuild;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
