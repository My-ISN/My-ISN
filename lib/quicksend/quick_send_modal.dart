import 'package:flutter/material.dart';
import '../widgets/custom_snackbar.dart';
import '../services/quick_send_service.dart';

class QuickSendModal extends StatefulWidget {
  final Map<String, dynamic> contact;
  final Map<String, dynamic>? userData;

  const QuickSendModal({
    super.key,
    required this.contact,
    this.userData,
  });

  @override
  State<QuickSendModal> createState() => _QuickSendModalState();
}

class _QuickSendModalState extends State<QuickSendModal> {
  final Map<int, int> _itemQtys = {};
  final TextEditingController _tplController = TextEditingController();
  final QuickSendService _service = QuickSendService();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tplController.text = widget.contact['msg_template'] ?? '';
  }

  @override
  void dispose() {
    _tplController.dispose();
    super.dispose();
  }

  String _buildMessage() {
    final List items = widget.contact['items'] ?? [];
    List<String> parts = [];

    for (int i = 0; i < items.length; i++) {
      final qty = _itemQtys[i] ?? 0;
      if (qty > 0) {
        String itemLabel = "${items[i]['nama_item']} $qty";
        String sat = (items[i]['satuan'] ?? '').toString().trim();
        
        // Safety filter for units that are likely data artifacts (numeric '1' or 'null')
        if (sat.isNotEmpty && 
            sat.toLowerCase() != "null" && 
            sat != "1") {
          itemLabel += " $sat";
        }
        parts.add(itemLabel);
      }
    }

    if (parts.isEmpty) return '';

    String pesananStr = parts.join(', ');
    String tpl = _tplController.text.trim();
    if (tpl.isEmpty) {
      tpl = 'Halo {nama}, mau pesan {pesanan}. Terima kasih 🙏';
    }

    return tpl
        .replaceAll(RegExp(r'\{nama\}', caseSensitive: false), widget.contact['nama'] ?? '')
        .replaceAll(RegExp(r'\{pesanan\}', caseSensitive: false), pesananStr)
        .replaceAll(RegExp(r'\{hp\}', caseSensitive: false), widget.contact['no_hp'] ?? '');
  }

  void _sendWA() async {
    final message = _buildMessage();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    final String rawPhones = widget.contact['no_hp'] ?? '';
    final List<String> phones = rawPhones
        .split(RegExp(r'[,;\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (phones.isEmpty) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Nomor HP tidak valid');
      }
      setState(() => _isSending = false);
      return;
    }

    try {
      int successCount = 0;
      for (String phone in phones) {
        String p = phone.replaceAll(RegExp(r'\D'), '');
        if (p.startsWith('0')) p = '62${p.substring(1)}';
        if (!p.startsWith('62')) p = '62$p';

        final res = await _service.sendWhatsApp(
          contactId: int.tryParse(widget.contact['id']?.toString() ?? '0') ?? 0,
          phone: p,
          message: message,
        );

        // Check status flexibly (handle bool, string, or int)
        final status = res['status'];
        if (status == true || status == 'true' || status == 1 || status == '1') {
          successCount++;
        }
      }

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Berhasil mengirim ke $successCount nomor');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  bool _hasPermission(String resource) {
    if (widget.userData == null) return false;
    if (widget.userData!['role_access'] == '1' ||
        widget.userData!['role_resources'] == 'all') {
      return true;
    }
    final String resources = widget.userData!['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  void _confirmDelete() {
    if (!_hasPermission('mobile_quicksend_delete')) return;
    showModalBottomSheet(
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
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Hapus Kontak?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Apakah Anda yakin ingin menghapus kontak ini beserta daftar pesanannya? Tindakan ini tidak dapat dibatalkan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
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
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteContact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(fontWeight: FontWeight.w900),
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
  }

  void _deleteContact() async {
    final contactId = int.tryParse(widget.contact['id'].toString());
    if (contactId == null) return;

    setState(() => _isSending = true);

    try {
      final res = await _service.deleteContact(contactId);
      if (mounted) {
        if (res['status'] == true) {
          CustomSnackBar.showSuccess(context, 'Kontak berhasil dihapus');
          Navigator.pop(context, true); // Return true to refresh list
        } else {
          CustomSnackBar.showError(context, res['message'] ?? 'Gagal menghapus kontak');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String emoji = widget.contact['icon_emoji'] ?? '💬';
    final String colorHex = widget.contact['color'] ?? '#7E57C2';
    final Color color = _parseHexColor(colorHex);
    final List items = widget.contact['items'] ?? [];
    final String message = _buildMessage();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.contact['nama'] ?? 'Message',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'QuickSend - Chat Cepat',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasPermission('mobile_quicksend_delete'))
                  IconButton(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                    tooltip: 'Hapus Kontak',
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    final qty = _itemQtys[index] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['nama_item'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                if (item['satuan'] != null)
                                  Text(
                                    item['satuan'],
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.dividerColor.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildQtyBtn(Icons.remove_rounded, () {
                                  if (qty > 0) {
                                    setState(() => _itemQtys[index] = qty - 1);
                                  }
                                }),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '$qty',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                _buildQtyBtn(Icons.add_rounded, () {
                                  setState(() => _itemQtys[index] = qty + 1);
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Template Pesan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _tplController.text = widget.contact['msg_template'] ?? '';
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'RESET DEFAULT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tplController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Halo {nama}, mau pesan {pesanan}...',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Preview Pesan WhatsApp',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      message.isEmpty ? '— Pilih item untuk melihat preview —' : message,
                      style: TextStyle(
                        fontSize: 13,
                        color: message.isEmpty ? Colors.grey[400] : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (message.isEmpty || _isSending) ? null : _sendWA,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Kirim via WhatsApp',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF7E57C2);
    }
  }
}
