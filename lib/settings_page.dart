import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'localization/app_localizations.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'diagnosis/diagnosis_hub_page.dart';
import 'helpdesk/helpdesk_list_page.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SettingsPage({super.key, required this.userData});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final storage = const FlutterSecureStorage();
  final LocalAuthentication auth = LocalAuthentication();

  bool _isFingerprintEnabled = false;
  bool _hasToken = false;
  bool _isLoading = true;
  String _appVersion = "Loading...";
  String _userType = ''; // fetched from API, same as profile_page

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    String? token = await storage.read(key: 'biometric_token');

    // Initial status from userData (server)
    bool serverEnabled = widget.userData['biometric_enabled'] == 1;

    // Fetch user_type from profile API (same as profile_page.dart)
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = 'https://foxgeen.com/HRIS/mobileapi/get_profile_details?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == true) {
        final fetchedUserType = (data['data']['basic_info']?['user_type'] ?? '').toString();
        if (mounted) setState(() => _userType = fetchedUserType);
      }
    } catch (e) {
      debugPrint('Settings: failed to fetch user type: $e');
    }

    setState(() {
      _isFingerprintEnabled = serverEnabled;
      _hasToken = token != null;
      _isLoading = false;
    });
  }

  Future<void> _toggleFingerprint(bool value) async {
    // If enabling, we need a token first
    if (value && !_hasToken) {
      bool? proceed = await _showRegisterDialog();
      if (proceed != true) return;
      await _registerBiometric();
    } else {
      setState(() => _isLoading = true);
      try {
        final url =
            'https://foxgeen.com/HRIS/mobileapi/update_biometric_status';
        final response = await http.post(
          Uri.parse(url),
          body: {
            'user_id': widget.userData['id'].toString(),
            'status': value ? '1' : '0',
          },
        );

        final data = json.decode(response.body);
        if (data['status'] == true) {
          await storage.write(
            key: 'fingerprint_enabled',
            value: value.toString(),
          );
          setState(() {
            _isFingerprintEnabled = value;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  value
                      ? 'settings.fingerprint_enabled_msg'.tr(context)
                      : 'settings.fingerprint_disabled_msg'.tr(context),
                ),
                backgroundColor: value ? Colors.green : Colors.orange,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'main.error_with_msg'.tr(
                    context,
                    args: {'message': data['message'] ?? 'Error'},
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error toggle fingerprint: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('login.conn_error'.tr(context)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFingerprint() async {
    bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'settings.delete_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'settings.delete_confirm_desc'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'settings.cancel'.tr(context),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('settings.delete'.tr(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final url = 'https://foxgeen.com/HRIS/mobileapi/delete_biometric';
        final response = await http.post(
          Uri.parse(url),
          body: {'user_id': widget.userData['id'].toString()},
        );

        final data = json.decode(response.body);
        if (data['status'] == true) {
          await storage.delete(key: 'biometric_token');
          await storage.write(key: 'fingerprint_enabled', value: 'false');
          setState(() {
            _hasToken = false;
            _isFingerprintEnabled = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('settings.delete_success'.tr(context)),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'main.error_with_msg'.tr(
                    context,
                    args: {'message': data['message'] ?? 'Error'},
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error delete fingerprint: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('login.conn_error'.tr(context)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showRegisterDialog() {
    return showModalBottomSheet<bool>(
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
              'settings.register_title'.tr(context),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'settings.register_desc'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'settings.cancel'.tr(context),
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
                    onPressed: () => Navigator.pop(context, true),
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
                      'settings.continue_label'.tr(context),
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

  Future<void> _registerBiometric() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'settings.scan_reason'.tr(context),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        // Tanya password DULU sebelum set loading, agar halaman tidak jadi kosong di balik dialog
        final biometricToken = const Uuid().v4();
        const url = 'https://foxgeen.com/HRIS/mobileapi/register_biometric';

        String? password = await _promptForPassword();
        if (password == null) return; // user tekan Batal

        // Baru set loading SETELAH dialog ditutup
        setState(() => _isLoading = true);

        final response = await http.post(
          Uri.parse(url),
          body: {
            'identifier':
                widget.userData['username'] ?? widget.userData['email'],
            'password': password,
            'biometric_token': biometricToken,
            'device_info': 'settings.device_info'.tr(context),
          },
        );

        final data = json.decode(response.body);
        if (data['status'] == true) {
          await storage.write(key: 'biometric_token', value: biometricToken);
          await storage.write(key: 'fingerprint_enabled', value: 'true');

          setState(() {
            _hasToken = true;
            _isFingerprintEnabled = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('settings.reg_success'.tr(context)),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'main.error_with_msg'.tr(
                    context,
                    args: {'message': data['message'] ?? 'Error'},
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error registering biometric: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _promptForPassword() async {
    final passwordController = TextEditingController();
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.confirm_password'.tr(context).toUpperCase(),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                focusNode: FocusNode()..requestFocus(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'settings.enter_password'.tr(context),
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (value) => Navigator.pop(context, value.trim()),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'settings.cancel'.tr(context),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, passwordController.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'settings.confirm'.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    String currentLang = languageProvider.locale.languageCode;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.language_rounded,
                size: 48,
                color: Color(0xFF7E57C2),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'settings.select_language'.tr(context),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            RadioListTile<String>(
              title: const Text('Bahasa Indonesia'),
              value: 'id',
              groupValue: currentLang,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  languageProvider.setLanguage(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: currentLang,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  languageProvider.setLanguage(value);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showThemeDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ThemeMode currentMode = themeProvider.themeMode;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Icon(
                currentMode == ThemeMode.system
                    ? Icons.brightness_4_rounded
                    : currentMode == ThemeMode.light
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                size: 48,
                color: const Color(0xFF7E57C2),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'settings.theme'.tr(context),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            RadioListTile<ThemeMode>(
              title: Text('settings.theme_system'.tr(context)),
              secondary: const Icon(Icons.brightness_4_rounded, color: Color(0xFF7E57C2)),
              value: ThemeMode.system,
              groupValue: currentMode,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('settings.theme_light'.tr(context)),
              secondary: const Icon(Icons.light_mode_rounded, color: Color(0xFF7E57C2)),
              value: ThemeMode.light,
              groupValue: currentMode,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('settings.theme_dark'.tr(context)),
              secondary: const Icon(Icons.dark_mode_rounded, color: Color(0xFF7E57C2)),
              value: ThemeMode.dark,
              groupValue: currentMode,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'main.xin_settings'.tr(context),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'settings.language'.tr(context),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Theme.of(context).brightness == Brightness.dark
                        ? Border.all(color: Colors.white24)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: Color(0xFF7E57C2),
                      ),
                    ),
                    title: Text('settings.language'.tr(context)),
                    subtitle: Text(
                      Provider.of<LanguageProvider>(
                                context,
                              ).locale.languageCode ==
                              'id'
                          ? 'Bahasa Indonesia'
                          : 'English',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showLanguageDialog,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'settings.theme'.tr(context),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Theme.of(context).brightness == Brightness.dark
                        ? Border.all(color: Colors.white24)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Provider.of<ThemeProvider>(context).themeMode == ThemeMode.system
                            ? Icons.brightness_4_rounded
                            : Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                        color: const Color(0xFF7E57C2),
                      ),
                    ),
                    title: Text('settings.theme'.tr(context)),
                    subtitle: Text(
                      Provider.of<ThemeProvider>(context).themeMode ==
                              ThemeMode.system
                          ? 'settings.theme_system'.tr(context)
                          : Provider.of<ThemeProvider>(context).themeMode ==
                                ThemeMode.light
                          ? 'settings.theme_light'.tr(context)
                          : 'settings.theme_dark'.tr(context),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showThemeDialog,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'settings.fingerprint'.tr(context),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Theme.of(context).brightness == Brightness.dark
                        ? Border.all(color: Colors.white24)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text('settings.fingerprint'.tr(context)),
                        subtitle: Text(
                          _hasToken
                              ? 'settings.registered'.tr(context)
                              : 'settings.not_registered'.tr(context),
                        ),
                        trailing: Switch(
                          value: _isFingerprintEnabled,
                          onChanged: _toggleFingerprint,
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (_hasToken) ...[
                        const Divider(height: 1, indent: 70),
                        ListTile(
                          leading: const SizedBox(width: 40),
                          title: Text(
                            'settings.re_register'.tr(context),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onTap: () async {
                            // Only call _registerBiometric, it will handle the scan
                            _registerBiometric();
                          },
                        ),
                        const Divider(height: 1, indent: 70),
                        ListTile(
                          leading: const SizedBox(width: 40),
                          title: Text(
                            'settings.delete_fingerprint'.tr(context),
                            style: const TextStyle(color: Colors.red),
                          ),
                          onTap: _deleteFingerprint,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'settings.account'.tr(context),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Theme.of(context).brightness == Brightness.dark
                        ? Border.all(color: Colors.white24)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF7E57C2),
                      backgroundImage:
                          (widget.userData['profile_photo'] != null &&
                              widget.userData['profile_photo']
                                  .toString()
                                  .isNotEmpty)
                          ? NetworkImage(
                              'https://foxgeen.com/HRIS/public/uploads/users/thumb/${widget.userData['profile_photo']}',
                            )
                          : null,
                      child:
                          (widget.userData['profile_photo'] == null ||
                              widget.userData['profile_photo']
                                  .toString()
                                  .isEmpty)
                          ? Text(
                              (widget.userData['nama'] ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    title: Text(widget.userData['nama'] ?? 'User'),
                    subtitle: Text(widget.userData['email'] ?? ''),
                  ),
                ),
                // ── Informasi Aplikasi ────────────────────────────
                const SizedBox(height: 32),
                Text(
                  'settings.app_info'.tr(context),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Theme.of(context).brightness == Brightness.dark
                        ? Border.all(color: Colors.white24)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        icon: Icons.info_outline,
                        title: 'settings.app_version'.tr(context),
                        trailing: _appVersion,
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildInfoTile(
                        icon: Icons.shield_outlined,
                        title: 'settings.privacy_policy'.tr(context),
                        onTap: () =>
                            _launchURL('https://foxgeen.com/HRIS/erp/privacy'),
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildInfoTile(
                        icon: Icons.help_outline,
                        title: 'settings.help_support'.tr(context),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HelpdeskListPage(userData: widget.userData),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildInfoTile(
                        icon: Icons.business_outlined,
                        title: 'Iskom Sarana Nusantara',
                        trailing: '© 2026',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'settings.diagnosis'.tr(context),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Theme.of(context).brightness == Brightness.dark
                        ? Border.all(color: Colors.white24)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E57C2).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            color: Color(0xFF7E57C2),
                          ),
                        ),
                        title: Text('settings.diagnosis'.tr(context)),
                        subtitle: Text('settings.diagnosis_desc'.tr(context)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DiagnosisHubPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Zona Berbahaya (Hanya untuk Customer) ──
                if (_userType == 'customer') ...[  
                  Text(
                    'delete_account.section_title'.tr(context),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                      ),
                      title: Text(
                        'delete_account.btn_label'.tr(context),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('delete_account.btn_desc'.tr(context)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.red),
                      onTap: _showDeleteAccountSheet,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF7E57C2).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF7E57C2), size: 20),
      ),
      title: Text(title),
      trailing: trailing != null
          ? Text(
              trailing,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            )
          : (onTap != null
                ? const Icon(Icons.chevron_right, color: Colors.grey)
                : null),
      onTap: onTap,
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.link_error'.tr(context, args: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  void _showDeleteAccountSheet() {
    final ScrollController scrollController = ScrollController();
    bool hasScrolledToBottom = false;
    bool hasAgreed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          scrollController.addListener(() {
            if (scrollController.position.atEdge &&
                scrollController.position.pixels != 0 &&
                !hasScrolledToBottom) {
              setSheetState(() => hasScrolledToBottom = true);
            }
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'delete_account.sheet_title'.tr(context),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scroll hint
                if (!hasScrolledToBottom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward, size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'delete_account.scroll_hint'.tr(context),
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                // Warning text (scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Text(
                      'delete_account.warning_body'.tr(context),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
                // Checkbox + Button (bottom fixed)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: hasScrolledToBottom
                            ? () => setSheetState(() => hasAgreed = !hasAgreed)
                            : null,
                        child: Row(
                          children: [
                            Checkbox(
                              value: hasAgreed,
                              onChanged: hasScrolledToBottom
                                  ? (v) => setSheetState(() => hasAgreed = v ?? false)
                                  : null,
                              activeColor: Colors.red,
                            ),
                            Expanded(
                              child: Text(
                                'delete_account.agree_checkbox'.tr(context),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hasScrolledToBottom
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: hasAgreed && hasScrolledToBottom
                              ? () async {
                                  Navigator.pop(context);
                                  final confirm = await showModalBottomSheet<bool>(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).scaffoldBackgroundColor,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                                          Text(
                                            'delete_account.confirm_title'.tr(context),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'delete_account.confirm_desc'.tr(context),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                          ),
                                          const SizedBox(height: 32),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  child: Text(
                                                    'settings.cancel'.tr(context),
                                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    elevation: 0,
                                                  ),
                                                  child: Text(
                                                    'delete_account.confirm_btn'.tr(context),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (confirm == true) _deleteAccount();
                                }
                              : null,
                          icon: const Icon(Icons.delete_forever),
                          label: Text('delete_account.btn_label'.tr(context)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasAgreed && hasScrolledToBottom ? Colors.red : Colors.grey[300],
                            foregroundColor: hasAgreed && hasScrolledToBottom ? Colors.white : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    try {
      final userId = (widget.userData['id'] ?? widget.userData['user_id']).toString();
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/delete_account'),
        body: {'user_id': userId},
      );

      final data = json.decode(response.body);
      if (data['status'] == true) {
        // Clear all local storage
        await storage.deleteAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('delete_account.success'.tr(context)),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'delete_account.error'.tr(context)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('delete_account.error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
