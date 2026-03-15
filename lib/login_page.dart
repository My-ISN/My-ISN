import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dashboard_page.dart';
import 'register_page.dart';
import 'services/notification_service.dart';
import 'widgets/connectivity_wrapper.dart';
import 'localization/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final LocalAuthentication auth = LocalAuthentication();
  final storage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
  );

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck && isSupported;
      });
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }
  }

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login.fill_all_fields'.tr(context))),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      const url = 'https://foxgeen.com/HRIS/mobileapi/login';

      final response = await http
          .post(
            Uri.parse(url),
            body: {'identifier': identifier, 'password': password},
          )
          .timeout(const Duration(seconds: 15));

      var data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint('Failed to decode JSON. Raw response: ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('login.server_error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (response.statusCode == 200 && data['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'login.login_success'.tr(
                context,
                args: {'name': data['data']['nama']},
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Setelah login sukses, tawarkan aktifkan fingerprint jika belum aktif
        final storedToken = await storage.read(key: 'biometric_token');
        if (storedToken == null && _canCheckBiometrics) {
          // Kita await dialog agar proses registrasi selesai dulu
          await _showEnableFingerprintDialog(identifier, password);
        }

        // Save user data for persistence (deep linking etc)
        await storage.write(key: 'user_data', value: json.encode(data['data']));

        // Update FCM Token
        NotificationService().updateTokenOnServer(data['data']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(userData: data['data']),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'login.login_failed'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (ConnectivityStatus.of(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('login.conn_error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showEnableFingerprintDialog(
    String identifier,
    String password,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('login.enable_fingerprint'.tr(context)),
        content: Text('login.enable_fingerprint_desc'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('login.later'.tr(context)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Show loading if you want, but at least await the process
              await _registerBiometric(identifier, password);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
            ),
            child: Text(
              'login.enable'.tr(context),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerBiometric(String identifier, String password) async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'login.scan_fingerprint_enable'.tr(context),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final biometricToken = const Uuid().v4();
        const url = 'https://foxgeen.com/HRIS/mobileapi/register_biometric';

        final response = await http.post(
          Uri.parse(url),
          body: {
            'identifier': identifier,
            'password': password,
            'biometric_token': biometricToken,
            'device_info': 'login.android_device'.tr(context),
          },
        );

        final data = json.decode(response.body);
        if (data['status'] == true) {
          debugPrint('Writing token to storage: $biometricToken');
          await storage.write(key: 'biometric_token', value: biometricToken);
          await storage.write(key: 'fingerprint_enabled', value: 'true');

          // Verifikasi langsung setelah nulis
          final verify = await storage.read(key: 'biometric_token');
          debugPrint('Verification read: $verify');

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('login.fingerprint_enabled'.tr(context)),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'login.fingerprint_failed'.tr(
                  context,
                  args: {'message': data['message']},
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Jika user membatalkan scan
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login.fingerprint_cancelled'.tr(context))),
        );
      }
    } catch (e) {
      debugPrint('Error registering biometric: $e');
      if (mounted && ConnectivityStatus.of(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login.fingerprint_conn_error'.tr(context))),
        );
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    final token = await storage.read(key: 'biometric_token');
    final enabled = await storage.read(key: 'fingerprint_enabled');
    debugPrint('Reading token for login: $token, enabled: $enabled');

    if (token == null || enabled != 'true') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login.fingerprint_not_enabled'.tr(context))),
      );
      return;
    }

    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'login.scan_fingerprint_login'.tr(context),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() => _isLoading = true);
        const url = 'https://foxgeen.com/HRIS/mobileapi/login_biometric';
        final response = await http.post(
          Uri.parse(url),
          body: {'biometric_token': token},
        );

        final data = json.decode(response.body);
        if (data['status'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'login.welcome_back_name'.tr(
                  context,
                  args: {'name': data['data']['nama']},
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Save user data for persistence (deep linking etc)
          await storage.write(
            key: 'user_data',
            value: json.encode(data['data']),
          );

          // Update FCM Token
          NotificationService().updateTokenOnServer(data['data']);

          // Navigate to Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardPage(userData: data['data']),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'login.login_failed'.tr(context),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && ConnectivityStatus.of(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('login.conn_error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final String email = googleUser.email;
      final String displayName = googleUser.displayName ?? '';
      final List<String> nameParts = displayName.split(' ');
      final String firstName = nameParts.first;
      final String lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      final String picture = googleUser.photoUrl ?? '';

      const url = 'https://foxgeen.com/HRIS/mobileapi/google_login';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'profile_photo': picture,
        },
      );

      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'login.google_success'.tr(
                context,
                args: {'name': data['data']['nama']?.toString() ?? ''},
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(userData: data['data']),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'login.google_failed'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      debugPrint('Google Sign-In Error: $error');
      if (mounted && ConnectivityStatus.of(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('login.conn_error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'main.app_name'.tr(context),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7E57C2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'login.welcome_back'.tr(context),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: 'login.username_email'.tr(context),
                    filled: true,
                    fillColor: const Color(0xFFF3F6FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    hintText: 'login.password'.tr(context),
                    filled: true,
                    fillColor: const Color(0xFFF3F6FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) =>
                              setState(() => _rememberMe = value ?? false),
                          activeColor: const Color(0xFF7E57C2),
                        ),
                        Text('login.remember_me'.tr(context)),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'login.forgot_password'.tr(context),
                        style: const TextStyle(color: Color(0xFF7E57C2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF7E57C2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'login.register'.tr(context),
                          style: const TextStyle(color: Color(0xFF7E57C2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E57C2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.login,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'login.login'.tr(context),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                if (_canCheckBiometrics) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'login.login_fingerprint'.tr(context),
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(
                            Icons.fingerprint,
                            size: 60,
                            color: Color(0xFF7E57C2),
                          ),
                          onPressed: _isLoading ? null : _loginWithBiometric,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'login.or'.tr(context),
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: Image.asset('assets/images/google.webp', height: 24),
                    label: Text(
                      'login.login_google'.tr(context),
                      style: const TextStyle(color: Colors.black87),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
