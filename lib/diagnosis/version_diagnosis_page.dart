import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/app_localizations.dart';
import '../services/version_check_service.dart';
import '../widgets/secondary_app_bar.dart';

class VersionDiagnosisPage extends StatefulWidget {
  const VersionDiagnosisPage({super.key});

  @override
  State<VersionDiagnosisPage> createState() => _VersionDiagnosisPageState();
}

class _VersionDiagnosisPageState extends State<VersionDiagnosisPage> {
  int _currentStep = 0;
  bool _step1Success = false;
  bool _step2Success = false;
  bool _step3Success = false;
  String? _step1Error;
  String? _step2Error;
  String? _step3Error;

  String? _localVersion;
  String? _serverVersion;
  String? _downloadLink;
  bool _isUpdateNeeded = false;

  final Color _primaryColor = Colors.teal;

  @override
  void initState() {
    super.initState();
    _startDiagnosis();
  }

  Future<void> _startDiagnosis() async {
    // Step 1: Get Local Version
    setState(() => _currentStep = 1);
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _localVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      setState(() => _step1Success = true);
    } catch (e) {
      if (mounted) setState(() => _step1Error = e.toString());
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    // Step 2: Get Server Version
    if (mounted) setState(() => _currentStep = 2);
    try {
      final latestUpdate = await VersionCheckService.getLatestVersionInfo();
      if (latestUpdate != null) {
        _serverVersion = latestUpdate.version;
        _downloadLink = latestUpdate.downloadLink;
        if (mounted) setState(() => _step2Success = true);
      } else {
        throw Exception('diagnosis.version_fetch_failed'.tr(context));
      }
    } catch (e) {
      if (mounted) setState(() => _step2Error = e.toString());
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    // Step 3: Compare Status
    if (mounted) setState(() => _currentStep = 3);
    try {
      if (_localVersion != null && _serverVersion != null) {
        // Logic to check if update is needed (server vs local)
        _isUpdateNeeded = _compareVersions(_localVersion!, _serverVersion!);
        if (mounted) setState(() => _step3Success = true);
      }
    } catch (e) {
      if (mounted) setState(() => _step3Error = e.toString());
    }
  }

  bool _compareVersions(String current, String latest) {
    try {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(title: 'diagnosis.version_title'.tr(context)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_alt_outlined,
                  size: 60,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'diagnosis.version_checking'.tr(context),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'diagnosis.version_verifying'.tr(context),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStep(
                      'diagnosis.current_version'.tr(context),
                      _localVersion != null
                          ? 'v${_localVersion!.split('+')[0]}'
                          : 'diagnosis.current_version_desc'.tr(context),
                      _currentStep >= 1,
                      _step1Success,
                      _step1Error,
                    ),
                    _buildDivider(),
                    _buildStep(
                      'diagnosis.latest_version'.tr(context),
                      _serverVersion != null
                          ? 'v${_serverVersion!.split('+')[0]}'
                          : 'diagnosis.latest_version_desc'.tr(context),
                      _currentStep >= 2,
                      _step2Success,
                      _step2Error,
                    ),
                    _buildDivider(),
                    _buildStep(
                      'diagnosis.update_status'.tr(context),
                      _currentStep < 3
                          ? '...'
                          : (_isUpdateNeeded
                                ? 'diagnosis.update_needed'.tr(context)
                                : 'diagnosis.up_to_date'.tr(context)),
                      _currentStep >= 3,
                      _step3Success,
                      _step3Error,
                    ),
                  ],
                ),
              ),
            ),
            if (_step3Success) ...[
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isUpdateNeeded
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isUpdateNeeded
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isUpdateNeeded
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: _isUpdateNeeded ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isUpdateNeeded
                              ? 'diagnosis.update_needed'.tr(context)
                              : 'diagnosis.up_to_date'.tr(context),
                          style: TextStyle(
                            color: _isUpdateNeeded
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isUpdateNeeded && _downloadLink != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(_downloadLink!);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      label: Text(
                        'main.update_now'.tr(context),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 40,
      indent: 44,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
    );
  }

  Widget _buildStep(
    String title,
    String subtitle,
    bool isStarted,
    bool isSuccess,
    String? error,
  ) {
    Widget icon;
    if (error != null) {
      icon = const Icon(Icons.cancel_outlined, color: Colors.red, size: 28);
    } else if (isSuccess) {
      icon = const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28);
    } else if (isStarted) {
      icon = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
        ),
      );
    } else {
      icon = Icon(
        Icons.radio_button_unchecked_rounded,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        size: 28,
      );
    }

    return Row(
      children: [
        icon,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isStarted
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                error ?? subtitle,
                style: TextStyle(
                  color: error != null
                      ? Colors.red
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
