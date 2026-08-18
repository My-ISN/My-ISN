import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/secondary_app_bar.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/barcode_scanner_page.dart';
import '../../services/rent_plan_service.dart';
import 'rent_plan_detail_page.dart';

class ScanLaptopDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? initialBarcode;

  const ScanLaptopDetailPage({
    super.key,
    required this.userData,
    this.initialBarcode,
  });

  @override
  State<ScanLaptopDetailPage> createState() => _ScanLaptopDetailPageState();
}

class _ScanLaptopDetailPageState extends State<ScanLaptopDetailPage> {
  final RentPlanService _service = RentPlanService();
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  bool _isLoading = false;
  Map<String, dynamic>? _unitData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLaptopDetail(widget.initialBarcode!);
      });
    } else {
      // Auto open camera on first launch if no barcode provided
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openScanner();
      });
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    _barcodeFocusNode.unfocus();
    final String? scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (scanned != null && scanned.trim().isNotEmpty) {
      _barcodeController.text = scanned.trim();
      await _fetchLaptopDetail(scanned.trim());
    }
  }

  Future<void> _fetchLaptopDetail(String barcode) async {
    final query = barcode.trim();
    if (query.isEmpty) return;

    _barcodeFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _unitData = null;
    });

    try {
      final res = await _service.getLaptopDetailScan(query);
      if (!mounted) return;

      if (res['status'] == true && res['data'] != null) {
        setState(() {
          _unitData = Map<String, dynamic>.from(res['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message'] ?? 'Unit laptop tidak ditemukan.';
        });
        context.showErrorSnackBar(_errorMessage!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
      context.showErrorSnackBar('Gagal memuat detail laptop.');
    }
  }

  void _showDamageNotesModal() {
    if (_unitData == null) return;

    final String currentBarcode = _unitData!['barcode'] ?? _barcodeController.text.trim();
    final int? unitId = _unitData!['id'] != null ? int.tryParse(_unitData!['id'].toString()) : null;
    String selectedKondisi = _unitData!['kondisi'] ?? 'Baru';
    String selectedStatus = _unitData!['status'] ?? 'Tersedia';
    final TextEditingController newNoteController = TextEditingController();
    bool isSaving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2026) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E57C2).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF7E57C2),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catat Masalah / Update Unit',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  _unitData!['nama_laptop'] ?? currentBarcode,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Pilihan Kondisi
                      Text(
                        'Kondisi Laptop',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Baru', 'Bekas', 'Rusak', 'Perlu Servis'].map((k) {
                          final isSelected = selectedKondisi == k;
                          Color activeCol = const Color(0xFF7E57C2);
                          if (k == 'Rusak' || k == 'Perlu Servis') activeCol = Colors.redAccent;
                          if (k == 'Baru') activeCol = Colors.green;

                          return ChoiceChip(
                            label: Text(k),
                            selected: isSelected,
                            selectedColor: activeCol.withValues(alpha: 0.2),
                            backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                            side: BorderSide(
                              color: isSelected ? activeCol : Colors.transparent,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? activeCol : Theme.of(context).colorScheme.onSurface,
                            ),
                            onSelected: (val) {
                              if (val) setModalState(() => selectedKondisi = k);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Pilihan Status
                      Text(
                        'Status Unit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Tersedia', 'Disewa', 'Rusak', 'Maintenance'].map((s) {
                          final isSelected = selectedStatus == s;
                          Color activeCol = const Color(0xFF7E57C2);
                          if (s == 'Rusak') activeCol = Colors.redAccent;
                          if (s == 'Tersedia') activeCol = Colors.green;
                          if (s == 'Maintenance') activeCol = Colors.orange;

                          return ChoiceChip(
                            label: Text(s),
                            selected: isSelected,
                            selectedColor: activeCol.withValues(alpha: 0.2),
                            backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                            side: BorderSide(
                              color: isSelected ? activeCol : Colors.transparent,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? activeCol : Theme.of(context).colorScheme.onSurface,
                            ),
                            onSelected: (val) {
                              if (val) setModalState(() => selectedStatus = s);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Input Catatan Baru
                      Text(
                        'Tambah Catatan Masalah / Kerusakan Baru',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: newNoteController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Layar bergaris horizontal, engsel kiri goyang...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF15171C) : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setModalState(() => isSaving = true);
                                  final res = await _service.updateLaptopDamageNotes(
                                    barcode: currentBarcode,
                                    unitId: unitId,
                                    kondisi: selectedKondisi,
                                    status: selectedStatus,
                                    catatan: newNoteController.text.trim(),
                                  );

                                  if (res['status'] == true) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (!mounted) return;
                                    context.showSuccessSnackBar(res['message'] ?? 'Data berhasil disimpan');
                                    await _fetchLaptopDetail(currentBarcode);
                                  } else {
                                    setModalState(() => isSaving = false);
                                    if (!mounted) return;
                                    context.showErrorSnackBar(res['message'] ?? 'Gagal menyimpan perubahan');
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          label: Text(
                            isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '62${cleanNumber.substring(1)}';
    }
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) context.showErrorSnackBar('Tidak dapat membuka WhatsApp');
    }
  }

  Future<void> _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) context.showErrorSnackBar('Tidak dapat melakukan panggilan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7E57C2);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(
        title: 'Scan Barcode Laptop',
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Buka Kamera Scan',
            onPressed: _openScanner,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search & Trigger Card ──────────────────────────────────────
            _buildSearchCard(isDark, primaryColor),
            const SizedBox(height: 16),

            // ── Loading Indicator ───────────────────────────────────────────
            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Memeriksa database laptop...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Error State ────────────────────────────────────────────────
            if (!_isLoading && _errorMessage != null && _unitData == null)
              _buildErrorCard(isDark),

            // ── Laptop Detail Content ───────────────────────────────────────
            if (!_isLoading && _unitData != null) ...[
              _buildLaptopIdentityCard(isDark, primaryColor),
              const SizedBox(height: 14),
              _buildRentalStatusCard(isDark, primaryColor),
              const SizedBox(height: 14),
              _buildDamageNotesCard(isDark, primaryColor),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15171C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300]!,
                    ),
                  ),
                  child: TextField(
                    controller: _barcodeController,
                    focusNode: _barcodeFocusNode,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ketik Barcode / Serial Number...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: primaryColor),
                      suffixIcon: _barcodeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _barcodeController.clear();
                                setState(() {
                                  _unitData = null;
                                  _errorMessage = null;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (val) => _fetchLaptopDetail(val),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Camera Scan Button
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7E57C2), Color(0xFF6A11CB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                  tooltip: 'Scan Kamera',
                  onPressed: _openScanner,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Arahkan kamera ke stiker barcode / ketik SN',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_barcodeController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _fetchLaptopDetail(_barcodeController.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Cari Data',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1919) : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Tidak Ditemukan',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorMessage ?? 'Laptop dengan barcode tersebut belum terdaftar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.red[200] : Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaptopIdentityCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;
    final String modelName = _unitData!['nama_laptop'] ?? 'Unit Laptop';
    final String barcode = _unitData!['barcode'] ?? '-';
    final String sn = _unitData!['serial_number'] ?? '-';
    final String kondisi = _unitData!['kondisi'] ?? 'Baru';
    final String status = _unitData!['status'] ?? 'Tersedia';
    final String tanggalMasuk = _unitData!['tanggal_masuk'] ?? '-';

    Color statusColor = Colors.green;
    if (status == 'Disewa') statusColor = const Color(0xFF7E57C2);
    if (status == 'Rusak') statusColor = Colors.redAccent;
    if (status == 'Maintenance') statusColor = Colors.orange;

    Color kondisiColor = Colors.green;
    if (kondisi == 'Rusak' || kondisi == 'Perlu Servis') kondisiColor = Colors.redAccent;
    if (kondisi == 'Bekas') kondisiColor = Colors.teal;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7E57C2), Color(0xFF5E35B1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.laptop_chromebook_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (_unitData!['kode_laptop'] != null)
                      Text(
                        'Kode: ${_unitData!['kode_laptop']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          const SizedBox(height: 14),

          // Status & Kondisi Badges
          Row(
            children: [
              _buildBadge('Status: $status', statusColor),
              const SizedBox(width: 8),
              _buildBadge('Kondisi: $kondisi', kondisiColor),
            ],
          ),
          const SizedBox(height: 14),

          // Barcode & SN details
          _buildDetailRow(
            icon: Icons.qr_code_rounded,
            label: 'Barcode',
            value: barcode,
            canCopy: true,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.tag_rounded,
            label: 'Serial Number',
            value: sn,
            canCopy: true,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Tanggal Masuk',
            value: tanggalMasuk,
          ),
        ],
      ),
    );
  }

  Widget _buildRentalStatusCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;
    final activeRental = _unitData!['active_rental'];
    final pastRentals = _unitData!['past_rentals'] as List<dynamic>? ?? [];

    if (activeRental != null) {
      // ── Sedang Disewa ─────────────────────────────────────────────────────
      final renterName = activeRental['renter_name'] ?? 'Penyewa ISN';
      final invoiceNum = activeRental['invoice_number'] ?? '-';
      final contactNum = activeRental['contact_number'] ?? '-';
      final rentalStatus = activeRental['rental_status'] ?? 'aktif';
      final startDate = activeRental['invoice_date'] ?? '-';
      final dueDate = activeRental['invoice_due_date'] ?? '-';
      final rentalId = activeRental['rental_id'];

      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7E57C2).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_pin_rounded, color: Color(0xFF7E57C2), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STATUS: SEDANG DISEWA',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: const Color(0xFF7E57C2),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                _buildBadge(rentalStatus.toUpperCase(), const Color(0xFF7E57C2)),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            const SizedBox(height: 14),

            // Penyewa Info
            Text(
              'Disewa Oleh:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              renterName,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            _buildDetailRow(
              icon: Icons.receipt_long_rounded,
              label: 'No. Invoice',
              value: invoiceNum,
              canCopy: true,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.date_range_rounded,
              label: 'Periode Sewa',
              value: '$startDate s/d $dueDate',
            ),
            if (activeRental['lama_sewa'] != null && activeRental['lama_sewa'] != '-') ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.timelapse_rounded,
                label: 'Durasi',
                value: '${activeRental['lama_sewa']} Hari',
              ),
            ],
            const SizedBox(height: 14),

            // Quick Actions: Call / WA / Detail
            Row(
              children: [
                if (contactNum != '-' && contactNum.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(contactNum),
                      icon: const Icon(Icons.chat_rounded, color: Colors.green, size: 16),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callPhone(contactNum),
                      icon: const Icon(Icons.phone_rounded, color: Colors.blueAccent, size: 16),
                      label: const Text('Telepon', style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (rentalId != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RentPlanDetailPage(
                              rentalId: rentalId is int ? rentalId : int.parse(rentalId.toString()),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
                      label: const Text('Detail Sewa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E57C2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    } else {
      // ── Tersedia di Gudang (Tidak Sedang Disewa) ───────────────────────────
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit Tersedia di Gudang',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Saat ini tidak sedang disewa oleh client.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Riwayat sewa sebelumnya jika ada
            if (pastRentals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              Text(
                'Riwayat Sewa Sebelumnya:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              ...pastRentals.take(3).map((pr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${pr['renter_name'] ?? '-'} (${pr['invoice_number'] ?? '-'})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        pr['invoice_due_date'] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildDamageNotesCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;
    final catatan = _unitData!['catatan'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_circle_rounded, color: Colors.orange, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Catatan Kerusakan & Masalah',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF7E57C2)),
                tooltip: 'Edit / Tambah Catatan',
                onPressed: _showDamageNotesModal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          const SizedBox(height: 12),

          // Tampilan catatan
          if (catatan.toString().trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF15171C) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
                ),
              ),
              child: Text(
                catatan.toString().trim(),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF15171C) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Belum ada catatan masalah atau kerusakan untuk unit ini.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDamageNotesModal,
              icon: const Icon(Icons.add_comment_rounded, size: 16, color: Color(0xFF7E57C2)),
              label: const Text(
                'Catat Masalah / Kerusakan Laptop',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E57C2),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7E57C2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool canCopy = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7E57C2)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (canCopy && value != '-')
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              context.showSuccessSnackBar('$label disalin ke clipboard');
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.copy_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }
}
