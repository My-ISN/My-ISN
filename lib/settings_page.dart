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
        _appVersion = "${info.version}-preview";
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    String? token = await storage.read(key: 'biometric_token');

    // Initial status from userData (server)
    bool serverEnabled = widget.userData['biometric_enabled'] == 1;

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
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.delete_confirm_title'.tr(context)),
        content: Text('settings.delete_confirm_desc'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('settings.cancel'.tr(context)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'settings.delete'.tr(context),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
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
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.register_title'.tr(context)),
        content: Text('settings.register_desc'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('settings.cancel'.tr(context)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('settings.continue_label'.tr(context)),
          ),
        ],
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
            'device_info': 'Android Device (Settings Update)',
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
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.confirm_password'.tr(context)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'settings.enter_password'.tr(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('settings.cancel'.tr(context)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, passwordController.text.trim()),
            child: Text('settings.confirm'.tr(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    String currentLang = languageProvider.locale.languageCode;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.select_language'.tr(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Bahasa Indonesia'),
              value: 'id',
              groupValue: currentLang,
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
              onChanged: (value) {
                if (value != null) {
                  languageProvider.setLanguage(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showThemeDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ThemeMode currentMode = themeProvider.themeMode;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.theme'.tr(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text('settings.theme_system'.tr(context)),
              value: ThemeMode.system,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('settings.theme_light'.tr(context)),
              value: ThemeMode.light,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('settings.theme_dark'.tr(context)),
              value: ThemeMode.dark,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.language,
                        color: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.dark_mode_outlined,
                        color: Theme.of(context).colorScheme.primary,
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
                        onTap: () => _launchWhatsApp(
                          '0895384314416',
                          'Halo admin My ISN, saya butuh bantuan terkait akun saya...',
                        ),
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildInfoTile(
                        icon: Icons.business_outlined,
                        title: 'Foxgeen',
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

  Future<void> _launchWhatsApp(String phone, String message) async {
    // Remove leading 0 and replace with 62
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '62${phone.substring(1)}';
    }

    final String urlString =
        "whatsapp://send?phone=$formattedPhone&text=${Uri.encodeComponent(message)}";
    final Uri url = Uri.parse(urlString);

    try {
      if (!await launchUrl(url)) {
        // Fallback to web link if whatsapp app is not installed
        final String webUrlString =
            "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}";
        final Uri webUrl = Uri.parse(webUrlString);
        if (!await launchUrl(webUrl, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch WhatsApp');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.wa_error'.tr(context, args: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }
}
