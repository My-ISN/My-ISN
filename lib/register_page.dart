import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import 'dashboard/dashboard_page.dart';
import 'widgets/connectivity_wrapper.dart';
import 'localization/app_localizations.dart';
import 'constants.dart';

import 'widgets/secondary_app_bar.dart';
import 'widgets/custom_snackbar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Step Control
  int _currentStep = 0; // 0: Phone, 1: OTP, 2: Profile
  bool _isLoading = false;
  bool _isEmailMethod = false;

  // Step 1: Phone
  final _phoneController = TextEditingController();

  // Step 2: OTP
  final _otpController = TextEditingController();
  int _resendSeconds = 0;
  Timer? _resendTimer;

  // Step 3: Profile
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedGender = 'Male';
  File? _image;
  final _picker = ImagePicker();

  final LocalAuthentication auth = LocalAuthentication();
  final storage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      context.showWarningSnackBar('login.fill_all_fields'.tr(context));
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('Requesting OTP to: ${AppConstants.baseUrl}/send_otp');
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/send_otp'),
        body: {'phone': phone},
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: "${response.body}"');

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        if (!mounted) return;
        context.showSuccessSnackBar('register.otp_sent'.tr(context));
        _startResendTimer();
        FocusScope.of(context).unfocus();
        setState(() => _currentStep = 1);
      } else {
        if (!mounted) return;
        context.showErrorSnackBar(data['message'] ?? 'login.conn_error'.tr(context));
      }
    } catch (e) {
      debugPrint('Error request OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      context.showWarningSnackBar('register.enter_otp_hint'.tr(context));
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('Verifying OTP to: ${AppConstants.baseUrl}/verify_otp');
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/verify_otp'),
        body: {
          'phone': _phoneController.text.trim(),
          'otp': code,
        },
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: "${response.body}"');

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        if (!mounted) return;
        context.showSuccessSnackBar('register.otp_verified'.tr(context));
        FocusScope.of(context).unfocus();
        setState(() => _currentStep = 2);
      } else {
        if (!mounted) return;
        context.showErrorSnackBar(data['message'] ?? 'register.invalid_otp'.tr(context));
      }
    } catch (e) {
      debugPrint('Error verify OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (_fullNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        (_isEmailMethod && _emailController.text.isEmpty) ||
        _passwordController.text.isEmpty) {
      context.showWarningSnackBar('login.fill_all_fields'.tr(context));
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/register'),
      );

      request.fields['full_name'] = _fullNameController.text;
      request.fields['username'] = _usernameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passwordController.text;
      request.fields['contact_number'] = _phoneController.text;
      request.fields['gender'] = _selectedGender == 'Male' ? '1' : '2';
      request.fields['registration_method'] = _isEmailMethod ? 'email' : 'phone';

      if (_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_photo', _image!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        if (!mounted) return;
        context.showSuccessSnackBar('main.success_with_msg'.tr(context, args: {'message': 'register.title'.tr(context)}));

        final userData = data['data'];
        if (_canCheckBiometrics) {
          await _showEnableFingerprintDialog(_usernameController.text, _passwordController.text);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage(userData: userData)),
        );
      } else {
        if (!mounted) return;
        context.showErrorSnackBar(data['message'] ?? 'login.conn_error'.tr(context));
      }
    } catch (e) {
      debugPrint('Error finalize register: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      _cropImage(pickedFile.path);
    }
  }

  Future<void> _cropImage(String filePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: filePath,
      maxHeight: 1024,
      maxWidth: 1024,
      compressQuality: 70,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'profile.edit_photo'.tr(context),
          toolbarColor: const Color(0xFF7E57C2),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'profile.edit_photo'.tr(context),
          cancelButtonTitle: 'main.cancel'.tr(context),
          doneButtonTitle: 'main.save'.tr(context),
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      if (!mounted) return;
      setState(() {
        _image = File(croppedFile.path);
      });
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
        body: Stack(
          children: [
            // Decorative background blobs
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7E57C2).withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                   const SizedBox(height: 10),
                  // Progress Indicator
                  if (!_isEmailMethod) _buildStepIndicator(),
                  
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: SingleChildScrollView(
                        key: ValueKey(_currentStep.toString() + _isEmailMethod.toString()),
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
                        child: _buildCurrentStepView(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 45),
      child: Row(
        children: [
          _stepNode(0, 'register.step_phone'.tr(context), Icons.phone_android_rounded),
          _stepLine(0),
          _stepNode(1, 'register.step_otp'.tr(context), Icons.lock_clock_rounded),
          _stepLine(1),
          _stepNode(2, 'register.step_profile'.tr(context), Icons.person_rounded),
        ],
      ),
    );
  }

  Widget _stepNode(int step, String label, IconData icon) {
    bool isActive = _currentStep >= step;
    bool isCompleted = _currentStep > step;
    
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: isActive 
              ? const LinearGradient(
                  colors: [Color(0xFF9575CD), Color(0xFF7E57C2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
            color: isActive ? null : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color(0xFF7E57C2).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : [],
            border: Border.all(
              color: isActive ? Colors.transparent : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Icon(
                    icon,
                    color: isActive ? Colors.white : Colors.grey.shade400,
                    size: 18,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? const Color(0xFF7E57C2) : Colors.grey.shade500,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int step) {
    bool isActive = _currentStep > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 22, left: 4, right: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: isActive ? const Color(0xFF7E57C2).withValues(alpha: 0.8) : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    if (_isEmailMethod) {
      return _buildEmailRegistrationForm();
    }
    switch (_currentStep) {
      case 0:
        return _buildPhoneStep();
      case 1:
        return _buildOtpStep();
      case 2:
        return _buildProfileStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_android_rounded, size: 70, color: Color(0xFF7E57C2)),
        ),
        const SizedBox(height: 24),
        Text(
          'register.phone_number'.tr(context),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'register.subtitle'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 40),
        _buildPremiumField(
          controller: _phoneController,
          label: 'register.phone_number'.tr(context),
          icon: Icons.phone_iphone_rounded,
          keyboardType: TextInputType.phone,
          prefix: IntrinsicWidth(
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.phone_iphone_rounded, color: Color(0xFF7E57C2), size: 20),
                const SizedBox(width: 8),
                Text(
                  '+62',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: 20,
                  width: 1.5,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          text: 'register.send_otp'.tr(context),
          onPressed: _requestOtp,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(height: 1, width: 30, color: Colors.grey.withValues(alpha: 0.2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'OR',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            Container(height: 1, width: 30, color: Colors.grey.withValues(alpha: 0.2)),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _isEmailMethod = true;
          }),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF7E57C2),
          ),
          child: Text(
            'register.or_use_email'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailRegistrationForm() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          'register.email_reg_title'.tr(context),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const SizedBox(height: 28),
        _buildProfilePicker(),
        const SizedBox(height: 32),
        _buildPremiumField(
          controller: _fullNameController,
          label: 'register.full_name'.tr(context),
          icon: Icons.badge_outlined,
          autoCapitalize: true,
        ),
        const SizedBox(height: 18),
        _buildPremiumField(
          controller: _usernameController,
          label: 'register.username'.tr(context),
          icon: Icons.alternate_email_rounded,
        ),
        const SizedBox(height: 18),
        _buildPremiumField(
          controller: _emailController,
          label: 'register.email'.tr(context),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _buildPremiumField(
          controller: _phoneController,
          label: 'register.contact'.tr(context),
          icon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          prefix: IntrinsicWidth(
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.phone_android_rounded, color: Color(0xFF7E57C2), size: 20),
                const SizedBox(width: 8),
                Text(
                  '+62',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: 20,
                  width: 1.5,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _buildPremiumField(
          controller: _passwordController,
          label: 'register.password'.tr(context),
          icon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 20),
        _buildGenderSelector(),
        const SizedBox(height: 36),
        _buildActionButton(
          text: 'register.create_account'.tr(context),
          onPressed: _register,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _isEmailMethod = false;
          }),
          child: Text(
            'register.use_phone_number'.tr(context),
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_user_rounded, size: 70, color: Color(0xFF7E57C2)),
        ),
        const SizedBox(height: 24),
        Text(
          'register.otp_code'.tr(context),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'register.enter_otp_hint'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 40),
        Pinput(
          length: 6,
          controller: _otpController,
          onCompleted: (pin) => _verifyOtp(),
          defaultPinTheme: PinTheme(
            width: 45,
            height: 55,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E57C2),
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
            ),
          ),
          focusedPinTheme: PinTheme(
            width: 45,
            height: 55,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E57C2),
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF7E57C2), width: 3),
              ),
            ),
          ),
          submittedPinTheme: PinTheme(
            width: 45,
            height: 55,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E57C2),
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF7E57C2), width: 2),
              ),
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'register.resend_otp_in'.tr(
                context,
                args: {'seconds': _resendSeconds.toString()},
              ),
              style: TextStyle(color: Colors.grey.shade500),
            ),
            if (_resendSeconds == 0)
              TextButton(
                onPressed: _requestOtp,
                child: Text(
                  'register.send_otp'.tr(context),
                  style: const TextStyle(color: Color(0xFF7E57C2), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          text: 'register.verify_otp'.tr(context),
          onPressed: _verifyOtp,
        ),
        TextButton(
          onPressed: () => setState(() => _currentStep = 0),
          child: Text('register.back'.tr(context), style: TextStyle(color: Colors.grey.shade600)),
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Column(
      children: [
        _buildProfilePicker(),
        const SizedBox(height: 24),
        _buildPremiumField(
          controller: _fullNameController,
          label: 'register.full_name'.tr(context),
          icon: Icons.badge_outlined,
          autoCapitalize: true,
        ),
        const SizedBox(height: 16),
        _buildPremiumField(
          controller: _usernameController,
          label: 'register.username'.tr(context),
          icon: Icons.alternate_email_rounded,
        ),
        if (_isEmailMethod) ...[
          _buildPremiumField(
            controller: _emailController,
            label: 'register.email'.tr(context),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
        ],
        _buildPremiumField(
          controller: _passwordController,
          label: 'register.password'.tr(context),
          icon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 16),
        _buildGenderSelector(),
        const SizedBox(height: 32),
        _buildActionButton(
          text: 'register.create_account'.tr(context),
          onPressed: _register,
        ),
      ],
    );
  }

  Widget _buildProfilePicker() {
    return Center(
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
                        const Color(0xFF7E57C2).withValues(alpha: 0.2),
                        const Color(0xFF7E57C2).withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 43,
                  backgroundColor: const Color(0xFFF8F9FE),
                  backgroundImage: _image != null ? FileImage(_image!) : null,
                  child: _image == null
                      ? Icon(Icons.person_outline_rounded, size: 40, color: Colors.grey.shade400)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF7E57C2), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'register.set_profile_photo'.tr(context),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'register.gender'.tr(context),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7E57C2)),
              items: ['Male', 'Female'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value == 'Male' ? 'register.male'.tr(context) : 'register.female'.tr(context)),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedGender = v!),
            ),
          ),
        ),
      ],
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
        const url = '${AppConstants.baseUrl}/register_biometric';

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
          context.showSuccessSnackBar('login.fingerprint_enabled'.tr(context));
        } else {
          if (!mounted) return;
          context.showErrorSnackBar(
            'login.fingerprint_failed'.tr(
              context,
              args: {'message': data['message']},
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error registering biometric: $e');
        context.showErrorSnackBar('login.fingerprint_conn_error'.tr(context));
    }
  }

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool autoCapitalize = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefix,
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
              prefixIcon: prefix ?? Icon(icon, color: const Color(0xFF7E57C2), size: 20),
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

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF9575CD), Color(0xFF7E57C2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E57C2).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
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
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
