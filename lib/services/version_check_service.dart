import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'log_service.dart';

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
  static const String _updateUrl = 'https://foxgeen.com/HRIS/mobileapi/status';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    final latestUpdate = await getLatestVersionInfo();
    if (latestUpdate == null) return null;

    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion =
        "${packageInfo.version}+${packageInfo.buildNumber}";

    if (_isVersionNewer(currentVersion, latestUpdate.version)) {
      return latestUpdate;
    }
    return null;
  }

  static Future<AppUpdateInfo?> getLatestVersionInfo() async {
    try {
      final response = await http
          .get(Uri.parse(_updateUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both old flat structure and new nested structure
        if (data['version_info'] != null) {
          return AppUpdateInfo.fromJson(data['version_info']);
        }
        // Fallback for direct app_version endpoint or matching structure
        return AppUpdateInfo.fromJson(data);
      } else {
        Log.w('VersionCheckService: Server returned ${response.statusCode}');
      }
    } catch (e) {
      Log.e('VersionCheckService: Error fetching info: $e');
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
