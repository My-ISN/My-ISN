import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/rent_plan_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/barcode_scanner_page.dart';
import '../../widgets/secondary_app_bar.dart';
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
  String? _errorMessage;
  Map<String, dynamic>? _unitData;

  // ── Checklist State ──
  List<dynamic> _templates = [];
  int? _selectedTemplateId;
  String _selectedTemplateName = '';
  List<dynamic> _checklistIndicators = [];
  final Map<int, String> _indicatorResults = {}; // indicatorId => 'OK' or 'NOK'
  final Map<int, TextEditingController> _indicatorNoteControllers = {};
  final TextEditingController _overallNotesController = TextEditingController();
  String _overallStatus = 'Pass'; // Pass, Fail, Needs Repair
  bool _isLoadingChecklist = false;
  bool _isSavingInspection = false;

  // ── Inspection History State ──
  List<dynamic> _inspectionHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null && widget.initialBarcode!.trim().isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLaptopDetail(widget.initialBarcode!.trim());
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openScanner();
      });
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _overallNotesController.dispose();
    for (var ctrl in _indicatorNoteControllers.values) {
      ctrl.dispose();
    }
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
        // Fetch Checklist Templates & Inspection History
        await _loadChecklistTemplates();
        await _loadInspectionHistory(query);
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

  Future<void> _loadChecklistTemplates() async {
    setState(() => _isLoadingChecklist = true);
    try {
      final res = await _service.getChecklistTemplates();
      if (!mounted) return;

      if (res['status'] == true && res['data'] != null) {
        final list = List<dynamic>.from(res['data']);
        setState(() {
          _templates = list;
          if (list.isNotEmpty && _selectedTemplateId == null) {
            // Auto-select default or first template
            final defaultTpl = list.firstWhere(
              (t) => t['is_default'] == 1 || t['is_default'] == '1',
              orElse: () => list.first,
            );
            _selectedTemplateId = int.tryParse(defaultTpl['id'].toString());
            _selectedTemplateName = defaultTpl['nama_template'] ?? '';
          }
        });

        if (_selectedTemplateId != null) {
          await _loadTemplateIndicators(_selectedTemplateId!);
        }
      }
    } catch (e) {
      debugPrint('Error loading checklist templates: $e');
    } finally {
      if (mounted) setState(() => _isLoadingChecklist = false);
    }
  }

  Future<void> _loadTemplateIndicators(int templateId) async {
    setState(() => _isLoadingChecklist = true);
    try {
      final res = await _service.getTemplateIndicators(templateId: templateId);
      if (!mounted) return;

      if (res['status'] == true && res['indicators'] != null) {
        final list = List<dynamic>.from(res['indicators']);
        setState(() {
          _checklistIndicators = list;
          _indicatorResults.clear();
          // Reset default result to OK for each indicator
          for (var ind in list) {
            final int id = int.tryParse(ind['indicator_id']?.toString() ?? '0') ?? 0;
            if (id > 0) {
              _indicatorResults[id] = 'OK';
              if (!_indicatorNoteControllers.containsKey(id)) {
                _indicatorNoteControllers[id] = TextEditingController();
              } else {
                _indicatorNoteControllers[id]?.clear();
              }
            }
          }
          _updateOverallStatus();
        });
      }
    } catch (e) {
      debugPrint('Error loading indicators: $e');
    } finally {
      if (mounted) setState(() => _isLoadingChecklist = false);
    }
  }

  void _updateOverallStatus() {
    bool hasNok = _indicatorResults.values.any((val) => val == 'NOK');
    setState(() {
      _overallStatus = hasNok ? 'Needs Repair' : 'Pass';
    });
  }

  Future<void> _submitInspection() async {
    if (_unitData == null || _selectedTemplateId == null) return;

    setState(() => _isSavingInspection = true);

    try {
      final String barcode = _unitData!['barcode'] ?? _barcodeController.text.trim();
      final int unitId = int.tryParse(_unitData!['id']?.toString() ?? '0') ?? 0;

      final activeRental = _unitData!['rental_aktif'];
      final int rentalId = activeRental != null ? (int.tryParse(activeRental['rental_id']?.toString() ?? '0') ?? 0) : 0;
      final String projectName = activeRental != null
          ? (activeRental['nama_perusahaan'] ?? activeRental['nama_pribadi'] ?? '')
          : '';

      final List<Map<String, dynamic>> itemsPayload = [];
      for (var ind in _checklistIndicators) {
        final int id = int.tryParse(ind['indicator_id']?.toString() ?? '0') ?? 0;
        final String res = _indicatorResults[id] ?? 'OK';
        final String note = _indicatorNoteControllers[id]?.text.trim() ?? '';
        itemsPayload.add({
          'indicator_id': id,
          'nama_indikator': ind['nama_indikator'] ?? '',
          'kategori': ind['kategori'] ?? 'Software',
          'status_hasil': res,
          'catatan_temuan': note,
        });
      }

      String kondisiSetelah = 'Baik';
      if (_overallStatus == 'Fail') {
        kondisiSetelah = 'Rusak';
      } else if (_overallStatus == 'Needs Repair') {
        kondisiSetelah = 'Perlu Servis';
      }

      final res = await _service.submitLaptopInspection(
        barcode: barcode,
        unitId: unitId,
        templateId: _selectedTemplateId,
        rentalId: rentalId,
        namaTemplate: _selectedTemplateName,
        namaProyek: projectName,
        overallStatus: _overallStatus,
        kondisiUnitSetelah: kondisiSetelah,
        catatanUmum: _overallNotesController.text.trim(),
        items: itemsPayload,
      );

      if (!mounted) return;

      if (res['status'] == true) {
        context.showSuccessSnackBar(res['message'] ?? 'Pemeriksaan checklist berhasil disimpan.');
        _overallNotesController.clear();
        await _fetchLaptopDetail(barcode);
      } else {
        context.showErrorSnackBar(res['message'] ?? 'Gagal menyimpan pemeriksaan.');
      }
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar('Terjadi kesalahan saat menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isSavingInspection = false);
    }
  }

  Future<void> _loadInspectionHistory(String barcode) async {
    setState(() => _isLoadingHistory = true);
    try {
      final res = await _service.getLaptopInspectionHistory(barcode);
      if (!mounted) return;

      if (res['status'] == true && res['data'] != null) {
        setState(() {
          _inspectionHistory = List<dynamic>.from(res['data']);
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _showDamageNotesModal() {
    if (_unitData == null) return;

    final String currentBarcode = _unitData!['barcode'] ?? _barcodeController.text.trim();
    final int unitId = int.tryParse(_unitData!['id']?.toString() ?? '0') ?? 0;
    String selectedKondisi = _unitData!['kondisi'] ?? 'Baru';
    String selectedStatus = _unitData!['status'] ?? 'Tersedia';
    final TextEditingController newNoteController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2026) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Catat Masalah / Kerusakan Laptop',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unit: ${_unitData!['nama_laptop'] ?? '-'} ($currentBarcode)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pilihan Kondisi
                      Text(
                        'Kondisi Fisik',
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
                          Color activeCol = Colors.green;
                          if (k == 'Rusak' || k == 'Perlu Servis') activeCol = Colors.redAccent;
                          if (k == 'Bekas') activeCol = Colors.teal;

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
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Layar flickering, keyboard tombol Enter macet...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF15171C) : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.grey[300]!,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7E57C2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
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
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Simpan Perubahan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }
    final Uri waUri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) context.showErrorSnackBar('Tidak dapat membuka WhatsApp');
    }
  }

  Future<void> _callPhone(String phone) async {
    final Uri callUri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      if (mounted) context.showErrorSnackBar('Tidak dapat melakukan panggilan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7E57C2);

    return Scaffold(
      appBar: SecondaryAppBar(
        title: 'Scan Barcode Laptop',
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
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

            // ── Laptop Detail & Checklist Content ───────────────────────────
            if (!_isLoading && _unitData != null) ...[
              _buildLaptopIdentityCard(isDark, primaryColor),
              const SizedBox(height: 14),
              _buildRentalStatusCard(isDark, primaryColor),
              const SizedBox(height: 14),
              _buildChecklistInspectionCard(isDark, primaryColor),
              const SizedBox(height: 14),
              _buildInspectionHistoryCard(isDark, primaryColor),
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
                                  _checklistIndicators.clear();
                                  _inspectionHistory.clear();
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
        color: isDark ? const Color(0xFF2C1618) : const Color(0xFFFDEDED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
          ),
          const SizedBox(width: 14),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.laptop_chromebook_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadge(status, statusColor),
                        _buildBadge('Kondisi: $kondisi', kondisiColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Barcode Unit',
                  value: barcode,
                  isCopyable: true,
                ),
              ),
              Expanded(
                child: _buildDetailRow(
                  icon: Icons.pin_outlined,
                  label: 'Serial Number (SN)',
                  value: sn,
                  isCopyable: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Tanggal Masuk',
            value: tanggalMasuk,
          ),
        ],
      ),
    );
  }

  Widget _buildRentalStatusCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;
    final activeRental = _unitData!['rental_aktif'];
    final bool isRented = activeRental != null;

    if (isRented) {
      final String tenantName = activeRental['nama_perusahaan'] ?? activeRental['nama_pribadi'] ?? 'Penyewa';
      final String invoiceNo = activeRental['invoice_number'] ?? '-';
      final String startDate = activeRental['tanggal_sewa'] ?? '-';
      final String dueDate = activeRental['jatuh_tempo'] ?? '-';
      final String duration = '${activeRental['lama_sewa'] ?? '-'} Hari';
      final String phone = activeRental['no_telpon'] ?? '';
      final int rentalId = int.tryParse(activeRental['rental_id']?.toString() ?? '0') ?? 0;

      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7E57C2).withValues(alpha: 0.3),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E57C2).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_center_rounded, color: Color(0xFF7E57C2), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sedang Disewa (Aktif)',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7E57C2),
                        ),
                      ),
                      Text(
                        'No. Invoice: $invoiceNo',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (rentalId > 0)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RentPlanDetailPage(
                            rentalId: rentalId,
                            invoiceNumber: invoiceNo,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Text(
                            'Detail',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7E57C2),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF7E57C2)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Nama Penyewa / Perusahaan',
              value: tenantName,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    icon: Icons.date_range_outlined,
                    label: 'Masa Sewa',
                    value: '$startDate s/d $dueDate',
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Durasi',
                    value: duration,
                  ),
                ),
              ],
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _openWhatsApp(phone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.call_outlined, size: 16),
                      label: const Text('Telepon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _callPhone(phone),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tersedia di Gudang (Siap Sewa)',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unit sedang tidak dalam masa sewa dan siap disewakan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── 3. Checklist Inspection Card ──────────────────────────────────────────
  Widget _buildChecklistInspectionCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;

    int totalIndicators = _checklistIndicators.length;
    int okCount = _indicatorResults.values.where((v) => v == 'OK').length;
    int nokCount = _indicatorResults.values.where((v) => v == 'NOK').length;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
          width: 1.5,
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fact_check_outlined, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checklist Pemeriksaan Laptop',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Pilih template proyek & periksa indikator yang tampil',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Template Selector
          Text(
            'Template Proyek Pengecekan:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),

          if (_templates.isEmpty && !_isLoadingChecklist)
            Text(
              'Belum ada template checklist dari Web Admin.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _templates.map((tpl) {
                  final int tplId = int.tryParse(tpl['id'].toString()) ?? 0;
                  final bool isSelected = _selectedTemplateId == tplId;
                  final int totalInd = int.tryParse(tpl['total_indikator']?.toString() ?? '0') ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text('${tpl['nama_template']} ($totalInd Item)'),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF10B981),
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedTemplateId = tplId;
                            _selectedTemplateName = tpl['nama_template'] ?? '';
                          });
                          _loadTemplateIndicators(tplId);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          // Indicators List
          if (_isLoadingChecklist)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
              ),
            )
          else if (_checklistIndicators.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Tidak ada indikator pada template ini.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else ...[
            // Status Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Indikator ($totalIndicators Item)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$okCount OK',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                    if (nokCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$nokCount NOK',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Indicators Items
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checklistIndicators.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ind = _checklistIndicators[index];
                final int indId = int.tryParse(ind['indicator_id']?.toString() ?? '0') ?? 0;
                final String name = ind['nama_indikator'] ?? 'Indikator';
                final String category = ind['kategori'] ?? 'Software';
                final String desc = ind['deskripsi'] ?? '';
                final String currentResult = _indicatorResults[indId] ?? 'OK';
                final bool isOk = currentResult == 'OK';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15171C) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOk
                          ? (isDark ? Colors.white12 : Colors.grey[300]!)
                          : Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Toggle Buttons OK / NOK
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _indicatorResults[indId] = 'OK';
                                    _updateOverallStatus();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isOk ? Colors.green : (isDark ? Colors.white10 : Colors.grey[200]),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: isOk ? Colors.white : Colors.grey[500],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'OK',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isOk ? Colors.white : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _indicatorResults[indId] = 'NOK';
                                    _updateOverallStatus();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: !isOk ? Colors.redAccent : (isDark ? Colors.white10 : Colors.grey[200]),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: !isOk ? Colors.white : Colors.grey[500],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'NOK',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: !isOk ? Colors.white : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Input note if NOK or for special findings
                      if (!isOk) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _indicatorNoteControllers[indId],
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Tulis kendala $name (misal: belum terpasang / bermasalah)...',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E2026) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // Overall Notes
            Text(
              'Catatan Tambahan Pemeriksaan (Opsional):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _overallNotesController,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Contoh: Siap dikirim ke lokasi tes, segel aman...',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF15171C) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey[300]!,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSavingInspection ? null : _submitInspection,
                child: _isSavingInspection
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.save_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Simpan Hasil Pemeriksaan',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 4. Inspection History Card ───────────────────────────────────────────
  Widget _buildInspectionHistoryCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Riwayat Pemeriksaan Checklist Unit',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (_isLoadingHistory)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const Divider(height: 20),

          if (_inspectionHistory.isEmpty && !_isLoadingHistory)
            Text(
              'Belum ada riwayat pemeriksaan checklist untuk unit ini.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _inspectionHistory.length > 5 ? 5 : _inspectionHistory.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final insp = _inspectionHistory[idx];
                final String date = insp['inspection_date'] ?? '-';
                final String tplName = insp['nama_template'] ?? 'Template';
                final String inspector = insp['inspected_by_name'] ?? 'Staff';
                final String status = insp['overall_status'] ?? 'Pass';
                final List<dynamic> items = List<dynamic>.from(insp['items'] ?? []);

                final bool isPass = status == 'Pass' || status == 'Lolos';
                final bool isRepair = status == 'Needs Repair' || status == 'Perlu Servis';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tplName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPass
                                ? Colors.green.withValues(alpha: 0.15)
                                : (isRepair ? Colors.orange.withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPass ? 'Lolos' : (isRepair ? 'Perlu Servis' : 'Gagal'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPass ? Colors.green : (isRepair ? Colors.orange : Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Oleh $inspector pada $date',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: items.map((it) {
                          final String iName = it['nama_indikator'] ?? '';
                          final bool itOk = (it['status_hasil'] ?? 'OK') == 'OK';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: itOk ? Colors.green.withValues(alpha: 0.08) : Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: itOk ? Colors.green.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  itOk ? Icons.check : Icons.close,
                                  size: 10,
                                  color: itOk ? Colors.green : Colors.redAccent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  iName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: itOk ? Colors.green[700] : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── 5. Damage Notes Card ──────────────────────────────────────────────────
  Widget _buildDamageNotesCard(bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E2026) : Colors.white;
    final String catatan = _unitData!['catatan'] ?? '';
    final bool hasNotes = catatan.trim().isNotEmpty;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.report_problem_outlined, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Catatan Log & Kerusakan',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 24),
                color: primaryColor,
                tooltip: 'Catat Masalah Baru',
                onPressed: _showDamageNotesModal,
              ),
            ],
          ),
          const Divider(height: 16),
          if (!hasNotes)
            Text(
              'Belum ada catatan kerusakan atau masalah pada laptop ini.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          else
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
                catatan,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text(
                'Catat Masalah / Kerusakan Laptop',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: _showDamageNotesModal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
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
    bool isCopyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isCopyable && value != '-')
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          context.showSuccessSnackBar('$label disalin!');
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
