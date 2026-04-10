import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';
import '../constants.dart';
import '../widgets/secondary_app_bar.dart';

class NotificationDiagnosisPage extends StatefulWidget {
  const NotificationDiagnosisPage({super.key});

  @override
  State<NotificationDiagnosisPage> createState() =>
      _NotificationDiagnosisPageState();
}

class _NotificationDiagnosisPageState extends State<NotificationDiagnosisPage> {
  int _currentStep = 0;
  bool _step1Success = false;
  bool _step2Success = false;
  bool _step3Success = false;
  String? _step1Error;
  String? _step2Error;
  String? _step3Error;

  final Color _primaryColor = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _startDiagnosis();
  }

  Future<void> _startDiagnosis() async {
    // Step 1: Check Permission
    setState(() => _currentStep = 1);
    try {
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        setState(() => _step1Success = true);
      } else {
        throw Exception('diagnosis.permission_denied'.tr(context));
      }
    } catch (e) {
      if (mounted) setState(() => _step1Error = e.toString());
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    // Step 2: Check Token
    if (mounted) setState(() => _currentStep = 2);
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        if (mounted) setState(() => _step2Success = true);
        _sendTestNotification(token);
      } else {
        throw Exception('diagnosis.token_failed'.tr(context));
      }
    } catch (e) {
      if (mounted) setState(() => _step2Error = e.toString());
      return;
    }
  }

  Future<void> _sendTestNotification(String token) async {
    // Step 3: Send Test
    if (mounted) setState(() => _currentStep = 3);
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}/test_push_direct?token=$token',
      );
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) setState(() => _step3Success = true);
      } else {
        throw Exception(data['message'] ?? 'diagnosis.test_failed'.tr(context));
      }
    } catch (e) {
      if (mounted) setState(() => _step3Error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(title: 'diagnosis.notification_title'.tr(context)),
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
                  Icons.notifications_active_outlined,
                  size: 60,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'diagnosis.checking_notif'.tr(context),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'diagnosis.verifying_notif'.tr(context),
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
                      'diagnosis.permission'.tr(context),
                      'diagnosis.permission_desc'.tr(context),
                      _currentStep >= 1,
                      _step1Success,
                      _step1Error,
                    ),
                    _buildDivider(),
                    _buildStep(
                      'diagnosis.token'.tr(context),
                      'diagnosis.token_desc'.tr(context),
                      _currentStep >= 2,
                      _step2Success,
                      _step2Error,
                    ),
                    _buildDivider(),
                    _buildStep(
                      'diagnosis.test_sending'.tr(context),
                      'diagnosis.test_desc'.tr(context),
                      _currentStep >= 3,
                      _step3Success,
                      _step3Error,
                    ),
                  ],
                ),
              ),
            ),
            if (_step3Success)
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
                          'diagnosis.success'.tr(context),
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
