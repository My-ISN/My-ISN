import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_service.dart';
import '../widgets/custom_snackbar.dart';

class PasswordDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> account;

  const PasswordDetailPage({
    super.key,
    required this.userData,
    required this.account,
  });

  @override
  State<PasswordDetailPage> createState() => _PasswordDetailPageState();
}

class _PasswordDetailPageState extends State<PasswordDetailPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  final PasswordService _passwordService = PasswordService();

  bool _isLoading = true;
  List<dynamic> _services = [];
  List<dynamic> _entries = [];

  final Map<String, bool> _obscuredStates = {};

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (mounted) setState(() => _isLoading = true);
    final idAcc = widget.account['id_acc'];
    final response = await _passwordService.getPasswordDetails(idAcc);
    if (response['status'] == true) {
      if (mounted) {
        setState(() {
          _services = response['services'] ?? [];
          _entries = response['entries'] ?? [];

          for (var entry in _entries) {
            final entryId = entry['id_pass'].toString();
            for (var svc in _services) {
              final svcId = svc['id_service'].toString();
              final type = svc['type'] ?? '';
              if (type == 'password' || type == 'pin') {
                _obscuredStates['${entryId}_$svcId'] = true;
              }
            }
          }

          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value)).then((_) {
      if (mounted) {
        CustomSnackBar.showSuccess(context, '$label copied to clipboard!');
      }
    });
  }

  void _showAddEntrySheet() {
    if (_services.isEmpty) {
      CustomSnackBar.showError(
        context,
        'Akun ini belum memiliki kolom/fields. Tambahkan terlebih dahulu melalui ERP.',
      );
      return;
    }

    final descController = TextEditingController();
    final Map<String, TextEditingController> fieldControllers = {};
    for (var svc in _services) {
      fieldControllers[svc['id_service'].toString()] = TextEditingController();
    }
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final sheetColor = isDark
              ? Theme.of(context).colorScheme.surfaceContainerLow
              : Colors.white;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_rounded, color: _primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Credential',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                (widget.account['name'] ?? '').toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                  // Form Fields
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description
                          _buildFormLabel('Nama / Deskripsi'),
                          const SizedBox(height: 6),
                          _buildFormField(
                            controller: descController,
                            hint: 'e.g. Akun Utama, Admin, dll.',
                            isPassword: false,
                          ),
                          const SizedBox(height: 16),
                          // Dynamic Fields
                          ...(_services.map((svc) {
                            final svcId = svc['id_service'].toString();
                            final svcName = svc['name'] ?? '';
                            final svcType = svc['type'] ?? '';
                            final isPass = svcType == 'password' || svcType == 'pin';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormLabel(svcName),
                                const SizedBox(height: 6),
                                _buildFormField(
                                  controller: fieldControllers[svcId]!,
                                  hint: isPass ? '••••••••' : 'Masukkan $svcName',
                                  isPassword: isPass,
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          })),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  // Save Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                final fieldsMap = <String, String>{};
                                for (var svc in _services) {
                                  final svcId = svc['id_service'].toString();
                                  final val = fieldControllers[svcId]!.text.trim();
                                  if (val.isNotEmpty) fieldsMap[svcId] = val;
                                }
                                final result = await _passwordService.savePasswordEntry(
                                  idAcc: widget.account['id_acc'],
                                  description: descController.text.trim(),
                                  fields: fieldsMap,
                                );
                                setModalState(() => isSaving = false);
                                if (result['status'] == true) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  CustomSnackBar.showSuccess(context, 'Credential berhasil disimpan!');
                                  _fetchDetails();
                                } else {
                                  CustomSnackBar.showError(context, result['message'] ?? 'Gagal menyimpan');
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Simpan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String hint,
    required bool isPassword,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _deleteEntry(dynamic idPass) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(ctx).colorScheme.surfaceContainerLow
                : Theme.of(ctx).scaffoldBackgroundColor,
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
                  color: Theme.of(ctx).dividerColor.withValues(alpha: 0.2),
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
                'Hapus Credential?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tindakan ini tidak dapat dibatalkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Theme.of(ctx).dividerColor.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Hapus'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
    if (confirm != true) return;
    final result = await _passwordService.deletePasswordEntry(
      idPass: idPass,
      idAcc: widget.account['id_acc'],
    );
    if (result['status'] == true) {
      CustomSnackBar.showSuccess(context, 'Credential dihapus');
      _fetchDetails();
    } else {
      CustomSnackBar.showError(context, result['message'] ?? 'Gagal menghapus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String accountName = (widget.account['name'] ?? '').toString().toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          accountName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEntrySheet,
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tambah',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetails,
        color: _primaryColor,
        child: _isLoading
            ? _buildLoadingState()
            : _entries.isEmpty
                ? _buildEmptyState()
                : _buildEntriesList(isDark),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: CircularProgressIndicator(color: _primaryColor));
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.vpn_key_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada credential',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tekan tombol Tambah untuk menambahkan',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntriesList(bool isDark) {
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Colors.white;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final entryId = entry['id_pass'].toString();
        final String description = entry['description'] ?? 'Unnamed Entry';
        final Map<String, dynamic> fields = entry['fields'] ?? {};

        return Dismissible(
          key: Key(entryId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[400],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
          ),
          confirmDismiss: (_) async {
            await _deleteEntry(entry['id_pass']);
            return false; // We handle removal manually via _fetchDetails
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
              border: isDark
                  ? Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: isDark ? 0.15 : 0.06),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          description,
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.swipe_left_outlined,
                        size: 14,
                        color: _primaryColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Geser untuk hapus',
                        style: TextStyle(
                          fontSize: 10,
                          color: _primaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _services.map((svc) {
                      final svcId = svc['id_service'].toString();
                      final svcName = svc['name'] ?? '';
                      final svcType = svc['type'] ?? '';
                      final value = (fields[svcId] ?? '').toString();

                      if (value.isEmpty) return const SizedBox.shrink();

                      final isSensitive = (svcType == 'password' || svcType == 'pin');
                      final isObscured = _obscuredStates['${entryId}_$svcId'] ?? false;
                      final displayText = isSensitive && isObscured ? '••••••••' : value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    svcName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSensitive)
                                  IconButton(
                                    icon: Icon(
                                      isObscured
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscuredStates['${entryId}_$svcId'] = !isObscured;
                                      });
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.copy_rounded, size: 18, color: _primaryColor),
                                  onPressed: () => _copyToClipboard(svcName, value),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
