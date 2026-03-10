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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'register.title'.tr(context),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'register.subtitle'.tr(context),
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 32),

              // Profile Photo Picker (Merged)
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF7E57C2).withOpacity(0.2),
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: const Color(0xFFF3F6FF),
                              backgroundImage: _image != null
                                  ? FileImage(_image!)
                                  : null,
                              child: _image == null
                                  ? const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 40,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7E57C2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'register.set_profile_photo'.tr(context),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: 'register.first_name'.tr(context),
                      hint: 'register.first_name'.tr(context),
                      icon: Icons.person_outline,
                      autoCapitalize: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'register.last_name'.tr(context),
                      hint: 'register.last_name'.tr(context),
                      icon: Icons.person_outline,
                      autoCapitalize: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _usernameController,
                      label: 'register.username'.tr(context),
                      hint: 'register.username'.tr(context),
                      icon: Icons.alternate_email,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _emailController,
                      label: 'register.email'.tr(context),
                      hint: 'register.email'.tr(context),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _passwordController,
                      label: 'register.password'.tr(context),
                      hint: 'register.password'.tr(context),
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _contactController,
                      label: 'register.contact'.tr(context),
                      hint: 'register.contact'.tr(context),
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'register.gender'.tr(context),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
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
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      : Text(
                          'register.create_account'.tr(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'register.have_account'.tr(context),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'register.login'.tr(context),
                        style: const TextStyle(
                          color: Color(0xFF7E57C2),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('login.enable_fingerprint'.tr(context)),
        content: Text('register.reg_success_fingerprint'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('login.later'.tr(context)),
          ),
          ElevatedButton(
            onPressed: () async {
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
            'device_info': 'Android Device (After Registration)',
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

  Widget _buildTextField({
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
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
            prefixIcon: Icon(icon, size: 20),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
            filled: true,
            fillColor: const Color(0xFFF3F6FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }
}
