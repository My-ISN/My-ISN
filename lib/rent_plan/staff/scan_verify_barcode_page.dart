import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/barcode_scanner_page.dart';
import '../../../widgets/secondary_app_bar.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../services/rent_plan_service.dart';

class ScanVerifyBarcodePage extends StatefulWidget {
  const ScanVerifyBarcodePage({super.key});

  @override
  State<ScanVerifyBarcodePage> createState() => _ScanVerifyBarcodePageState();
}

class _ScanVerifyBarcodePageState extends State<ScanVerifyBarcodePage> {
  final _service = RentPlanService();

  // Scan state
  String? _scannedBarcode;
  bool _isVerifying = false;
  String? _action; // 'verified' | 'not_found'
  Map<String, dynamic>? _foundUnit;

  // Form state (for not_found)
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _laptopModels = [];
  bool _loadingModels = false;
  bool _isSaving = false;

  String? _selectedLaptopId;
  final _serialController = TextEditingController();
  String _kondisi = 'Baru';
  String _status = 'Tersedia';
  DateTime _tanggalMasuk = DateTime.now();
  final _catatanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openCamera();
    });
  }

  @override
  void dispose() {
    _serialController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    final String? scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scanned != null && scanned.isNotEmpty) {
      await _verify(scanned);
    } else {
      if (_scannedBarcode == null && mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _verify(String barcode) async {
    setState(() {
      _scannedBarcode = barcode;
      _isVerifying = true;
      _action = null;
      _foundUnit = null;
    });

    final res = await _service.verifyLaptopBarcode(barcode);

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      if (res['status'] == true) {
        _action = res['action'];
        if (_action == 'verified') {
          _foundUnit = Map<String, dynamic>.from(res['data'] ?? {});
        } else if (_action == 'not_found') {
          _loadLaptopModels();
        }
      } else {
        context.showErrorSnackBar(res['message'] ?? 'Terjadi kesalahan');
        _action = null;
        _scannedBarcode = null;
      }
    });
  }

  Future<void> _loadLaptopModels() async {
    setState(() => _loadingModels = true);
    final res = await _service.getRentFormData();
    if (mounted) {
      setState(() {
        _loadingModels = false;
        if (res['status'] == true) {
          _laptopModels =
              List<Map<String, dynamic>>.from(res['data']['laptops'] ?? []);
        }
      });
    }
  }

  Future<void> _saveNewUnit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLaptopId == null) {
      context.showErrorSnackBar('Pilih model laptop terlebih dahulu');
      return;
    }

    setState(() => _isSaving = true);
    final res = await _service.createLaptopUnitFromScan(
      barcode: _scannedBarcode!,
      laptopId: _selectedLaptopId!,
      serialNumber: _serialController.text.trim(),
      kondisi: _kondisi,
      status: _status,
      tanggalMasuk:
          '${_tanggalMasuk.year}-${_tanggalMasuk.month.toString().padLeft(2, '0')}-${_tanggalMasuk.day.toString().padLeft(2, '0')}',
      catatan: _catatanController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['status'] == true) {
      setState(() {
        _action = 'verified';
        _foundUnit = Map<String, dynamic>.from(res['data'] ?? {});
      });
    } else {
      context.showErrorSnackBar(res['message'] ?? 'Gagal menyimpan unit');
    }
  }

  void _reset() {
    setState(() {
      _scannedBarcode = null;
      _action = null;
      _foundUnit = null;
      _selectedLaptopId = null;
      _serialController.clear();
      _catatanController.clear();
      _kondisi = 'Baru';
      _status = 'Tersedia';
      _tanggalMasuk = DateTime.now();
    });
    _openCamera();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SecondaryAppBar(
        title: 'Verifikasi Barcode',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Scan Button ─────────────────────────────────────────
            if (_action == null) ...[
              _buildScanPromptCard(primaryColor),
            ],

            // ── Verifying indicator ──────────────────────────────────
            if (_isVerifying)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Memeriksa barcode...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // ── VERIFIED result ──────────────────────────────────────
            if (_action == 'verified' && _foundUnit != null) ...[
              _buildVerifiedCard(primaryColor),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 18),
                label: Text(
                  'Scan Barcode Lain',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],

            // ── NOT FOUND — Add Form ─────────────────────────────────
            if (_action == 'not_found' && !_isVerifying) ...[
              _buildNotFoundHeader(),
              const SizedBox(height: 16),
              _buildAddForm(primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanPromptCard(Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2026) : Theme.of(context).cardColor;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Scan Barcode Laptop',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan sticker barcode pada unit laptop.\nJika ditemukan → langsung diverifikasi.\nJika belum ada → isi form pendaftaran.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Buka Kamera',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedCard(Color primaryColor) {
    final isNew = _foundUnit!['created_at'] != null &&
        (_foundUnit!['id'] != null) &&
        _action == 'verified' &&
        _foundUnit!['verified'] == 1;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2026) : Theme.of(context).cardColor;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withValues(alpha: isDark ? 0.3 : 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNew ? 'Unit Berhasil Didaftarkan!' : 'Barcode Terverifikasi!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      isNew ? 'Unit baru ditambahkan & diverifikasi' : 'Barcode ditemukan dan status diperbarui',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          _infoRow(primaryColor, Icons.laptop_rounded, 'Model', _foundUnit!['nama_laptop'] ?? '-'),
          _infoRow(primaryColor, Icons.qr_code_rounded, 'Barcode', _foundUnit!['barcode'] ?? _scannedBarcode ?? '-'),
          _infoRow(primaryColor, Icons.tag_rounded, 'Serial Number', _foundUnit!['serial_number'] ?? '-'),
          _infoRow(primaryColor, Icons.info_outline_rounded, 'Kondisi', _foundUnit!['kondisi'] ?? '-'),
          _infoRow(primaryColor, Icons.circle_rounded, 'Status', _foundUnit!['status'] ?? '-'),
        ],
      ),
    );
  }

  Widget _infoRow(Color primaryColor, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3E2D1A) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withValues(alpha: isDark ? 0.3 : 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Barcode Belum Terdaftar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _scannedBarcode ?? '',
                  style: TextStyle(
                    color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Isi form berikut untuk mendaftarkan unit baru.',
                  style: TextStyle(
                    color: isDark ? Colors.orange.shade400 : Colors.orange.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: isDark ? Colors.orange.shade400 : Colors.orange.shade700),
            onPressed: _reset,
            tooltip: 'Scan ulang',
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm(Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2026) : Theme.of(context).cardColor;
    final inputBg = isDark ? const Color(0xFF15171C) : Colors.grey.shade50;
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah Unit Laptop Baru',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Barcode (readonly)
            _fieldLabel('Barcode / QR *'),
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.qr_code_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scannedBarcode ?? '',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.lock_outline_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Model Laptop
            _fieldLabel('Pilih Model Laptop *'),
            if (_loadingModels)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                ),
              )
            else
              _buildDropdownField<String>(
                value: _selectedLaptopId,
                hint: 'Pilih tipe laptop...',
                items: _laptopModels
                    .map((m) => DropdownMenuItem<String>(
                          value: m['id']?.toString(),
                          child: Text(
                            m['nama_laptop'] ?? '',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLaptopId = v),
                primaryColor: primaryColor,
              ),
            const SizedBox(height: 14),

            // Serial Number
            _fieldLabel('Serial Number (SN) *'),
            _buildTextField(
              controller: _serialController,
              hint: 'Serial number dari dus...',
              icon: Icons.tag_rounded,
              primaryColor: primaryColor,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 14),

            // Kondisi
            _fieldLabel('Kondisi *'),
            _buildDropdownField<String>(
              value: _kondisi,
              hint: '',
              items: ['Baru', 'Bekas']
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v,
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _kondisi = v ?? 'Baru'),
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 14),

            // Status
            _fieldLabel('Status *'),
            _buildDropdownField<String>(
              value: _status,
              hint: '',
              items: ['Tersedia', 'Disewa', 'Rusak']
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v,
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'Tersedia'),
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 14),

            // Tanggal Masuk
            _fieldLabel('Tanggal Masuk *'),
            GestureDetector(
              onTap: () => _pickDate(primaryColor),
              child: Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(
                      '${_tanggalMasuk.day.toString().padLeft(2, '0')}/${_tanggalMasuk.month.toString().padLeft(2, '0')}/${_tanggalMasuk.year}',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Catatan
            _fieldLabel('Catatan (Opsional)'),
            _buildTextField(
              controller: _catatanController,
              hint: 'Catatan tambahan...',
              icon: Icons.notes_rounded,
              primaryColor: primaryColor,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveNewUnit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isSaving ? 'Menyimpan...' : 'Daftarkan Unit Baru',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(Color primaryColor) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalMasuk,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: Theme.of(context).cardColor,
            onSurface: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _tanggalMasuk = picked);
    }
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF15171C) : Colors.grey.shade50;
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: primaryColor),
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderCol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderCol),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required Color primaryColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF15171C) : Colors.grey.shade50;
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF1E2026) : Theme.of(context).cardColor,
          hint: Text(
            hint,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12),
          ),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
        ),
      ),
    );
  }
}
