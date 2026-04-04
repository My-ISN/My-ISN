import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'dashboard_page.dart';
import 'widgets/connectivity_wrapper.dart';
import 'localization/app_localizations.dart';
import 'widgets/secondary_app_bar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedGender = 'Male';
  File? _image;
  bool _isLoading = false;
  final _picker = ImagePicker();

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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _register() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _contactController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login.fill_all_fields'.tr(context))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/register'),
      );

      request.fields['first_name'] = _firstNameController.text;
      request.fields['last_name'] = _lastNameController.text;
      request.fields['username'] = _usernameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passwordController.text;
      request.fields['contact_number'] = _contactController.text;
      request.fields['gender'] = _selectedGender == 'Male' ? '1' : '2';

      if (_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_photo', _image!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint('RAW RESPONSE: ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login.server_error'.tr(context))),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (response.statusCode == 200 && data['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'main.success_with_msg'.tr(
                context,
                args: {'message': data['message']?.toString() ?? ''},
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Auto-login logic
        final userData = data['data'];
        final identifier = _usernameController.text;
        final password = _passwordController.text;

        // Tawarkan aktifkan fingerprint
        if (_canCheckBiometrics) {
          await _showEnableFingerprintDialog(identifier, password);
        }

        if (!mounted) return;
        // Langsung masuk Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(userData: userData),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'login.conn_error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: SecondaryAppBar(title: 'register.title'.tr(context)),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'register.subtitle'.tr(context),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Profile Photo Picker (Premium Design)
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF7E57C2).withOpacity(0.2),
                                  const Color(0xFF7E57C2).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).cardColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFF8F9FE),
                              backgroundImage: _image != null
                                  ? FileImage(_image!)
                                  : null,
                              child: _image == null
                                  ? Icon(
                                      Icons.person_outline_rounded,
                                      size: 40,
                                      color: Colors.grey.shade400,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7E57C2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7E57C2,
                                    ).withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'register.set_profile_photo'.tr(context),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildPremiumField(
                      controller: _firstNameController,
                      label: 'register.first_name'.tr(context),
                      hint: 'register.first_name'.tr(context),
                      icon: Icons.person_outline_rounded,
                      autoCapitalize: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPremiumField(
                      controller: _lastNameController,
                      label: 'register.last_name'.tr(context),
                      hint: 'register.last_name'.tr(context),
                      icon: Icons.person_outline_rounded,
                      autoCapitalize: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPremiumField(
                controller: _usernameController,
                label: 'register.username'.tr(context),
                hint: 'register.username'.tr(context),
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 12),
              _buildPremiumField(
                controller: _emailController,
                label: 'register.email'.tr(context),
                hint: 'register.email'.tr(context),
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPremiumField(
                      controller: _passwordController,
                      label: 'register.password'.tr(context),
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPremiumField(
                      controller: _contactController,
                      label: 'register.contact'.tr(context),
                      hint: '0812...',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                'register.gender'.tr(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF4A4A4A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF7E57C2),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    items: ['Male', 'Female'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value == 'Male'
                              ? 'register.male'.tr(context)
                              : 'register.female'.tr(context),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedGender = newValue!;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFF7E57C2).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'register.create_account'.tr(context),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'register.have_account'.tr(context),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'register.login'.tr(context),
                        style: const TextStyle(
                          color: Color(0xFF7E57C2),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEnableFingerprintDialog(
    String identifier,
    String password,
  ) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.fingerprint_rounded,
              size: 80,
              color: Color(0xFF7E57C2),
            ),
            const SizedBox(height: 24),
            Text(
              'login.enable_fingerprint'.tr(context),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'register.reg_success_fingerprint'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'login.later'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _registerBiometric(identifier, password);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'login.enable'.tr(context),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
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
            'device_info': 'login.android_device_reg'.tr(context),
          },
        );

        final data = json.decode(response.body);
        if (data['status'] == true) {
          await storage.write(key: 'biometric_token', value: biometricToken);
          await storage.write(key: 'fingerprint_enabled', value: 'true');
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

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool autoCapitalize = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF8F9FE),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            onChanged: autoCapitalize
                ? (value) {
                    final uppercase = value.toUpperCase();
                    if (controller.text != uppercase) {
                      controller.value = controller.value.copyWith(
                        text: uppercase,
                        selection: TextSelection.collapsed(
                          offset: uppercase.length,
                        ),
                      );
                    }
                  }
                : null,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF7E57C2), size: 20),
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF7E57C2),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
