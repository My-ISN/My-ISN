import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/app_localizations.dart';
import '../services/log_service.dart';
import '../services/version_check_service.dart';

class UpdateDialogContent extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialogContent({
    super.key,
    required this.updateInfo,
  });

  @override
  State<UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<UpdateDialogContent> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  /// Membuka tautan pembaruan dari JSON.
  ///
  /// Bila tautan menuju Google Play, skema `market://` dicoba lebih dulu supaya
  /// halaman aplikasi langsung dibuka di aplikasi Play Store; bila tidak
  /// tersedia, URL asli dari JSON yang dipakai.
  Future<bool> _openUpdateLink(String url) async {
    if (url.contains('play.google.com') || url.startsWith('market://')) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final marketUri = Uri.parse(
          'market://details?id=${packageInfo.packageName}',
        );
        if (await canLaunchUrl(marketUri)) {
          return await launchUrl(
            marketUri,
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e) {
        Log.w('UpdateDialog: gagal membuka market:// : $e');
      }
    }

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      Log.w('UpdateDialog: gagal membuka tautan pembaruan: $e');
    }
    return false;
  }

  Future<void> _startUpdate() async {
    // `tautan` dari JSON versi terbaru.
    final String url = widget.updateInfo.downloadLink.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage =
          'Tautan pembaruan belum tersedia. Silakan coba lagi nanti.');
      return;
    }

    // Tautan non-APK (mis. halaman Google Play) -> buka lewat Play Store/browser.
    if (!url.toLowerCase().contains('.apk')) {
      final bool opened = await _openUpdateLink(url);
      if (!mounted) return;
      if (opened) {
        Navigator.pop(context, 'update');
      } else {
        setState(() => _errorMessage =
            'Tidak dapat membuka tautan pembaruan. Silakan coba lagi.');
      }
      return;
    }

    // Direct APK installation flow
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      _otaSubscription = OtaUpdate()
          .execute(
        url,
        destinationFilename: 'myisn_update.apk',
      )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              setState(() {
                _progress = double.tryParse(event.value ?? '0') ?? 0.0;
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _isDownloading = false;
                _progress = 100.0;
              });
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Proses pembaruan sedang berjalan.';
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'main.grant_permission'.tr(context);
              });
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            default:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'main.download_failed'.tr(context);
              });
              break;
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _errorMessage = 'main.download_failed'.tr(context);
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'main.download_failed'.tr(context);
        });
      }
    }
  }

  void _cancelDownload() {
    _otaSubscription?.cancel();
    setState(() {
      _isDownloading = false;
      _progress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String versionLabel = widget.updateInfo.version.split('+')[0];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9A2E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update,
                    color: Color(0xFFFF9A2E),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'main.update_available'.tr(context),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isDownloading) ...[
                    Text(
                      '${'main.new_version'.tr(context)}: $versionLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.updateInfo.releaseNotes != null &&
                        widget.updateInfo.releaseNotes!.trim().isNotEmpty) ...[
                      Text(
                        'announcement.whats_new'.tr(context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          widget.updateInfo.releaseNotes!,
                          style: TextStyle(
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'main.update_desc'.tr(context),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 80,
                            width: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 6,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9A2E)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'main.downloading'.tr(
                              context,
                              args: {'progress': _progress.toStringAsFixed(0)},
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: LinearProgressIndicator(
                              value: _progress / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF9A2E)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_progress.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                if (!_isDownloading) ...[
                  // Tombol "Nanti" hanya muncul bila update tidak wajib.
                  if (!widget.updateInfo.isForceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, 'later'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'main.later'.tr(context),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9A2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _errorMessage != null
                            ? 'main.try_again'.tr(context)
                            : 'main.update_now'.tr(context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  if (!widget.updateInfo.isForceUpdate)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelDownload,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'main.cancel'.tr(context),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
