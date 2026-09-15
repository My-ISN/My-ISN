import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/rent_plan_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/side_drawer.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/barcode_scanner_page.dart';

class SerahTerimaLaptopPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final int initialTab; // 0 = Kirim, 1 = Terima
  final Map<String, dynamic>? initialRental;
  final String? initialBarcode;

  const SerahTerimaLaptopPage({
    super.key,
    this.userData,
    this.initialTab = 0,
    this.initialRental,
    this.initialBarcode,
  });

  @override
  State<SerahTerimaLaptopPage> createState() => _SerahTerimaLaptopPageState();
}

class _SerahTerimaLaptopPageState extends State<SerahTerimaLaptopPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RentPlanService _rentPlanService = RentPlanService();
  final ImagePicker _imagePicker = ImagePicker();

  // Warna Tema Ungu HRIS
  static const Color _purplePrimary = Color(0xFF7E57C2);
  static const Color _purpleDark = Color(0xFF5E35B1);

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1: KIRIM LAPTOP STATE
  // ══════════════════════════════════════════════════════════════════════════════
  final TextEditingController _kirimSearchCtrl = TextEditingController();
  final TextEditingController _kirimBarcodeCtrl = TextEditingController();
  final TextEditingController _kirimNotesCtrl = TextEditingController();
  bool _kirimSearching = false;
  bool _kirimSubmitting = false;
  Map<String, dynamic>? _kirimSelectedRental;
  List<dynamic> _kirimSearchResults = [];
  List<XFile> _kirimPhotos = [];
  XFile? _kirimVideo;

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2: TERIMA LAPTOP STATE
  // ══════════════════════════════════════════════════════════════════════════════
  final TextEditingController _terimaBarcodeCtrl = TextEditingController();
  final TextEditingController _terimaNotesCtrl = TextEditingController();
  final FocusNode _terimaBarcodeFocus = FocusNode();
  bool _terimaSearching = false;
  bool _terimaSubmitting = false;
  Map<String, dynamic>? _terimaLaptopData;
  Map<String, dynamic>? _terimaActiveRental;
  String _terimaKondisi = 'Bagus';
  bool _kelengkapanCharger = true;
  bool _kelengkapanTas = true;
  List<XFile> _terimaPhotos = [];
  XFile? _terimaVideo;

  static const int _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );

    if (widget.initialRental != null) {
      _kirimSelectedRental = widget.initialRental;
      if (widget.initialRental!['barcode'] != null) {
        _kirimBarcodeCtrl.text = widget.initialRental!['barcode'].toString();
      }
    } else if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _kirimBarcodeCtrl.text = widget.initialBarcode!;
      _terimaBarcodeCtrl.text = widget.initialBarcode!;
      _searchKirimRental(widget.initialBarcode!);
      _searchTerimaLaptop(widget.initialBarcode!);
    } else {
      _loadInitialPendingRentals();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kirimSearchCtrl.dispose();
    _kirimBarcodeCtrl.dispose();
    _kirimNotesCtrl.dispose();
    _terimaBarcodeCtrl.dispose();
    _terimaNotesCtrl.dispose();
    _terimaBarcodeFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1 (KIRIM) LOGIC
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _loadInitialPendingRentals() async {
    setState(() => _kirimSearching = true);
    try {
      final res = await _rentPlanService.getRentPlans(status: 'pending', limit: 10);
      if (res['status'] == true && res['data'] != null) {
        setState(() => _kirimSearchResults = res['data']);
      }
    } catch (_) {}
    if (mounted) setState(() => _kirimSearching = false);
  }

  Future<void> _searchKirimRental(String query) async {
    if (query.trim().isEmpty) {
      _loadInitialPendingRentals();
      return;
    }
    setState(() => _kirimSearching = true);
    try {
      final res = await _rentPlanService.getRentPlans(search: query.trim(), limit: 15);
      if (res['status'] == true && res['data'] != null) {
        setState(() => _kirimSearchResults = res['data']);
      } else {
        final bRes = await _rentPlanService.getActiveRentalByBarcode(query.trim());
        if (bRes['status'] == true && bRes['data'] != null && bRes['data']['active_rental'] != null) {
          final rental = bRes['data']['active_rental'];
          rental['barcode'] = bRes['data']['barcode'];
          rental['nama_laptop'] = bRes['data']['nama_laptop'];
          setState(() {
            _kirimSelectedRental = rental;
            _kirimBarcodeCtrl.text = bRes['data']['barcode'] ?? '';
            _kirimSearchResults = [];
          });
        }
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Pencarian sewa gagal: $e');
    } finally {
      if (mounted) setState(() => _kirimSearching = false);
    }
  }

  Future<void> _pickKirimPhoto(ImageSource source) async {
    if (_kirimPhotos.length >= _maxPhotos) {
      context.showErrorSnackBar('Maksimal $_maxPhotos foto.');
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null) {
        setState(() => _kirimPhotos.add(image));
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal mengambil foto: $e');
    }
  }

  Future<void> _pickKirimVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (video != null) {
        setState(() => _kirimVideo = video);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal merekam video: $e');
    }
  }

  Future<void> _processKirimSubmit() async {
    if (_kirimSelectedRental == null) {
      context.showErrorSnackBar('Harap pilih penyewa / order rental terlebih dahulu.');
      return;
    }
    if (_kirimPhotos.isEmpty) {
      context.showWarningSnackBar('Wajib mengambil minimal 1 Foto Penyewa sebagai bukti serah terima.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rentalId = _kirimSelectedRental!['rental_id']?.toString() ?? '';
    final renterName = _getRenterName(_kirimSelectedRental!);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.local_shipping_rounded, color: _purplePrimary, size: 28),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Serah Terima',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laptop akan ditandai terkirim ke penyewa:',
              style: GoogleFonts.outfit(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text('• Penyewa: $renterName', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text('• Bukti: ${_kirimPhotos.length} foto penyewa', style: GoogleFonts.outfit(color: _purplePrimary)),
            if (_kirimVideo != null)
              Text('• Video: 1 video terlampir', style: GoogleFonts.outfit(color: const Color(0xFFE91E63))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purplePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kirim Sekarang', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _kirimSubmitting = true);
    try {
      final res = await _rentPlanService.sendRentalLaptop(
        rentalId: rentalId,
        barcode: _kirimBarcodeCtrl.text.trim(),
        photos: _kirimPhotos,
        video: _kirimVideo,
        notes: _kirimNotesCtrl.text.trim(),
      );

      if (res['status'] == true) {
        if (mounted) {
          context.showSuccessSnackBar(res['message'] ?? 'Serah terima laptop berhasil disimpan!');
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) context.showErrorSnackBar(res['message'] ?? 'Gagal menyimpan serah terima laptop.');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _kirimSubmitting = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2 (TERIMA) LOGIC
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _scanTerimaBarcode() async {
    _terimaBarcodeFocus.unfocus();
    final String? scannedValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scannedValue != null && scannedValue.isNotEmpty) {
      _terimaBarcodeCtrl.text = scannedValue;
      _searchTerimaLaptop(scannedValue);
    }
  }

  Future<void> _searchTerimaLaptop(String barcode) async {
    if (barcode.trim().isEmpty) return;
    setState(() {
      _terimaSearching = true;
      _terimaLaptopData = null;
      _terimaActiveRental = null;
    });

    try {
      final res = await _rentPlanService.getActiveRentalByBarcode(barcode.trim());
      if (res['status'] == true && res['data'] != null) {
        setState(() {
          _terimaLaptopData = res['data'];
          _terimaActiveRental = res['data']['active_rental'];
          if (_terimaLaptopData?['kondisi'] != null) {
            _terimaKondisi = _terimaLaptopData!['kondisi'];
          }
        });
      } else {
        if (mounted) context.showErrorSnackBar(res['message'] ?? 'Laptop atau rental tidak ditemukan.');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal mencari laptop: $e');
    } finally {
      if (mounted) setState(() => _terimaSearching = false);
    }
  }

  Future<void> _pickTerimaPhoto(ImageSource source) async {
    if (_terimaPhotos.length >= _maxPhotos) {
      context.showErrorSnackBar('Maksimal $_maxPhotos foto.');
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null) {
        setState(() => _terimaPhotos.add(image));
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal mengambil foto: $e');
    }
  }

  Future<void> _pickTerimaVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (video != null) {
        setState(() => _terimaVideo = video);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal merekam video: $e');
    }
  }

  Future<void> _processTerimaSubmit() async {
    if (_terimaLaptopData == null || _terimaActiveRental == null) {
      context.showErrorSnackBar('Harap cari dan pilih laptop/rental yang akan diterima.');
      return;
    }
    if (_terimaPhotos.isEmpty) {
      context.showWarningSnackBar('Wajib mengambil minimal 1 Foto bukti penerimaan unit laptop.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barcode = _terimaLaptopData!['barcode'] ?? _terimaBarcodeCtrl.text.trim();
    final laptopName = _terimaLaptopData!['nama_laptop'] ?? 'Unit Laptop';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.archive_rounded, color: _purplePrimary, size: 28),
            const SizedBox(width: 10),
            Text('Konfirmasi Terima Laptop', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfirmasi pengembalian unit sewa:', style: GoogleFonts.outfit(fontSize: 13)),
            const SizedBox(height: 10),
            Text('• Unit: $laptopName ($barcode)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text('• Kondisi: $_terimaKondisi', style: GoogleFonts.outfit(color: _purplePrimary, fontWeight: FontWeight.bold)),
            Text('• Kelengkapan: ${_kelengkapanCharger ? "Charger ADA" : "Charger TIDAK ADA"}, ${_kelengkapanTas ? "Tas ADA" : "Tas TIDAK ADA"}', style: GoogleFonts.outfit(fontSize: 12)),
            Text('• Foto: ${_terimaPhotos.length} foto bukti terlampir', style: GoogleFonts.outfit(color: _purplePrimary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purplePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Terima Unit', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _terimaSubmitting = true);
    try {
      final combinedNotes = [
        if (_terimaNotesCtrl.text.isNotEmpty) _terimaNotesCtrl.text.trim(),
        'Kelengkapan: Charger ${_kelengkapanCharger ? "Lengkap" : "Tidak Ada"}, Tas ${_kelengkapanTas ? "Lengkap" : "Tidak Ada"}',
      ].join(' | ');

      final res = await _rentPlanService.receiveRentalLaptop(
        barcode: barcode,
        kondisi: _terimaKondisi,
        photos: _terimaPhotos,
        video: _terimaVideo,
        notes: combinedNotes,
      );

      if (res['status'] == true) {
        if (mounted) {
          context.showSuccessSnackBar(res['message'] ?? 'Pengembalian laptop berhasil diproses!');
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) context.showErrorSnackBar(res['message'] ?? 'Gagal memproses penerimaan laptop.');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _terimaSubmitting = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER UTILS
  // ══════════════════════════════════════════════════════════════════════════════

  String _getRenterName(Map<String, dynamic> r) {
    if (r['first_name'] != null && r['first_name'].toString().isNotEmpty) {
      return '${r['first_name']} ${r['last_name'] ?? ''}'.trim();
    }
    if (r['nama_pribadi'] != null && r['nama_pribadi'].toString().isNotEmpty) {
      return r['nama_pribadi'].toString();
    }
    if (r['nama_perusahaan'] != null && r['nama_perusahaan'].toString().isNotEmpty) {
      return r['nama_perusahaan'].toString();
    }
    if (r['renter_name'] != null && r['renter_name'].toString().isNotEmpty) {
      return r['renter_name'].toString();
    }
    return 'Penyewa #${r['rental_id'] ?? '-'}';
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD METHOD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        userData: widget.userData ?? {},
        showBackButton: false,
        title: 'Serah Terima Laptop',
      ),
      endDrawer: widget.userData != null && widget.userData!.isNotEmpty
          ? SideDrawer(userData: widget.userData!, activePage: 'serah_terima_laptop')
          : null,
      body: Column(
        children: [
          // ── Clean Segmented Switcher (Tanpa emoji, tanpa kurung, tema ungu) ──
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2026) : Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [_purplePrimary, _purpleDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purplePrimary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Kirim Laptop'),
                Tab(text: 'Terima Laptop'),
              ],
            ),
          ),

          // ── Tab Views ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKirimTabView(isDark),
                _buildTerimaTabView(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1: KIRIM LAPTOP VIEW
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildKirimTabView(bool isDark) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner Instruksi Foto Penyewa
            _buildKirimInstructionCard(isDark),
            const SizedBox(height: 24),

            // 2. Pilih Penyewa / Order Rental
            if (_kirimSelectedRental == null) ...[
              _buildSectionHeader('Pilih Penyewa / Order Rental', Icons.person_search_rounded),
              const SizedBox(height: 10),
              _buildKirimSearchField(isDark),
              const SizedBox(height: 12),
              if (_kirimSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: _purplePrimary),
                  ),
                )
              else
                _buildKirimSearchResults(isDark),
              const SizedBox(height: 24),
            ] else ...[
              _buildSectionHeader('Data Penyewa Terpilih', Icons.person_rounded),
              const SizedBox(height: 10),
              _buildKirimSelectedRentalCard(isDark),
              const SizedBox(height: 24),
            ],

            // 3. Foto Penyewa (Wajib)
            _buildSectionHeader(
              'Foto Penyewa (${_kirimPhotos.length}/$_maxPhotos) *',
              Icons.camera_alt_rounded,
            ),
            const SizedBox(height: 4),
            Text(
              'Ambil foto penyewa memegang laptop saat serah terima.',
              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 14),
            _buildMediaGrid(
              photos: _kirimPhotos,
              onAdd: () => _showPhotoSourceSheet(isKirim: true),
              onRemove: (idx) => setState(() => _kirimPhotos.removeAt(idx)),
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // 4. Video (Opsional)
            _buildSectionHeader('Video Serah Terima (Opsional)', Icons.videocam_rounded),
            const SizedBox(height: 4),
            Text(
              'Rekam video fisik unit / proses serah terima (maks. 3 menit).',
              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildVideoPreview(
              video: _kirimVideo,
              onAdd: () => _showVideoSourceSheet(isKirim: true),
              onRemove: () => setState(() => _kirimVideo = null),
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // 5. Barcode Laptop (Opsional)
            _buildSectionHeader('Barcode Laptop (Opsional)', Icons.qr_code_rounded),
            const SizedBox(height: 4),
            Text(
              'Barcode nomor unit fisik laptop jika ingin dicatat.',
              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kirimBarcodeCtrl,
                      style: GoogleFonts.outfit(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Barcode laptop (opsional)...',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
                        prefixIcon: const Icon(Icons.qr_code_2_rounded, color: _purplePrimary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: _purplePrimary),
                    onPressed: () async {
                      final val = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
                      );
                      if (val != null && val.isNotEmpty) {
                        setState(() => _kirimBarcodeCtrl.text = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Catatan Pengiriman
            _buildSectionHeader('Catatan Serah Terima (Opsional)', Icons.notes_rounded),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
              ),
              child: TextField(
                controller: _kirimNotesCtrl,
                maxLines: 2,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Contoh: Diterima langsung oleh penyewa...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 7. Tombol Submit Kirim
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _kirimSubmitting ? null : _processKirimSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purplePrimary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _kirimSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Konfirmasi Serah Terima Laptop',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2: TERIMA LAPTOP VIEW
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildTerimaTabView(bool isDark) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner Instruksi Terima Laptop
            _buildTerimaInstructionCard(isDark),
            const SizedBox(height: 24),

            // 2. Scan / Input Barcode Unit
            _buildSectionHeader('Scan Barcode Unit Laptop *', Icons.qr_code_scanner_rounded),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2026) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _terimaBarcodeCtrl,
                      focusNode: _terimaBarcodeFocus,
                      style: GoogleFonts.outfit(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Scan / Masukkan barcode laptop...',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
                        prefixIcon: const Icon(Icons.laptop_chromebook_rounded, color: _purplePrimary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onSubmitted: _searchTerimaLaptop,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: _purplePrimary),
                    onPressed: _scanTerimaBarcode,
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: _purpleDark),
                    onPressed: () => _searchTerimaLaptop(_terimaBarcodeCtrl.text),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_terimaSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: _purplePrimary),
                ),
              )
            else if (_terimaLaptopData != null) ...[
              // Data Laptop & Rental Ditemukan
              _buildSectionHeader('Informasi Unit & Penyewa', Icons.info_outline_rounded),
              const SizedBox(height: 10),
              _buildTerimaLaptopInfoCard(isDark),
              const SizedBox(height: 24),

              // Checklist Kondisi & Kelengkapan
              _buildSectionHeader('Kondisi Fisik Saat Diterima', Icons.build_circle_outlined),
              const SizedBox(height: 10),
              _buildKondisiSelector(isDark),
              const SizedBox(height: 20),

              _buildSectionHeader('Pengecekan Kelengkapan', Icons.checklist_rounded),
              const SizedBox(height: 10),
              _buildKelengkapanCheckboxes(isDark),
              const SizedBox(height: 24),

              // Foto Bukti Pengembalian
              _buildSectionHeader(
                'Foto Unit Saat Diterima (${_terimaPhotos.length}/$_maxPhotos) *',
                Icons.camera_alt_rounded,
              ),
              const SizedBox(height: 4),
              Text(
                'Foto kondisi fisik laptop & kelengkapannya saat dikembalikan penyewa.',
                style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 14),
              _buildMediaGrid(
                photos: _terimaPhotos,
                onAdd: () => _showPhotoSourceSheet(isKirim: false),
                onRemove: (idx) => setState(() => _terimaPhotos.removeAt(idx)),
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Video Pengembalian (Opsional)
              _buildSectionHeader('Video Unit (Opsional)', Icons.videocam_rounded),
              const SizedBox(height: 4),
              Text(
                'Video kelayakan unit dan pengujian fungsi.',
                style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildVideoPreview(
                video: _terimaVideo,
                onAdd: () => _showVideoSourceSheet(isKirim: false),
                onRemove: () => setState(() => _terimaVideo = null),
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Catatan Pengembalian
              _buildSectionHeader('Catatan Tambahan', Icons.notes_rounded),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2026) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _terimaNotesCtrl,
                  maxLines: 2,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Catatan lecet fisik, kelalaian, atau kelengkapan...',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Submit Terima
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _terimaSubmitting ? null : _processTerimaSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purplePrimary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _terimaSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.archive_rounded, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Konfirmasi Terima Laptop',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // WIDGET HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildKirimInstructionCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF311B92).withValues(alpha: 0.6), const Color(0xFF4527A0).withValues(alpha: 0.6)]
              : [const Color(0xFFF3E5F5), const Color(0xFFEDE7F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purplePrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purplePrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Instruksi Foto Penyewa (Wajib)',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF4A148C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1', 'Ambil foto penyewa memegang unit laptop saat serah terima dilakukan.', isDark),
          const SizedBox(height: 6),
          _buildInstructionItem('2', 'Pastikan wajah penyewa dan kondisi unit laptop tampak jelas.', isDark),
          const SizedBox(height: 6),
          _buildInstructionItem('3', 'Foto ini disimpan sebagai bukti sah pengiriman untuk mengaktifkan status sewa.', isDark),
        ],
      ),
    );
  }

  Widget _buildTerimaInstructionCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF311B92).withValues(alpha: 0.6), const Color(0xFF4527A0).withValues(alpha: 0.6)]
              : [const Color(0xFFF3E5F5), const Color(0xFFEDE7F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purplePrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purplePrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist_rtl_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Instruksi Pengembalian Laptop',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF4A148C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1', 'Scan barcode unit laptop yang dikembalikan untuk mencocokkan nomor unit.', isDark),
          const SizedBox(height: 6),
          _buildInstructionItem('2', 'Periksa kondisi fisik unit, layar, keyboard, dan kelengkapan (charger/tas).', isDark),
          const SizedBox(height: 6),
          _buildInstructionItem('3', 'Ambil foto bukti kondisi unit saat diterima kembali.', isDark),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _purplePrimary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: _purplePrimary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _purplePrimary),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildKirimSearchField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
      ),
      child: TextField(
        controller: _kirimSearchCtrl,
        style: GoogleFonts.outfit(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari nama penyewa / invoice rental...',
          hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _purplePrimary, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: _purplePrimary),
            onPressed: () => _searchKirimRental(_kirimSearchCtrl.text),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        onSubmitted: _searchKirimRental,
      ),
    );
  }

  Widget _buildKirimSearchResults(bool isDark) {
    if (_kirimSearchResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'Tidak ada order rental ditemukan.',
          style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kirimSearchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final r = _kirimSearchResults[idx];
        final name = _getRenterName(r);
        final inv = r['invoice_number'] ?? '-';
        final status = r['status'] ?? '-';

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _kirimSelectedRental = r;
              if (r['barcode'] != null) _kirimBarcodeCtrl.text = r['barcode'].toString();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2026) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _purplePrimary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded, color: _purplePrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Inv: $inv • Status: $status', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKirimSelectedRentalCard(bool isDark) {
    final r = _kirimSelectedRental!;
    final name = _getRenterName(r);
    final inv = r['invoice_number'] ?? '-';
    final phone = r['contact_number'] ?? r['phone'] ?? '-';
    final alamat = r['alamat'] ?? r['address'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purplePrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.change_circle_rounded, size: 16, color: _purplePrimary),
                label: Text('Ganti', style: GoogleFonts.outfit(fontSize: 12, color: _purplePrimary)),
                onPressed: () => setState(() => _kirimSelectedRental = null),
              ),
            ],
          ),
          const Divider(height: 12),
          Text('• Invoice: $inv', style: GoogleFonts.outfit(fontSize: 13)),
          const SizedBox(height: 4),
          Text('• Telepon: $phone', style: GoogleFonts.outfit(fontSize: 13)),
          const SizedBox(height: 4),
          Text('• Alamat: $alamat', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildTerimaLaptopInfoCard(bool isDark) {
    final laptop = _terimaLaptopData!;
    final rental = _terimaActiveRental;
    final laptopName = laptop['nama_laptop'] ?? 'Unit Laptop';
    final barcode = laptop['barcode'] ?? '-';
    final renterName = rental != null ? _getRenterName(rental) : 'Tidak ada sewa aktif';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purplePrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.laptop_chromebook_rounded, color: _purplePrimary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  laptopName,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Text('• Barcode: $barcode', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('• Penyewa Terakhir: $renterName', style: GoogleFonts.outfit(fontSize: 13)),
          if (rental != null && rental['invoice_number'] != null) ...[
            const SizedBox(height: 4),
            Text('• Invoice: ${rental['invoice_number']}', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  Widget _buildKondisiSelector(bool isDark) {
    final conditions = ['Bagus', 'Rusak Ringan', 'Rusak Berat'];
    return Row(
      children: conditions.map((c) {
        final isSelected = _terimaKondisi == c;
        Color color = _purplePrimary;
        if (c == 'Rusak Ringan') color = Colors.orange;
        if (c == 'Rusak Berat') color = Colors.red;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(c, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              selected: isSelected,
              selectedColor: color.withValues(alpha: 0.2),
              side: BorderSide(color: isSelected ? color : Colors.grey[300]!),
              onSelected: (val) {
                if (val) setState(() => _terimaKondisi = c);
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKelengkapanCheckboxes(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: _purplePrimary,
              title: Text('Charger / Adaptor', style: GoogleFonts.outfit(fontSize: 13)),
              value: _kelengkapanCharger,
              onChanged: (val) => setState(() => _kelengkapanCharger = val ?? true),
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: _purplePrimary,
              title: Text('Tas Laptop', style: GoogleFonts.outfit(fontSize: 13)),
              value: _kelengkapanTas,
              onChanged: (val) => setState(() => _kelengkapanTas = val ?? true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid({
    required List<XFile> photos,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required bool isDark,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: (photos.length < _maxPhotos) ? photos.length + 1 : photos.length,
      itemBuilder: (ctx, idx) {
        if (idx == photos.length) {
          return InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _purplePrimary.withValues(alpha: 0.4), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded, color: _purplePrimary, size: 28),
                  const SizedBox(height: 6),
                  Text('Tambah Foto', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: _purplePrimary)),
                ],
              ),
            ),
          );
        }

        final file = photos[idx];
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(file.path), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () => onRemove(idx),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPreview({
    required XFile? video,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
    required bool isDark,
  }) {
    if (video == null) {
      return InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_rounded, color: _purplePrimary, size: 24),
              const SizedBox(width: 8),
              Text('Rekam / Unggah Video', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purplePrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.video_file_rounded, color: _purplePrimary, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Video Terlampir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(video.name, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  void _showPhotoSourceSheet({required bool isKirim}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2026) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(isKirim ? 'Ambil Foto Penyewa' : 'Ambil Foto Unit Laptop', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Kamera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purplePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (isKirim) {
                        _pickKirimPhoto(ImageSource.camera);
                      } else {
                        _pickTerimaPhoto(ImageSource.camera);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galeri'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purplePrimary,
                      side: const BorderSide(color: _purplePrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (isKirim) {
                        _pickKirimPhoto(ImageSource.gallery);
                      } else {
                        _pickTerimaPhoto(ImageSource.gallery);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoSourceSheet({required bool isKirim}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2026) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Rekam / Pilih Video', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Kamera Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purplePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (isKirim) {
                        _pickKirimVideo(ImageSource.camera);
                      } else {
                        _pickTerimaVideo(ImageSource.camera);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.video_library_rounded),
                    label: const Text('Galeri Video'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purplePrimary,
                      side: const BorderSide(color: _purplePrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (isKirim) {
                        _pickKirimVideo(ImageSource.gallery);
                      } else {
                        _pickTerimaVideo(ImageSource.gallery);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
