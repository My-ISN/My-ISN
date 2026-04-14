import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_snackbar.dart';
import '../services/quick_send_service.dart';
import '../widgets/secondary_app_bar.dart';

class QuickSendAddPage extends StatefulWidget {
  const QuickSendAddPage({super.key});

  @override
  State<QuickSendAddPage> createState() => _QuickSendAddPageState();
}

class _QuickSendAddPageState extends State<QuickSendAddPage> {
  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emojiController = TextEditingController(text: '💬');
  final _tplController = TextEditingController();
  final QuickSendService _service = QuickSendService();

  final List<Map<String, TextEditingController>> _items = [];
  String _selectedColor = '#7E57C2';
  bool _isSaving = false;

  final List<String> _presets = [
    '#7E57C2', '#FF4D6D', '#4CAF50', '#2196F3', '#FF9800', '#00BCD4'
  ];

  @override
  void initState() {
    super.initState();
    _addItem(); // Start with one empty item
  }

  @override
  void dispose() {
    _namaController.dispose();
    _phoneController.dispose();
    _emojiController.dispose();
    _tplController.dispose();
    for (var item in _items) {
      item['nama']?.dispose();
      item['satuan']?.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add({
        'nama': TextEditingController(),
        'satuan': TextEditingController(),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index]['nama']?.dispose();
      _items[index]['satuan']?.dispose();
      _items.removeAt(index);
    });
  }

  void _save() async {
    final nama = _namaController.text.trim();
    final phone = _phoneController.text.trim();

    if (nama.isEmpty || phone.isEmpty) {
      CustomSnackBar.showWarning(context, 'Nama dan Nomor HP wajib diisi');
      return;
    }

    final List<Map<String, String>> itemData = [];
    for (var item in _items) {
      final itemNama = item['nama']!.text.trim();
      if (itemNama.isNotEmpty) {
        itemData.add({
          'nama_item': itemNama,
          'satuan': item['satuan']!.text.trim(),
        });
      }
    }

    setState(() => _isSaving = true);

    final res = await _service.saveContact(
      nama: nama,
      phone: phone,
      emoji: _emojiController.text.trim(),
      color: _selectedColor,
      template: _tplController.text.trim(),
      items: itemData,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['status'] == true) {
        Navigator.pop(context, true);
        CustomSnackBar.showSuccess(context, 'Kontak dan pesanan berhasil disimpan');
      } else {
        CustomSnackBar.showError(context, res['message'] ?? 'Gagal menyimpan data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: SecondaryAppBar(
        title: 'Tambah Kontak',
        actions: [
          if (!_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _save,
                child: Text(
                  'SIMPAN',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('INFORMASI KONTAK'),
                  _buildCard([
                    _buildTextField(_namaController, 'Nama Kontak', Icons.person_rounded),
                    const SizedBox(height: 16),
                    _buildTextField(_phoneController, 'Nomor WhatsApp', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                  ]),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('TAMPILAN KARTU'),
                  _buildCard([
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildTextField(_emojiController, 'Icon', null, textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pilih Warna', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _presets.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final hex = _presets[index];
                                    final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                                    final isSelected = _selectedColor == hex;
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedColor = hex),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                                        ),
                                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildSectionTitle('TEMPLATE PESAN DEFAULT'),
                  _buildTextField(_tplController, 'Contoh: Halo {nama}, mau pesan {pesanan}. Terima kasih 🙏', null, maxLines: 3),
                  const SizedBox(height: 12),
                  Text(
                    'Gunakan {nama} dan {pesanan} sebagai variabel otomatis.',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('DAFTAR PESANAN / ITEM'),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('TAMBAH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                      ),
                    ],
                  ),
                  ...List.generate(_items.length, (index) => _buildItemRow(index)),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.brightness == Brightness.dark
          ? theme.primaryColor.withValues(alpha: 0.04)
          : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildTextField(_items[index]['nama']!, 'Nama Item', null),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildTextField(_items[index]['satuan']!, 'Satuan', null),
          ),
          if (_items.length > 1)
            IconButton(
              onPressed: () => _removeItem(index),
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300], size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData? icon, {TextInputType? keyboardType, TextAlign textAlign = TextAlign.start, int maxLines = 1}) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: textAlign,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.7)) : null,
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? theme.primaryColor.withValues(alpha: 0.06)
            : theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
