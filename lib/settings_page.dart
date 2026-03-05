import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
                      ? 'Fingerprint diaktifkan'
                      : 'Fingerprint dinonaktifkan',
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
                  'Gagal: ${data['message'] ?? 'Error tidak diketahui'}',
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
              content: Text('Koneksi Error: $e'),
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
        title: const Text('Hapus Fingerprint?'),
        content: const Text(
          'Ini akan menghapus data sidik jari Anda dari aplikasi ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
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
              const SnackBar(
                content: Text(
                  'Data fingerprint berhasil dihapus secara permanen',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Gagal Hapus: ${data['message'] ?? 'Error tidak diketahui'}',
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
              content: Text('Koneksi Error: $e'),
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
        title: const Text('Daftarkan Fingerprint'),
        content: const Text(
          'Anda perlu mendaftarkan sidik jari Anda terlebih dahulu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerBiometric() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan sidik jari untuk mendaftarkan login biometrik',
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
              const SnackBar(
                content: Text('Fingerprint berhasil didaftarkan!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal: ${data['message']}'),
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
        title: const Text('Konfirmasi Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Masukkan password Anda'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, passwordController.text.trim()),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Keamanan & Biometrik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                            Icons.fingerprint,
                            color: Color(0xFF7E57C2),
                          ),
                        ),
                        title: const Text('Login dengan Fingerprint'),
                        subtitle: Text(
                          _hasToken ? 'Sudah terdaftar' : 'Belum terdaftar',
                        ),
                        trailing: Switch(
                          value: _isFingerprintEnabled,
                          onChanged: _toggleFingerprint,
                          activeColor: const Color(0xFF7E57C2),
                        ),
                      ),
                      if (_hasToken) ...[
                        const Divider(height: 1, indent: 70),
                        ListTile(
                          leading: const SizedBox(width: 40),
                          title: const Text(
                            'Daftarkan Ulang Sidik Jari',
                            style: TextStyle(color: Color(0xFF7E57C2)),
                          ),
                          onTap: () async {
                            // Only call _registerBiometric, it will handle the scan
                            _registerBiometric();
                          },
                        ),
                        const Divider(height: 1, indent: 70),
                        ListTile(
                          leading: const SizedBox(width: 40),
                          title: const Text(
                            'Hapus Data Fingerprint',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: _deleteFingerprint,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Text(
                  'Akun',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                const Text(
                  'Informasi Aplikasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                        title: 'Versi Aplikasi',
                        trailing: '0.3.1-preview',
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildInfoTile(
                        icon: Icons.shield_outlined,
                        title: 'Kebijakan Privasi',
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildInfoTile(
                        icon: Icons.help_outline,
                        title: 'Bantuan & Dukungan',
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 70),
                      _buildInfoTile(
                        icon: Icons.business_outlined,
                        title: 'Foxgeen HRIS',
                        trailing: '© 2026',
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
}
