import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/rent_plan_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/side_drawer.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/barcode_scanner_page.dart';

class ReceiveLaptopPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ReceiveLaptopPage({super.key, required this.userData});

  @override
  State<ReceiveLaptopPage> createState() => _ReceiveLaptopPageState();
}

class _ReceiveLaptopPageState extends State<ReceiveLaptopPage> {
  final RentPlanService _rentPlanService = RentPlanService();
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _laptopData;
  Map<String, dynamic>? _activeRental;
  String _returnCondition = 'Bagus';

  // ── Media State ──────────────────────────────────────────────────────────────
  List<XFile> _capturedPhotos = [];
  XFile? _capturedVideo;
  static const int _maxPhotos = 5;

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  // ── Barcode Scan ──────────────────────────────────────────────────────────────
  Future<void> _scanBarcode() async {
    _barcodeFocus.unfocus();
    final String? scannedValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerPage(),
      ),
    );

    if (scannedValue != null && scannedValue.isNotEmpty) {
      _barcodeController.text = scannedValue;
      _searchLaptop(scannedValue);
    }
  }

  Future<void> _searchLaptop(String barcode) async {
    if (barcode.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _laptopData = null;
      _activeRental = null;
    });

    try {
      final res = await _rentPlanService.getActiveRentalByBarcode(barcode.trim());
      if (res['status'] == true && res['data'] != null) {
        setState(() {
          _laptopData = res['data'];
          _activeRental = res['data']['active_rental'];
          if (_laptopData != null && _laptopData!['kondisi'] != null) {
            _returnCondition = _laptopData!['kondisi'];
          }
        });
      } else {
        if (mounted) {
          context.showErrorSnackBar(res['message'] ?? 'Data laptop tidak ditemukan.');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Terjadi kesalahan: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── Media Capture ────────────────────────────────────────────────────────────

  void _showPhotoSourceSheet() {
    if (_capturedPhotos.length >= _maxPhotos) {
      context.showErrorSnackBar('Maksimal $_maxPhotos foto. Hapus foto lama dulu.');
      return;
    }

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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pilih Sumber Foto',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMediaSourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: const Color(0xFF7E57C2),
                    onTap: () {
                      Navigator.pop(context);
                      _pickPhoto(ImageSource.camera);
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMediaSourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      _pickPhoto(ImageSource.gallery);
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoSourceSheet() {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pilih Sumber Video',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMediaSourceButton(
                    icon: Icons.videocam_rounded,
                    label: 'Rekam Video',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _pickVideo(ImageSource.camera);
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMediaSourceButton(
                    icon: Icons.video_library_rounded,
                    label: 'Galeri',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _pickVideo(ImageSource.gallery);
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (photo != null && mounted) {
        setState(() {
          _capturedPhotos.add(photo);
        });
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal mengambil foto: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (video != null && mounted) {
        setState(() {
          _capturedVideo = video;
        });
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal mengambil video: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _capturedPhotos.removeAt(index);
    });
  }

  void _removeVideo() {
    setState(() {
      _capturedVideo = null;
    });
  }

  // ── Process Receive ──────────────────────────────────────────────────────────

  Future<void> _processReceive() async {
    if (_laptopData == null) return;
    final barcode = _barcodeController.text.trim();
    final rentalId = _activeRental?['rental_id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFE57373), size: 28),
            const SizedBox(width: 12),
            Text(
              'Konfirmasi Penerimaan',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin laptop dengan barcode "$barcode" telah diterima kembali?\n\nStatus laptop akan menjadi READY (Tersedia) dan status sewa client akan selesai.',
          style: GoogleFonts.outfit(color: Colors.grey[300], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.outfit(color: Colors.grey[400], fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Ya, Terima',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() { _isSubmitting = true; });

    try {
      final List<File> photoFiles = _capturedPhotos.map((x) => File(x.path)).toList();
      final File? videoFile = _capturedVideo != null ? File(_capturedVideo!.path) : null;

      final res = await _rentPlanService.receiveRentalLaptop(
        barcode: barcode,
        rentalId: rentalId,
        kondisi: _returnCondition,
        photos: photoFiles.isNotEmpty ? photoFiles : null,
        video: videoFile,
      );

      if (res['status'] == true) {
        if (mounted) {
          context.showSuccessSnackBar(res['message'] ?? 'Laptop berhasil diterima kembali.');
          _resetPage();
        }
      } else {
        if (mounted) {
          context.showErrorSnackBar(res['message'] ?? 'Gagal memproses pengembalian laptop.');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Gagal memproses pengembalian: $e');
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  void _resetPage() {
    setState(() {
      _barcodeController.clear();
      _laptopData = null;
      _activeRental = null;
      _returnCondition = 'Bagus';
      _capturedPhotos = [];
      _capturedVideo = null;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        title: 'My ISN',
      ),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'receive_laptop'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search & Scan Field ──
              Text(
                'Scan Barcode Unit Laptop',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white54.withValues(alpha: 0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        focusNode: _barcodeFocus,
                        keyboardType: TextInputType.text,
                        style: GoogleFonts.outfit(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Ketik atau scan barcode...',
                          hintStyle: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 14),
                          prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF7E57C2)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        ),
                        onSubmitted: (value) => _searchLaptop(value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF7E57C2), size: 28),
                      onPressed: _scanBarcode,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Loading Indicator ──
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFF7E57C2)),
                  ),
                ),

              // ── Laptop & Rental details ──
              if (!_isLoading && _laptopData != null) ...[
                _buildSectionHeader('Detail Laptop', Icons.laptop_rounded),
                const SizedBox(height: 8),
                _buildLaptopInfoCard(isDark),
                const SizedBox(height: 24),

                if (_activeRental != null) ...[
                  _buildSectionHeader('Detail Penyewa Aktif', Icons.person_rounded),
                  const SizedBox(height: 8),
                  _buildRenterInfoCard(isDark),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Kondisi Laptop Saat Kembali', Icons.rule_rounded),
                  const SizedBox(height: 12),
                  _buildConditionSelector(isDark),
                  const SizedBox(height: 28),

                  // ── FOTO PENYEWA ──────────────────────────────────────────
                  _buildSectionHeader(
                    'Foto Penyewa (${_capturedPhotos.length}/$_maxPhotos)',
                    Icons.camera_alt_rounded,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ambil foto penyewa sebagai dokumentasi penerimaan laptop.',
                    style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoGrid(isDark),
                  const SizedBox(height: 24),

                  // ── VIDEO (OPSIONAL) ──────────────────────────────────────
                  _buildSectionHeader('Video Kondisi Laptop (Opsional)', Icons.videocam_rounded),
                  const SizedBox(height: 4),
                  Text(
                    'Rekam video singkat kondisi laptop saat dikembalikan (maks. 3 menit).',
                    style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _buildVideoSection(isDark),
                  const SizedBox(height: 32),

                  // ── Receive Button ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _processReceive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Terima Laptop',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Laptop Tidak Sedang Disewa',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Unit laptop dengan barcode ini berstatus bebas/tersedia di database. Tidak ada proses sewa aktif yang bisa diselesaikan.',
                                style: GoogleFonts.outfit(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _resetPage,
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7E57C2)),
                    label: Text(
                      'Reset & Scan Lain',
                      style: GoogleFonts.outfit(color: const Color(0xFF7E57C2), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget Helpers ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7E57C2)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // Existing photo thumbnails
        ..._capturedPhotos.asMap().entries.map((entry) {
          final index = entry.key;
          final xfile = entry.value;
          return _buildPhotoThumbnail(index, xfile, isDark);
        }),

        // Add photo button (shown if below max)
        if (_capturedPhotos.length < _maxPhotos)
          GestureDetector(
            onTap: _showPhotoSourceSheet,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF7E57C2).withValues(alpha: 0.12)
                    : const Color(0xFF7E57C2).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7E57C2).withValues(alpha: 0.4),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded, color: Color(0xFF7E57C2), size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Tambah Foto',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7E57C2),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoThumbnail(int index, XFile xfile, bool isDark) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(xfile.path),
            width: 90,
            height: 90,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoSection(bool isDark) {
    if (_capturedVideo != null) {
      final fileName = _capturedVideo!.path.split('/').last;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video Dipilih',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _removeVideo,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Hapus Video',
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showVideoSourceSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.videocam_off_rounded, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Tap untuk merekam / pilih video',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Opsional — maks. 3 menit',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaptopInfoCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _laptopData?['nama_laptop'] ?? '-',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Kode Laptop', _laptopData?['kode_laptop'] ?? '-', isDark),
          const Divider(height: 16),
          _buildInfoRow('Serial Number (SN)', _laptopData?['serial_number'] ?? '-', isDark),
          const Divider(height: 16),
          _buildInfoRow('Kondisi Saat Ini', _laptopData?['kondisi'] ?? '-', isDark, isHighlight: true),
          const Divider(height: 16),
          _buildInfoRow('Status Unit', _laptopData?['status'] ?? '-', isDark,
              customValueColor: _laptopData?['status'] == 'Tersedia' ? Colors.green : Colors.blue),
        ],
      ),
    );
  }

  Widget _buildRenterInfoCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _activeRental?['renter_name'] ?? '-',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _activeRental?['rental_status']?.toString().toUpperCase() ?? '-',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('No. Invoice', _activeRental?['invoice_number'] ?? '-', isDark),
          const Divider(height: 16),
          _buildInfoRow('No. WhatsApp', _activeRental?['contact_number'] ?? '-', isDark),
        ],
      ),
    );
  }

  Widget _buildConditionSelector(bool isDark) {
    final List<String> conditions = ['Bagus', 'Rusak'];

    return Row(
      children: conditions.map((condition) {
        final isSelected = _returnCondition == condition;
        return Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _returnCondition = condition;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF7E57C2).withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7E57C2)
                      : (isDark ? Colors.white10 : Colors.grey[300]!),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    condition == 'Bagus' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 16,
                    color: isSelected
                        ? const Color(0xFF7E57C2)
                        : (condition == 'Bagus' ? Colors.green[400] : Colors.red[400]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    condition,
                    style: GoogleFonts.outfit(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF7E57C2)
                          : (isDark ? Colors.grey[300] : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark,
      {bool isHighlight = false, Color? customValueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.grey[500],
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: customValueColor ??
                (isHighlight
                    ? const Color(0xFF7E57C2)
                    : (isDark ? Colors.grey[300] : Colors.grey[800])),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
