import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../localization/app_localizations.dart';
import '../constants.dart';
import '../widgets/secondary_app_bar.dart';

class InternetDiagnosisPage extends StatefulWidget {
  const InternetDiagnosisPage({super.key});

  @override
  State<InternetDiagnosisPage> createState() => _InternetDiagnosisPageState();
}

class _InternetDiagnosisPageState extends State<InternetDiagnosisPage> {
  int _currentStep = 0;
  bool _step1Success = false;
  bool _step2Success = false;
  String? _step1Error;
  String? _step2Error;
  String _latency = '-';

  final Color _primaryColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _startDiagnosis();
  }

  Future<void> _startDiagnosis() async {
    // Step 1: Check Server Status
    setState(() => _currentStep = 1);
    try {
      final startTime = DateTime.now();
      final response = await http
          .get(Uri.parse('${AppConstants.baseUrl}/status'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime).inMilliseconds;

        setState(() {
          _step1Success = true;
          _latency = '$duration ms';
        });
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step1Error = 'diagnosis.internet_error'.tr(context));
      }
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    // Step 2: Stability Test (Multiple requests)
    if (mounted) setState(() => _currentStep = 2);
    try {
      int successCount = 0;
      for (int i = 0; i < 3; i++) {
        final response = await http
            .get(Uri.parse('${AppConstants.baseUrl}/status'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) successCount++;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (successCount >= 2) {
        if (mounted) setState(() => _step2Success = true);
      } else {
        throw Exception('Connection unstable');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step2Error = 'diagnosis.internet_error'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(title: 'diagnosis.internet_title'.tr(context)),
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
                child: Icon(Icons.wifi, size: 60, color: _primaryColor),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'diagnosis.internet_checking'.tr(context),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'diagnosis.internet_verifying'.tr(context),
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
                      'diagnosis.server_status'.tr(context),
                      'diagnosis.server_desc'.tr(context),
                      _currentStep >= 1,
                      _step1Success,
                      _step1Error,
                    ),
                    _buildDivider(),
                    _buildStep(
                      'diagnosis.latency'.tr(context),
                      '${'diagnosis.latency_desc'.tr(context)} ($_latency)',
                      _currentStep >= 2,
                      _step2Success,
                      _step2Error,
                    ),
                  ],
                ),
              ),
            ),
            if (_step2Success)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'diagnosis.internet_success'.tr(context),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
