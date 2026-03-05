import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

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
        const SnackBar(content: Text('Please fill in all fields')),
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

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login success: ${data['data']['nama']}'),
            backgroundColor: Colors.green,
          ),
        );

        // Setelah login sukses, tawarkan aktifkan fingerprint jika belum aktif
        final storedToken = await storage.read(key: 'biometric_token');
        if (storedToken == null && _canCheckBiometrics) {
          _showEnableFingerprintDialog(identifier, password);
        }

        // TODO: Navigate to Dashboard
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
        title: const Text('Aktifkan Fingerprint?'),
        content: const Text(
          'Apakah Anda ingin mengaktifkan login dengan sidik jari untuk akun ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _registerBiometric(identifier, password);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
            ),
            child: const Text(
              'Aktifkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerBiometric(String identifier, String password) async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan sidik jari untuk mengaktifkan login biometrik',
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
            'device_info':
                'Android Device', // Bisa dikembangkan pakai device_info_plus
          },
        );

        final data = json.decode(response.body);
        if (data['status'] == true) {
          await storage.write(key: 'biometric_token', value: biometricToken);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint berhasil diaktifkan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error registering biometric: $e');
    }
  }

  Future<void> _loginWithBiometric() async {
    final token = await storage.read(key: 'biometric_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fingerprint belum diaktifkan. Silakan login dengan password dulu.',
          ),
        ),
      );
      return;
    }

    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan sidik jari untuk masuk',
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
              content: Text('Welcome back, ${data['data']['nama']}'),
              backgroundColor: Colors.green,
            ),
          );
          // TODO: Navigate to Dashboard
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric error: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                const Text(
                  'Super Apps',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7E57C2),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome back, Please login into an account',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: 'Username or Email',
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
                    hintText: 'Password',
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
                        const Text('Remember Me'),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: Color(0xFF7E57C2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF7E57C2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(color: Color(0xFF7E57C2)),
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.login,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Login',
                                    style: TextStyle(
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
                        const Text(
                          'Atau masuk dengan sidik jari',
                          style: TextStyle(color: Colors.grey),
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
                        'atau',
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
                    onPressed: () {},
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                      height: 20,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.g_mobiledata),
                    ),
                    label: const Text(
                      'Masuk dengan Google',
                      style: TextStyle(color: Colors.black87),
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
