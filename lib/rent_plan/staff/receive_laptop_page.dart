import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/rent_plan_service.dart';
import '../../../widgets/secondary_app_bar.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/side_drawer.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/barcode_scanner_page.dart';
import '../../../localization/app_localizations.dart';

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

  bool _isLoading = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _laptopData;
  Map<String, dynamic>? _activeRental;
  String _returnCondition = 'Bagus'; // Default return condition

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

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

  Future<void> _processReceive() async {
    if (_laptopData == null) return;
    final barcode = _barcodeController.text.trim();
    final rentalId = _activeRental?['rental_id'];

    // Show Dialog Confirmation
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await _rentPlanService.receiveRentalLaptop(
        barcode: barcode,
        rentalId: rentalId,
        kondisi: _returnCondition,
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
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetPage() {
    setState(() {
      _barcodeController.clear();
      _laptopData = null;
      _activeRental = null;
      _returnCondition = 'Bagus';
    });
  }

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
                // Laptop info Card
                _buildSectionHeader('Detail Laptop', Icons.laptop_rounded),
                const SizedBox(height: 8),
                _buildLaptopInfoCard(isDark),
                const SizedBox(height: 24),

                // Renter/Rental Info Card
                if (_activeRental != null) ...[
                  _buildSectionHeader('Detail Penyewa Aktif', Icons.person_rounded),
                  const SizedBox(height: 8),
                  _buildRenterInfoCard(isDark),
                  const SizedBox(height: 24),

                  // Return condition ChoiceChips
                  _buildSectionHeader('Kondisi Laptop Saat Kembali', Icons.rule_rounded),
                  const SizedBox(height: 12),
                  _buildConditionSelector(isDark),
                  const SizedBox(height: 32),

                  // Receive Button
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
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Terima Laptop',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  // If not currently rented
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
