import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/rent_plan_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/side_drawer.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/barcode_scanner_page.dart';

class SendLaptopPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? initialBarcode;
  final Map<String, dynamic>? initialRental;

  const SendLaptopPage({
    super.key,
    required this.userData,
    this.initialBarcode,
    this.initialRental,
  });

  @override
  State<SendLaptopPage> createState() => _SendLaptopPageState();
}

class _SendLaptopPageState extends State<SendLaptopPage> {
  final RentPlanService _rentPlanService = RentPlanService();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _laptopData;
  Map<String, dynamic>? _activeRental;

  // ── Media State ──────────────────────────────────────────────────────────────
  List<XFile> _capturedPhotos = [];
  XFile? _capturedVideo;
  static const int _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    if (widget.initialRental != null) {
      _activeRental = widget.initialRental;
      if (widget.initialRental!['barcode'] != null &&
          widget.initialRental!['barcode'].toString().isNotEmpty) {
        _barcodeController.text = widget.initialRental!['barcode'].toString();
        _searchLaptop(widget.initialRental!['barcode'].toString());
      }
    } else if (widget.initialBarcode != null &&
        widget.initialBarcode!.isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!;
      _searchLaptop(widget.initialBarcode!);
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _notesController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  // ── Barcode Scan & Search ──────────────────────────────────────────────────
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
      if (widget.initialRental == null) {
        _activeRental = null;
      }
    });

    try {
      final res = await _rentPlanService.getActiveRentalByBarcode(barcode.trim());
      if (res['status'] == true && res['data'] != null) {
        setState(() {
          _laptopData = res['data'];
          if (res['data']['active_rental'] != null) {
            _activeRental = res['data']['active_rental'];
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
              'Ambil Foto Penyewa',
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
                    color: const Color(0xFF2575FC),
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
                    color: const Color(0xFF6A11CB),
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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final remaining = _maxPhotos - _capturedPhotos.length;
        final pickedFiles = await _imagePicker.pickMultiImage(
          imageQuality: 80,
          limit: remaining,
        );
        if (pickedFiles.isNotEmpty) {
          setState(() {
            _capturedPhotos.addAll(pickedFiles.take(remaining));
          });
        }
      } else {
        final pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (pickedFile != null) {
          setState(() {
            _capturedPhotos.add(pickedFile);
          });
        }
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal mengambil foto: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _capturedPhotos.removeAt(index);
    });
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
              'Rekam Video Serah Terima',
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
                    label: 'Kamera Video',
                    color: const Color(0xFFE91E63),
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
                    label: 'Galeri Video',
                    color: const Color(0xFF9C27B0),
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

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final pickedVideo = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (pickedVideo != null) {
        setState(() {
          _capturedVideo = pickedVideo;
        });
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Gagal merekam video: $e');
    }
  }

  void _removeVideo() {
    setState(() {
      _capturedVideo = null;
    });
  }

  void _viewPhoto(XFile file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(file.path),
                fit: BoxFit.contain,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Submit Kirim Laptop ───────────────────────────────────────────────────

  Future<void> _processSend() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty && _activeRental == null) {
      context.showErrorSnackBar('Harap masukkan atau scan barcode unit laptop.');
      return;
    }

    if (_activeRental == null) {
      context.showErrorSnackBar('Data rental belum ditemukan untuk pengiriman ini.');
      return;
    }

    if (_capturedPhotos.isEmpty) {
      context.showWarningSnackBar('Harap ambil minimal 1 foto penyewa saat serah terima.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.local_shipping_rounded, color: Color(0xFF2575FC), size: 28),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Kirim Laptop',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastikan laptop telah diserahkan langsung ke penyewa:',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Penyewa: ${_activeRental!['renter_name'] ?? '-'}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invoice: ${_activeRental!['invoice_number'] ?? '-'}',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Barcode: ${barcode.isNotEmpty ? barcode : (_activeRental!['barcode'] ?? '-')}',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Foto Terlampir: ${_capturedPhotos.length} foto',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2575FC),
                    ),
                  ),
                  if (_capturedVideo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Video Terlampir: 1 video',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE91E63),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.outfit(color: Colors.grey[500])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2575FC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ya, Konfirmasi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final photoFiles = _capturedPhotos.map((x) => File(x.path)).toList();
      final videoFile = _capturedVideo != null ? File(_capturedVideo!.path) : null;

      final res = await _rentPlanService.sendRentalLaptop(
        barcode: barcode.isNotEmpty ? barcode : (_activeRental!['barcode'] ?? ''),
        rentalId: _activeRental!['rental_id'],
        catatan: _notesController.text.trim(),
        photos: photoFiles,
        video: videoFile,
      );

      if (res['status'] == true) {
        if (mounted) {
          context.showSuccessSnackBar(
            res['message'] ?? 'Laptop berhasil diserahkan ke penyewa!',
          );
          _resetForm();
        }
      } else {
        if (mounted) {
          context.showErrorSnackBar(res['message'] ?? 'Gagal memproses pengiriman laptop.');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Terjadi kesalahan saat kirim laptop: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _barcodeController.clear();
      _notesController.clear();
      _laptopData = null;
      _activeRental = null;
      _capturedPhotos.clear();
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
        showBackButton: Navigator.canPop(context),
        title: 'Kirim Laptop',
      ),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'send_laptop'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search & Scan Field ──
              Text(
                'Scan Barcode Laptop Siap Kirim',
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
                          hintText: 'Ketik atau scan barcode laptop...',
                          hintStyle: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 14),
                          prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF2575FC)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        ),
                        onSubmitted: (value) => _searchLaptop(value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2575FC), size: 28),
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
                    child: CircularProgressIndicator(color: Color(0xFF2575FC)),
                  ),
                ),

              // ── Laptop Details ──
              if (!_isLoading && _laptopData != null) ...[
                _buildSectionHeader('Detail Laptop', Icons.laptop_rounded),
                const SizedBox(height: 8),
                _buildLaptopInfoCard(isDark),
                const SizedBox(height: 24),
              ],

              // ── Rental Details ──
              if (!_isLoading && _activeRental != null) ...[
                _buildSectionHeader('Detail Penyewa & Tujuan Kirim', Icons.person_pin_circle_rounded),
                const SizedBox(height: 8),
                _buildRenterInfoCard(isDark),
                const SizedBox(height: 24),

                // ── Catatan Pengiriman ──
                _buildSectionHeader('Catatan Serah Terima (Opsional)', Icons.edit_note_rounded),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: GoogleFonts.outfit(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Diterima langsung oleh penyewa, unit dan charger lengkap...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── FOTO PENYEWA ──────────────────────────────────────────
                _buildSectionHeader(
                  'Foto Penyewa (${_capturedPhotos.length}/$_maxPhotos) *',
                  Icons.camera_alt_rounded,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ambil foto penyewa saat serah terima laptop sebagai bukti pengiriman resmi.',
                  style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 12),
                _buildPhotoGrid(isDark),
                const SizedBox(height: 24),

                // ── VIDEO (OPSIONAL) ──────────────────────────────────────
                _buildSectionHeader('Video Serah Terima (Opsional)', Icons.videocam_rounded),
                const SizedBox(height: 4),
                Text(
                  'Rekam video singkat serah terima / fisik laptop saat diserahkan (maks. 3 menit).',
                  style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 12),
                _buildVideoSection(isDark),
                const SizedBox(height: 32),

                // ── Submit Button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _processSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2575FC),
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
                              const Icon(Icons.local_shipping_rounded, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Konfirmasi Kirim Laptop',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2575FC)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLaptopInfoCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow('Barcode', _laptopData!['barcode'] ?? '-', isBold: true),
          const Divider(height: 16),
          _buildInfoRow('Model Laptop', _laptopData!['nama_laptop'] ?? _laptopData!['kode_laptop'] ?? '-'),
          const Divider(height: 16),
          _buildInfoRow('Serial Number', _laptopData!['serial_number'] ?? '-'),
          const Divider(height: 16),
          _buildInfoRow('Kondisi Fisik', _laptopData!['kondisi'] ?? 'Bagus'),
          const Divider(height: 16),
          _buildInfoRow('Status Saat Ini', _laptopData!['status'] ?? '-', isStatus: true),
        ],
      ),
    );
  }

  Widget _buildRenterInfoCard(bool isDark) {
    final status = _activeRental!['rental_status']?.toString() ?? '-';
    final whatsapp = _activeRental!['whatsapp']?.toString() ?? _activeRental!['contact_number']?.toString() ?? '-';
    final lokasi = _activeRental!['lokasi']?.toString() ?? '-';
    final tipeKirim = _activeRental!['tipe_pengiriman']?.toString() ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow('Nama Penyewa', _activeRental!['renter_name'] ?? '-', isBold: true),
          const Divider(height: 16),
          _buildInfoRow('No. Invoice', _activeRental!['invoice_number'] ?? '-'),
          const Divider(height: 16),
          _buildInfoRow('Status Order', status.toUpperCase(), isStatus: true),
          const Divider(height: 16),
          _buildInfoRow('Tipe Pengiriman', tipeKirim),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('WhatsApp / Telp', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
              Row(
                children: [
                  Text(whatsapp, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (whatsapp != '-' && whatsapp.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        final cleanNumber = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
                        final waUrl = 'https://wa.me/$cleanNumber';
                        launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.green),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (lokasi != '-' && lokasi.isNotEmpty) ...[
            const Divider(height: 16),
            _buildInfoRow('Alamat Kirim', lokasi),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isStatus = false}) {
    Color? textColor;
    if (isStatus) {
      final v = value.toLowerCase();
      if (v == 'disewa' || v == 'confirmed' || v == 'aktif') {
        textColor = Colors.blue;
      } else if (v == 'tersedia' || v == 'ready') {
        textColor = Colors.green;
      } else if (v == 'pending' || v == 'new') {
        textColor = Colors.orange;
      } else {
        textColor = Colors.purple;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : (isStatus ? FontWeight.bold : FontWeight.normal),
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  // ── Media UI ─────────────────────────────────────────────────────────────────

  Widget _buildPhotoGrid(bool isDark) {
    return Column(
      children: [
        if (_capturedPhotos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _capturedPhotos.length,
            itemBuilder: (context, index) {
              final file = _capturedPhotos[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => _viewPhoto(file),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(file.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        if (_capturedPhotos.length < _maxPhotos) ...[
          if (_capturedPhotos.isNotEmpty) const SizedBox(height: 10),
          GestureDetector(
            onTap: _showPhotoSourceSheet,
            child: Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                color: isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF2575FC).withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded, color: Color(0xFF2575FC), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _capturedPhotos.isEmpty ? 'Ambil Foto Penyewa' : 'Tambah Foto (${_capturedPhotos.length}/$_maxPhotos)',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF2575FC),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoSection(bool isDark) {
    if (_capturedVideo == null) {
      return GestureDetector(
        onTap: _showVideoSourceSheet,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey[400]!.withValues(alpha: 0.5),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_outlined, color: Colors.grey, size: 22),
              const SizedBox(width: 8),
              Text(
                'Rekam Video Serah Terima (Opsional)',
                style: GoogleFonts.outfit(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filename = _capturedVideo!.name;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2575FC).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2575FC).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.videocam_rounded, color: Color(0xFF2575FC), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'Video serah terima siap diupload',
                  style: GoogleFonts.outfit(color: Colors.green, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            onPressed: _removeVideo,
          ),
        ],
      ),
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
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
