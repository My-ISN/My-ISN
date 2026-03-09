import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String version;
  final String downloadLink;
  final bool isForceUpdate;
  final String? releaseNotes;

  AppUpdateInfo({
    required this.version,
    required this.downloadLink,
    this.isForceUpdate = false,
    this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] ?? '0.0.0',
      downloadLink: json['link'] ?? '',
      isForceUpdate: json['force'] ?? false,
      releaseNotes: json['notes'],
    );
  }
}

class VersionCheckService {
  // Replace with actual API endpoint when available
  static const String _updateUrl =
      'https://foxgeen.com/HRIS/mobileapi/app_version';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      // 1. Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 2. Fetch latest version from server
      // Note: This is an assumption of how the API will look.
      // For now, it might fail if the endpoint doesn't exist yet.
      final response = await http
          .get(Uri.parse(_updateUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestUpdate = AppUpdateInfo.fromJson(data);

        // 3. Compare versions
        if (_isVersionNewer(currentVersion, latestUpdate.version)) {
          return latestUpdate;
        }
      }
    } catch (e) {
      print('Error checking for update: $e');
    }
    return null;
  }

  static bool _isVersionNewer(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      int currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestParts[i] > currentPart) return true;
      if (latestParts[i] < currentPart) return false;
    }
    return false;
  }
}
