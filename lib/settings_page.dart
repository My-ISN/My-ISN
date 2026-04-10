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
import 'constants.dart';

import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'diagnosis/diagnosis_hub_page.dart';
import 'helpdesk/helpdesk_list_page.dart';
import 'login_page.dart';
import 'widgets/secondary_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/notification_service.dart';
import 'widgets/custom_snackbar.dart';


class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SettingsPage({super.key, required this.userData});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final storage = const FlutterSecureStorage();
  final LocalAuthentication auth = LocalAuthentication();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isFingerprintEnabled = false;
  bool _hasToken = false;
  bool _isLoading = true;
  String _appVersion = "Loading...";
  String _userType = ''; // fetched from API, same as profile_page
  String _selectedNotificationSound = 'default';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initPackageInfo();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  Future<void> _playPreview(String value) async {
    try {
      String soundFile = value == 'default' ? 'notification_tone_swift_gesture' : value;
      String ext = 'mp3';
      _audioPlayer.stop(); // Don't await stop to minimize delay
      await _audioPlayer.play(AssetSource('audio/$soundFile.$ext'));
    } catch (e) {
      debugPrint('Error playing preview: $e');
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
      final url =
          '${AppConstants.baseUrl}/get_profile_details?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == true) {
        final fetchedUserType = (data['data']['basic_info']?['user_type'] ?? '')
            .toString();
        if (mounted) setState(() => _userType = fetchedUserType);
      }
    } catch (e) {
      debugPrint('Settings: failed to fetch user type: $e');
    }

    String? notificationSound = await storage.read(key: 'notification_sound');

    setState(() {
      _isFingerprintEnabled = serverEnabled;
      _hasToken = token != null;
      _selectedNotificationSound = notificationSound ?? 'default';
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
            '${AppConstants.baseUrl}/update_biometric_status';
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
            if (value) {
              context.showSuccessSnackBar('settings.fingerprint_enabled_msg'.tr(context));
            } else {
              context.showWarningSnackBar('settings.fingerprint_disabled_msg'.tr(context));
            }
          }
        } else {
          if (mounted) {
            context.showErrorSnackBar(
              'main.error_with_msg'.tr(
                context,
                args: {'message': data['message'] ?? 'Error'},
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error toggle fingerprint: $e');
        if (mounted) {
          context.showErrorSnackBar('login.conn_error'.tr(context));
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
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'settings.delete_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'settings.delete_confirm_desc'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'settings.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
        final url = '${AppConstants.baseUrl}/delete_biometric';
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
            context.showSuccessSnackBar('settings.delete_success'.tr(context));
          }
        } else {
          if (mounted) {
            context.showErrorSnackBar(
              'main.error_with_msg'.tr(
                context,
                args: {'message': data['message'] ?? 'Error'},
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error delete fingerprint: $e');
        if (mounted) {
          context.showErrorSnackBar('login.conn_error'.tr(context));
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'settings.register_desc'.tr(context),
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
        const url = '${AppConstants.baseUrl}/register_biometric';

        String? password = await _promptForPassword();
        if (password == null) return; // user tekan Batal

        // Baru set loading SETELAH dialog ditutup
        setState(() => _isLoading = true);

        final String identifier = (widget.userData['username']?.toString().isNotEmpty == true)
            ? widget.userData['username'].toString()
            : (widget.userData['email']?.toString() ?? '');

        debugPrint('--- Register Biometric Debug ---');
        debugPrint('Identifier to send: "$identifier"');
        debugPrint('Password length: ${password.length}');
        debugPrint('--------------------------------');

        final response = await http.post(
          Uri.parse(url),
          body: {
            'identifier': identifier,
            'password': password,
            'biometric_token': biometricToken,
            'device_info': 'settings.device_info'.tr(context),
          },
        );

        debugPrint('Settings Register Biometric Response Body: ${response.body}');
        final data = json.decode(response.body);
        if (data['status'] == true) {
          await storage.write(key: 'biometric_token', value: biometricToken);
          await storage.write(key: 'fingerprint_enabled', value: 'true');

          setState(() {
            _hasToken = true;
            _isFingerprintEnabled = true;
          });

          context.showSuccessSnackBar('settings.reg_success'.tr(context));
        } else {
          context.showErrorSnackBar(
            'main.error_with_msg'.tr(
              context,
              args: {'message': data['message'] ?? 'Error'},
            ),
          );
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
    bool obscureText = true;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                  obscureText: obscureText,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'settings.enter_password'.tr(context),
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setModalState(() {
                          obscureText = !obscureText;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (value) {
                    final p = value.trim();
                    if (p.isNotEmpty) {
                      Navigator.pop(context, p);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'settings.cancel'.tr(context),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final p = passwordController.text.trim();
                          context.showWarningSnackBar('login.password_required'.tr(context));
                        Navigator.pop(context, p);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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

  Future<void> _showNotificationSoundDialog() async {
    final List<Map<String, String>> sounds = [
      {'id': 'default', 'label': 'settings.sound_default'},
      {
        'id': 'elegant_notification_sound',
        'label': 'settings.sound_elegant'
      },
      {'id': 'message_ringtone_magic', 'label': 'settings.sound_magic'},
      {'id': 'relax_message_tone', 'label': 'settings.sound_relax'},
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                    Icons.notifications_active_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'settings.select_notification_sound'.tr(context),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: sounds.map((sound) {
                        final isSelected =
                            _selectedNotificationSound == sound['id'];
                        final soundId = sound['id']!;

                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: Radio<String>(
                            value: soundId,
                            groupValue: _selectedNotificationSound,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (value) async {
                              if (value != null) {
                                await storage.write(
                                  key: 'notification_sound',
                                  value: value,
                                );
                                setSheetState(() {
                                  _selectedNotificationSound = value;
                                });
                                setState(() {
                                  _selectedNotificationSound = value;
                                });
                                _playPreview(value);
                                NotificationService().createChannel();
                                NotificationService()
                                    .updateTokenOnServer(widget.userData);
                              }
                            },
                          ),
                          title: Text(
                            sound['label']!.tr(context),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          onTap: () async {
                            await storage.write(
                              key: 'notification_sound',
                              value: soundId,
                            );
                            setSheetState(() {
                              _selectedNotificationSound = soundId;
                            });
                            setState(() {
                              _selectedNotificationSound = soundId;
                            });
                            
                            // Always play preview on tap, even if already selected
                            _playPreview(soundId);
                            
                            NotificationService().createChannel();
                            NotificationService()
                                .updateTokenOnServer(widget.userData);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      _audioPlayer.stop();
    });
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            RadioListTile<ThemeMode>(
              title: Text('settings.theme_system'.tr(context)),
              secondary: const Icon(
                Icons.brightness_4_rounded,
                color: Color(0xFF7E57C2),
              ),
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
              secondary: const Icon(
                Icons.light_mode_rounded,
                color: Color(0xFF7E57C2),
              ),
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
              secondary: const Icon(
                Icons.dark_mode_rounded,
                color: Color(0xFF7E57C2),
              ),
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
      appBar: SecondaryAppBar(title: 'main.xin_settings'.tr(context)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader(context, 'settings.language'.tr(context)),
                _buildSeamlessCard(
                  context,
                  child: ListTile(
                    leading: _buildIconContainer(context, Icons.language_rounded),
                    title: Text('settings.language'.tr(context)),
                    subtitle: Text(
                      Provider.of<LanguageProvider>(context).locale.languageCode == 'id'
                          ? 'Bahasa Indonesia'
                          : 'English',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _showLanguageDialog,
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader(context, 'settings.theme'.tr(context)),
                _buildSeamlessCard(
                  context,
                  child: ListTile(
                    leading: _buildIconContainer(
                      context,
                      Provider.of<ThemeProvider>(context).themeMode == ThemeMode.system
                          ? Icons.brightness_4_rounded
                          : Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                    ),
                    title: Text('settings.theme'.tr(context)),
                    subtitle: Text(
                      Provider.of<ThemeProvider>(context).themeMode == ThemeMode.system
                          ? 'settings.theme_system'.tr(context)
                          : Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                              ? 'settings.theme_light'.tr(context)
                              : 'settings.theme_dark'.tr(context),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _showThemeDialog,
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader(context, 'settings.notification'.tr(context)),
                _buildSeamlessCard(
                  context,
                  child: ListTile(
                    leading: _buildIconContainer(context, Icons.notifications_active_outlined),
                    title: Text('settings.notification_sound'.tr(context)),
                    subtitle: Text(
                      'settings.sound_$_selectedNotificationSound'.tr(context),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _showNotificationSoundDialog,
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader(context, 'settings.fingerprint'.tr(context)),
                _buildSeamlessCard(
                  context,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildIconContainer(context, Icons.fingerprint,
                            color: Theme.of(context).colorScheme.primary),
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
                        _buildDivider(context),
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72, right: 16),
                          title: Text(
                            'settings.re_register'.tr(context),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: _registerBiometric,
                        ),
                        _buildDivider(context),
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72, right: 16),
                          title: Text(
                            'settings.delete_fingerprint'.tr(context),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: _deleteFingerprint,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader(context, 'settings.account'.tr(context)),
                _buildSeamlessCard(
                  context,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF7E57C2),
                        backgroundImage: (widget.userData['profile_photo'] != null &&
                                widget.userData['profile_photo'].toString().isNotEmpty)
                            ? CachedNetworkImageProvider(
                                '${AppConstants.serverRoot}/public/uploads/users/thumb/${widget.userData['profile_photo']}',
                              )
                            : null,
                        child: (widget.userData['profile_photo'] == null ||
                                widget.userData['profile_photo'].toString().isEmpty)
                            ? Text(
                                (widget.userData['nama'] ?? 'U').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                              )
                            : null,
                      ),
                    ),
                    title: Text(
                      widget.userData['nama'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      widget.userData['email'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader(context, 'settings.app_info'.tr(context)),
                _buildSeamlessCard(
                  context,
                  child: Column(
                    children: [
                      _buildInfoTile(
                        context,
                        icon: Icons.info_outline,
                        title: 'settings.app_version'.tr(context),
                        trailing: _appVersion,
                      ),
                      _buildDivider(context),
                      _buildInfoTile(
                        context,
                        icon: Icons.shield_outlined,
                        title: 'settings.privacy_policy'.tr(context),
                        onTap: () => _launchURL('${AppConstants.serverRoot}/erp/privacy'),
                      ),
                      _buildDivider(context),
                      _buildInfoTile(
                        context,
                        icon: Icons.help_outline,
                        title: 'settings.help_support'.tr(context),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HelpdeskListPage(userData: widget.userData),
                            ),
                          );
                        },
                      ),
                      _buildDivider(context),
                      _buildInfoTile(
                        context,
                        icon: Icons.business_outlined,
                        title: 'Iskom Sarana Nusantara',
                        trailing: '© 2026',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader(context, 'settings.diagnosis'.tr(context)),
                _buildSeamlessCard(
                  context,
                  child: ListTile(
                    leading: _buildIconContainer(context, Icons.notifications_active_outlined),
                    title: Text('settings.diagnosis'.tr(context)),
                    subtitle: Text('settings.diagnosis_desc'.tr(context)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DiagnosisHubPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                if (_userType == 'customer') ...[
                  _buildSectionHeader(context, 'delete_account.section_title'.tr(context),
                      isDanger: true),
                  _buildSeamlessCard(
                    context,
                    isDanger: true,
                    child: ListTile(
                      leading: _buildIconContainer(context, Icons.delete_forever_outlined,
                          isDanger: true),
                      title: Text(
                        'delete_account.btn_label'.tr(context),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('delete_account.btn_desc'.tr(context)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.red, size: 20),
                      onTap: _showDeleteAccountSheet,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isDanger ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSeamlessCard(BuildContext context, {required Widget child, bool isDanger = false}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDanger
              ? Colors.red.withValues(alpha: 0.2)
              : Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }

  Widget _buildIconContainer(BuildContext context, IconData icon,
      {Color? color, bool isDanger = false}) {
    final themeColor = color ?? const Color(0xFF7E57C2);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            isDanger ? Colors.red.withValues(alpha: 0.1) : themeColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isDanger ? Colors.red : themeColor,
        size: 20,
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: _buildIconContainer(context, icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: trailing != null
          ? Text(
              trailing,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            )
          : (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
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
          context.showErrorSnackBar(
            'settings.link_error'.tr(context, args: {'error': e.toString()}),
          );
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'delete_account.sheet_title'.tr(context),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scroll hint
                if (!hasScrolledToBottom)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_downward,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'delete_account.scroll_hint'.tr(context),
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
                // Checkbox + Button (bottom fixed)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
                    ),
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
                                  ? (v) => setSheetState(
                                      () => hasAgreed = v ?? false,
                                    )
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
                                        color: Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(24),
                                            ),
                                      ),
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 4,
                                            margin: const EdgeInsets.only(
                                              bottom: 24,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(
                                                0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          Text(
                                            'delete_account.confirm_title'.tr(
                                              context,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'delete_account.confirm_desc'.tr(
                                              context,
                                            ),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    side: BorderSide(
                                                      color: Colors.grey
                                                          .withOpacity(0.3),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'settings.cancel'.tr(
                                                      context,
                                                    ),
                                                    style: TextStyle(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: Text(
                                                    'delete_account.confirm_btn'
                                                        .tr(context),
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
                            backgroundColor: hasAgreed && hasScrolledToBottom
                                ? Colors.red
                                : Colors.grey[300],
                            foregroundColor: hasAgreed && hasScrolledToBottom
                                ? Colors.white
                                : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
        Uri.parse('${AppConstants.baseUrl}/delete_account'),
        body: {'user_id': userId},
      );

      final data = json.decode(response.body);
      if (data['status'] == true) {
        // Clear all local storage
        await storage.deleteAll();

        if (mounted) {
          context.showSuccessSnackBar('delete_account.success'.tr(context));
          // Navigate back to login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        context.showErrorSnackBar(
          data['message'] ?? 'delete_account.error'.tr(context),
        );
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
      context.showErrorSnackBar('delete_account.error'.tr(context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
