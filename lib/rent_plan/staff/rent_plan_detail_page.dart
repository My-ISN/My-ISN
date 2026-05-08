import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/rent_plan_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../widgets/searchable_dropdown.dart';
import '../../localization/app_localizations.dart';
import '../../constants.dart';
import '../../widgets/custom_snackbar.dart';

import '../../widgets/secondary_app_bar.dart';

class RentPlanDetailPage extends StatefulWidget {
  final int rentalId;
  final String? invoiceNumber;
  const RentPlanDetailPage({
    super.key,
    required this.rentalId,
    this.invoiceNumber,
  });

  @override
  State<RentPlanDetailPage> createState() => _RentPlanDetailPageState();
}

class _RentPlanDetailPageState extends State<RentPlanDetailPage> {
  final RentPlanService _rentPlanService = RentPlanService();
  bool _isLoading = true;
  bool _isExpanded = false;
  String _activeTab = 'OVERVIEW';
  Map<String, dynamic>? _rentalData;
  Map<String, dynamic>? _debtData;
  List<dynamic> _installments = [];
  final Map<String, DateTime> _lastUpdateTimes = {};
  bool _isSaving = false;

  // Edit Controllers
  final _namaPribadiController = TextEditingController();
  final _nikPribadiController = TextEditingController();
  final _namaPerusahaanController = TextEditingController();
  final _npwpController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _lamaSewaController = TextEditingController();
  final _totalLaptopController = TextEditingController();
  final _notesController = TextEditingController();
  final _alamatKtpController = TextEditingController();
  final _alamatDomisiliController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _tanggalBerakhirController = TextEditingController();

  // Extension State
  final _extLamaSewaController = TextEditingController();
  final _extDiskonController = TextEditingController();
  final _extNotesController = TextEditingController();
  final Map<int, String?> _selectedExtJaminanIdsMap = {
    1: null,
    2: null,
    3: null,
  };
  final Map<int, File?> _extFileJaminanMap = {1: null, 2: null, 3: null};
  DateTime? _newEndDate;

  // Address State
  List<dynamic> _provinces = [];
  String? _selectedProvinceKtp;
  String? _selectedRegencyKtp;
  String? _selectedDistrictKtp;
  String? _selectedVillageKtp;
  List<dynamic> _regenciesKtp = [];
  List<dynamic> _districtsKtp = [];
  List<dynamic> _villagesKtp = [];
  bool _isLoadingRegKtp = false;
  bool _isLoadingDistKtp = false;
  bool _isLoadingVillKtp = false;

  String? _selectedProvinceCur;
  String? _selectedRegencyCur;
  String? _selectedDistrictCur;
  String? _selectedVillageCur;
  List<dynamic> _regenciesCur = [];
  List<dynamic> _districtsCur = [];
  List<dynamic> _villagesCur = [];
  bool _isLoadingRegCur = false;
  bool _isLoadingDistCur = false;
  bool _isLoadingVillCur = false;

  // Type & Shipping
  String _jenisSewa = 'pribadi';
  String? _selectedShippingId;
  String _tipePengiriman = '';
  List<dynamic> _shippingCosts = [];

  // Files & Guarantees
  File? _fileKtp;
  File? _fileNpwp;
  File? _filePo;
  File? _fileKtpPimpinan;
  File? _fileDomisiliPerusahaan;
  final Map<int, File?> _fileJaminan = {1: null, 2: null, 3: null};
  final Map<int, String?> _selectedJaminanIds = {1: null, 2: null, 3: null};
  List<dynamic> _jaminanPribadi = [];
  List<dynamic> _jaminanPerusahaan = [];
  List<dynamic> _pricingTiers = [];

  final List<String> _menuTabs = [
    'OVERVIEW',
    'EDIT',
    'RENTAL EXTEND',
    'INVOICE',
    'VIEW DOKUMEN',
    'PERJANJIAN SEWA',
    'SP-1',
    'SP-3 / SOMASI',
    'HUTANG',
  ];

  Color get _primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _initAllData();
  }

  Future<void> _initAllData() async {
    await _fetchDetail();
    await _fetchInitialFormData();
    // Setelah keduanya selesai, auto-load cascade address
    if (mounted) await _autoLoadCascadeAddresses();
  }

  Future<void> _fetchDetail({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final response = await _rentPlanService.getRentPlanDetail(widget.rentalId);
    if (response['status'] == true) {
      if (mounted) {
        setState(() {
          _rentalData = response['data']['rental'];
          _debtData = response['data']['debt'];
          _installments = response['data']['installments'] ?? [];
          _initializeControllers();
          if (!silent) _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        if (!silent) setState(() => _isLoading = false);
        context.showErrorSnackBar(
          response['message'] ??
              'rent_plan.failed_fetch_detail'.tr(context),
        );
      }
    }
  }

  // Region Loading Methods
  Future<void> _loadRegencies(String provinceId, bool isKtp) async {
    setState(() {
      if (isKtp) {
        _isLoadingRegKtp = true;
        _selectedRegencyKtp = null;
        _regenciesKtp = [];
        _selectedDistrictKtp = null;
        _districtsKtp = [];
        _selectedVillageKtp = null;
        _villagesKtp = [];
      } else {
        _isLoadingRegCur = true;
        _selectedRegencyCur = null;
        _regenciesCur = [];
        _selectedDistrictCur = null;
        _districtsCur = [];
        _selectedVillageCur = null;
        _villagesCur = [];
      }
    });

    final res = await _rentPlanService.getRegencies(provinceId);
    setState(() {
      if (isKtp) {
        _regenciesKtp = List<dynamic>.from(res['data'] ?? []);
        _isLoadingRegKtp = false;
      } else {
        _regenciesCur = List<dynamic>.from(res['data'] ?? []);
        _isLoadingRegCur = false;
      }
    });
  }

  Future<void> _loadDistricts(String regencyId, bool isKtp) async {
    setState(() {
      if (isKtp) {
        _isLoadingDistKtp = true;
        _selectedDistrictKtp = null;
        _districtsKtp = [];
        _selectedVillageKtp = null;
        _villagesKtp = [];
      } else {
        _isLoadingDistCur = true;
        _selectedDistrictCur = null;
        _districtsCur = [];
        _selectedVillageCur = null;
        _villagesCur = [];
      }
    });

    final res = await _rentPlanService.getDistricts(regencyId);
    setState(() {
      if (isKtp) {
        _districtsKtp = List<dynamic>.from(res['data'] ?? []);
        _isLoadingDistKtp = false;
      } else {
        _districtsCur = List<dynamic>.from(res['data'] ?? []);
        _isLoadingDistCur = false;
      }
    });
  }

  Future<void> _loadVillages(String districtId, bool isKtp) async {
    setState(() {
      if (isKtp) {
        _isLoadingVillKtp = true;
        _selectedVillageKtp = null;
        _villagesKtp = [];
      } else {
        _isLoadingVillCur = true;
        _selectedVillageCur = null;
        _villagesCur = [];
      }
    });

    final res = await _rentPlanService.getVillages(districtId);
    setState(() {
      if (isKtp) {
        _villagesKtp = List<dynamic>.from(res['data'] ?? []);
        _isLoadingVillKtp = false;
      } else {
        _villagesCur = List<dynamic>.from(res['data'] ?? []);
        _isLoadingVillCur = false;
      }
    });
  }

  Future<void> _pickFile(dynamic key) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        if (key == 0) {
          _fileKtp = File(result.files.single.path!);
        } else if (key is int)
          _fileJaminan[key] = File(result.files.single.path!);
        else if (key == 'npwp')
          _fileNpwp = File(result.files.single.path!);
        else if (key == 'po')
          _filePo = File(result.files.single.path!);
        else if (key == 'ktp_pimpinan')
          _fileKtpPimpinan = File(result.files.single.path!);
        else if (key == 'domisili')
          _fileDomisiliPerusahaan = File(result.files.single.path!);
      });
    }
  }

  Future<void> _fetchInitialFormData() async {
    final response = await _rentPlanService.getRentFormData();
    if (response['status'] == true) {
      final data = response['data'];
      if (mounted) {
        setState(() {
          _provinces = List<dynamic>.from(data['provinces'] ?? []);
          _jaminanPribadi = List<dynamic>.from(data['jaminan_pribadi'] ?? [])
              .where(
                (j) => j['category_name'].toString().toUpperCase() != 'KTP',
              )
              .toList();
          _jaminanPerusahaan =
              List<dynamic>.from(data['jaminan_perusahaan'] ?? [])
                  .where(
                    (j) => j['category_name'].toString().toUpperCase() != 'KTP',
                  )
                  .toList();
          _shippingCosts = List<dynamic>.from(data['shipping_costs'] ?? []);
          _pricingTiers = List<dynamic>.from(data['pricing_tiers'] ?? []);

          // Retry matching shipping if _rentalData is already loaded
          if (_rentalData != null && _rentalData!['tipe_pengiriman'] != null) {
            String tp = _rentalData!['tipe_pengiriman'].toString();
            final match = _shippingCosts.firstWhere(
              (s) =>
                  s['nama_kirim']?.toString().toLowerCase().trim() ==
                  tp.toLowerCase().trim(),
              orElse: () => null,
            );
            if (match != null) {
              _selectedShippingId = match['nama_kirim']?.toString();
            } else {
              _selectedShippingId = tp;
            }
          }

          // Auto-select "DEPOSIT" for jaminan 1
          try {
            final isPribadi = (_rentalData!['jenis_sewa'] ?? 'pribadi')
                    .toString()
                    .toLowerCase() ==
                'pribadi';
            final baseOptions = isPribadi ? _jaminanPribadi : _jaminanPerusahaan;
            final depositJaminan = baseOptions.firstWhere(
              (j) => j['category_name']
                  .toString()
                  .toUpperCase()
                  .contains('DEPOSIT'),
              orElse: () => null,
            );
            if (depositJaminan != null) {
              final depositId = (depositJaminan['constants_id'] ??
                      depositJaminan['id'])
                  .toString();
              _selectedJaminanIds[1] = depositId;
              _selectedExtJaminanIdsMap[1] = depositId;
            }
          } catch (_) {}
        });
      }
    }
  }

  /// Auto-load cascade address berdasarkan nama yang tersimpan di DB.
  /// Dipanggil setelah _fetchDetail dan _fetchInitialFormData keduanya selesai.
  Future<void> _autoLoadCascadeAddresses() async {
    if (_rentalData == null || _provinces.isEmpty) return;

    // --- Alamat KTP ---
    if (_selectedProvinceKtp != null && _selectedProvinceKtp!.isNotEmpty) {
      final pObj = _provinces.firstWhere(
        (p) =>
            p['name']?.toString().toLowerCase() ==
            _selectedProvinceKtp!.toLowerCase(),
        orElse: () => null,
      );
      if (pObj != null) {
        final res = await _rentPlanService.getRegencies(pObj['id'].toString());
        final regencies = List<dynamic>.from(res['data'] ?? []);
        if (mounted) setState(() => _regenciesKtp = regencies);

        if (_selectedRegencyKtp != null && _selectedRegencyKtp!.isNotEmpty) {
          final rObj = regencies.firstWhere(
            (r) =>
                r['name']?.toString().toLowerCase() ==
                _selectedRegencyKtp!.toLowerCase(),
            orElse: () => null,
          );
          if (rObj != null) {
            final res2 = await _rentPlanService.getDistricts(
              rObj['id'].toString(),
            );
            final districts = List<dynamic>.from(res2['data'] ?? []);
            if (mounted) setState(() => _districtsKtp = districts);

            if (_selectedDistrictKtp != null &&
                _selectedDistrictKtp!.isNotEmpty) {
              final dObj = districts.firstWhere(
                (d) =>
                    d['name']?.toString().toLowerCase() ==
                    _selectedDistrictKtp!.toLowerCase(),
                orElse: () => null,
              );
              if (dObj != null) {
                final res3 = await _rentPlanService.getVillages(
                  dObj['id'].toString(),
                );
                final villages = List<dynamic>.from(res3['data'] ?? []);
                if (mounted) setState(() => _villagesKtp = villages);
              }
            }
          }
        }
      }
    }

    // --- Alamat Domisili ---
    if (_selectedProvinceCur != null && _selectedProvinceCur!.isNotEmpty) {
      final pObj = _provinces.firstWhere(
        (p) =>
            p['name']?.toString().toLowerCase() ==
            _selectedProvinceCur!.toLowerCase(),
        orElse: () => null,
      );
      if (pObj != null) {
        final res = await _rentPlanService.getRegencies(pObj['id'].toString());
        final regencies = List<dynamic>.from(res['data'] ?? []);
        if (mounted) setState(() => _regenciesCur = regencies);

        if (_selectedRegencyCur != null && _selectedRegencyCur!.isNotEmpty) {
          final rObj = regencies.firstWhere(
            (r) =>
                r['name']?.toString().toLowerCase() ==
                _selectedRegencyCur!.toLowerCase(),
            orElse: () => null,
          );
          if (rObj != null) {
            final res2 = await _rentPlanService.getDistricts(
              rObj['id'].toString(),
            );
            final districts = List<dynamic>.from(res2['data'] ?? []);
            if (mounted) setState(() => _districtsCur = districts);

            if (_selectedDistrictCur != null &&
                _selectedDistrictCur!.isNotEmpty) {
              final dObj = districts.firstWhere(
                (d) =>
                    d['name']?.toString().toLowerCase() ==
                    _selectedDistrictCur!.toLowerCase(),
                orElse: () => null,
              );
              if (dObj != null) {
                final res3 = await _rentPlanService.getVillages(
                  dObj['id'].toString(),
                );
                final villages = List<dynamic>.from(res3['data'] ?? []);
                if (mounted) setState(() => _villagesCur = villages);
              }
            }
          }
        }
      }
    }
  }

  Future<void> _updateStatus(String field, dynamic value) async {
    // Rate Limiting: Minimal 2 detik antar request untuk field yang sama
    final now = DateTime.now();
    if (_lastUpdateTimes.containsKey(field)) {
      final lastUpdate = _lastUpdateTimes[field]!;
      if (now.difference(lastUpdate).inSeconds < 2) {
        context.showWarningSnackBar('rent_plan.please_wait'.tr(context));
        return;
      }
    }
    _lastUpdateTimes[field] = now;

    // Optimistic UI: Update state secara lokal dulu
    final originalValue = _rentalData![field];
    setState(() {
      _rentalData![field] = value;
    });

    final response = await _rentPlanService.updateRentPlanStatus(
      widget.rentalId,
      field,
      value,
    );
    if (response['status'] == true) {
      // Refresh data di background untuk memastikan sinkronisasi
      _fetchDetail(silent: true);
      if (mounted) {
        context.showSuccessSnackBar('rent_plan.status_updated'.tr(context));
      }
    } else {
      // Rollback jika gagal
      setState(() {
        _rentalData![field] = originalValue;
      });
      if (mounted) {
        context.showErrorSnackBar(
          response['message'] ??
              'rent_plan.failed_update_status'.tr(context),
        );
      }
    }
  }

  void _initializeControllers() {
    if (_rentalData == null) return;
    _namaPribadiController.text = _rentalData!['nama_pribadi'] ?? '';
    _nikPribadiController.text = _rentalData!['nik_pribadi'] ?? '';
    _namaPerusahaanController.text = _rentalData!['nama_perusahaan'] ?? '';
    _npwpController.text = _rentalData!['npwp'] ?? '';
    _whatsappController.text = _rentalData!['whatsapp'] ?? '';
    _emergencyContactController.text = _rentalData!['emergency_contact_number'] ?? '';
    _lamaSewaController.text = (_rentalData!['lama_sewa'] ?? '0').toString();
    _totalLaptopController.text = (_rentalData!['total_laptop'] ?? '0')
        .toString();
    _notesController.text = _rentalData!['notes'] ?? '';
    _invoiceDateController.text = _rentalData!['invoice_date'] ?? '';
    _tanggalBerakhirController.text = _rentalData!['tanggal_berakhir'] ?? '';

    setState(() {
      _jenisSewa = (_rentalData!['jenis_sewa'] ?? 'pribadi')
          .toString()
          .toLowerCase();

      // Regions (Names from DB)
      _selectedProvinceKtp = _rentalData!['provinsi_ktp'];
      _selectedRegencyKtp = _rentalData!['kabupaten_ktp'];
      _selectedDistrictKtp = _rentalData!['kecamatan_ktp'];
      _selectedVillageKtp = _rentalData!['desa_ktp'];

      _selectedProvinceCur = _rentalData!['provinsi_current'];
      _selectedRegencyCur = _rentalData!['kabupaten_current'];
      _selectedDistrictCur = _rentalData!['kecamatan_current'];
      _selectedVillageCur = _rentalData!['desa_current'];

      // Jaminan
      if (_rentalData!['jaminan_tambahan'] != null) {
        try {
          final List<dynamic> jIds = json.decode(
            _rentalData!['jaminan_tambahan'],
          );
          for (int i = 0; i < jIds.length; i++) {
            if (i < 3) _selectedJaminanIds[i + 1] = jIds[i]?.toString();
          }
        } catch (_) {}
      }

      _tipePengiriman = _rentalData!['tipe_pengiriman']?.toString() ?? '';

      // Match shipping id case-insensitively
      if (_shippingCosts.isNotEmpty && _tipePengiriman.isNotEmpty) {
        final match = _shippingCosts.firstWhere(
          (s) =>
              s['nama_kirim']?.toString().toLowerCase().trim() ==
              _tipePengiriman.toLowerCase().trim(),
          orElse: () => null,
        );
        if (match != null) {
          _selectedShippingId = match['nama_kirim']?.toString();
        } else {
          _selectedShippingId = _tipePengiriman;
        }
      } else {
        _selectedShippingId = _tipePengiriman.isNotEmpty
            ? _tipePengiriman
            : null;
      }
    });
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label, {
    TextEditingController? controller,
    bool enabled = true,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    int maxLines = 1,
    IconData? icon,
    String? suffix,
    bool isRequired = true,
    String? hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      validator: isRequired
          ? (val) =>
                val == null || val.isEmpty ? 'main.required'.tr(context) : null
          : null,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: Colors.grey[400])
            : null,
        suffixText: suffix,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildFileUploadTile(
    String label,
    File? file,
    VoidCallback onTap, {
    IconData? icon,
    String? existingUrl,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool hasFile =
        file != null || (existingUrl != null && existingUrl.isNotEmpty);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !hasFile
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50])
              : Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: !hasFile
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!)
                : Colors.green.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: !hasFile
                    ? _primaryColor.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.attach_file_rounded,
                color: !hasFile ? _primaryColor : Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file != null
                        ? file.path.split('/').last
                        : (existingUrl != null && existingUrl.isNotEmpty
                              ? 'rent_plan.file_saved'.tr(context)
                              : 'rent_plan.tap_to_select'.tr(context)),
                    style: TextStyle(
                      fontSize: 12,
                      color: !hasFile ? Colors.grey[500] : Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            if (hasFile)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDetailChanges() async {
    setState(() => _isSaving = true);

    final Map<String, dynamic> updateData = {
      'jenis_sewa': _jenisSewa,
      'whatsapp': _whatsappController.text,
      'lama_sewa': _lamaSewaController.text,
      'total_laptop': _totalLaptopController.text,
      'notes': _notesController.text,
      'tipe_pengiriman': _selectedShippingId,
      'invoice_date': _invoiceDateController.text,
      'emergency_contact_number': _emergencyContactController.text,

      // Address
      'provinsi_ktp': _selectedProvinceKtp,
      'kabupaten_ktp': _selectedRegencyKtp,
      'kecamatan_ktp': _selectedDistrictKtp,
      'desa_ktp': _selectedVillageKtp,

      'provinsi_current': _selectedProvinceCur,
      'kabupaten_current': _selectedRegencyCur,
      'kecamatan_current': _selectedDistrictCur,
      'desa_current': _selectedVillageCur,

      // Jaminan IDs
      'jaminan_ids': json.encode(
        _selectedJaminanIds.values.where((v) => v != null).toList(),
      ),
    };

    if (_jenisSewa == 'perusahaan') {
      updateData['nama_perusahaan'] = _namaPerusahaanController.text;
      updateData['npwp'] = _npwpController.text;
    } else {
      updateData['nama_pribadi'] = _namaPribadiController.text;
      updateData['nik_pribadi'] = _nikPribadiController.text;
    }

    // Files
    final List<http.MultipartFile> files = [];
    if (_fileKtp != null) {
      files.add(await http.MultipartFile.fromPath('file_ktp', _fileKtp!.path));
    }
    if (_fileNpwp != null) {
      files.add(
        await http.MultipartFile.fromPath('file_npwp', _fileNpwp!.path),
      );
    }
    if (_filePo != null) {
      files.add(await http.MultipartFile.fromPath('file_po', _filePo!.path));
    }
    if (_fileKtpPimpinan != null) {
      files.add(
        await http.MultipartFile.fromPath(
          'file_ktp_pimpinan',
          _fileKtpPimpinan!.path,
        ),
      );
    }
    if (_fileDomisiliPerusahaan != null) {
      files.add(
        await http.MultipartFile.fromPath(
          'file_domisili_perusahaan',
          _fileDomisiliPerusahaan!.path,
        ),
      );
    }

    for (int i = 1; i <= 3; i++) {
      if (_fileJaminan[i] != null) {
        files.add(
          await http.MultipartFile.fromPath(
            'file_jaminan_$i',
            _fileJaminan[i]!.path,
          ),
        );
      }
    }

    final response = await _rentPlanService.updateRentPlanDetail(
      widget.rentalId,
      updateData,
      files: files,
    );

    setState(() => _isSaving = false);

    if (response['status'] == true) {
      _fetchDetail(silent: true);
      if (mounted) {
        context.showSuccessSnackBar('rent_plan.detail_updated'.tr(context));
        setState(() => _activeTab = 'OVERVIEW');
      }
    } else {
      if (mounted) {
        context.showErrorSnackBar(
          response['message'] ??
              'rent_plan.failed_update_detail'.tr(context),
        );
      }
    }
  }

  @override
  void dispose() {
    _namaPribadiController.dispose();
    _nikPribadiController.dispose();
    _namaPerusahaanController.dispose();
    _npwpController.dispose();
    _whatsappController.dispose();
    _lamaSewaController.dispose();
    _totalLaptopController.dispose();
    _notesController.dispose();
    _alamatKtpController.dispose();
    _alamatDomisiliController.dispose();
    _invoiceDateController.dispose();
    _tanggalBerakhirController.dispose();
    _extLamaSewaController.dispose();
    _extDiskonController.dispose();
    _extNotesController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: SecondaryAppBar(title: widget.invoiceNumber ?? 'Detail Rental'),
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_rentalData == null) {
      return Scaffold(
        appBar: SecondaryAppBar(
          title: widget.invoiceNumber ?? 'rent_plan.rental_detail'.tr(context),
        ),
        body: Center(child: Text('rent_plan.data_not_found'.tr(context))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(
        title:
            _rentalData!['invoice_number'] ??
            widget.invoiceNumber ??
            'rent_plan.rental_detail'.tr(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCombinedControlCard(),
            const SizedBox(height: 20),
            _buildHorizontalMenu(),
            const SizedBox(height: 16),
            _buildActiveTabContent(),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalMenu() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _menuTabs.map((tab) {
          final bool isActive = _activeTab == tab;
          final bool isUrlTab = [
            'INVOICE',
            'PERJANJIAN SEWA',
            'SP-1',
            'SP-3 / SOMASI',
          ].contains(tab);
          final bool isHutang = tab == 'HUTANG';
          final double remainingDebt =
              double.tryParse(
                _rentalData!['remaining_debt']?.toString() ?? '0',
              ) ??
              0;
          final bool hasDebt = isHutang && remainingDebt > 0;
          final Color tabActiveColor = hasDebt
              ? Colors.redAccent
              : _primaryColor;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: isUrlTab
                  ? () => _launchDocumentUrl(tab)
                  : () => setState(() => _activeTab = tab),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? tabActiveColor
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? tabActiveColor.withValues(alpha: 0.2)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  _getTabLabel(tab),
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : (hasDebt ? Colors.redAccent : Colors.grey[600]),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getTabLabel(String tab) {
    switch (tab) {
      case 'OVERVIEW':
        return 'rent_plan.overview'.tr(context);
      case 'EDIT':
        return 'rent_plan.edit'.tr(context);
      case 'RENTAL EXTEND':
        return 'rent_plan.rental_extend'.tr(context);
      case 'INVOICE':
        return 'rent_plan.invoice'.tr(context);
      case 'VIEW DOKUMEN':
        return 'rent_plan.view_document'.tr(context);
      case 'PERJANJIAN SEWA':
        return 'rent_plan.rental_agreement'.tr(context);
      case 'SP-1':
        return 'rent_plan.sp1'.tr(context);
      case 'SP-3 / SOMASI':
        return 'rent_plan.sp3_somasi'.tr(context);
      case 'HUTANG':
        return 'rent_plan.debt'.tr(context);
      default:
        return tab;
    }
  }

  Future<void> _launchDocumentUrl(String tab) async {
    String endpoint = '';
    switch (tab) {
      case 'INVOICE':
        endpoint = 'invoice';
        break;
      case 'PERJANJIAN SEWA':
        endpoint = 'agreement';
        break;
      case 'SP-1':
        endpoint = 'sp1';
        break;
      case 'SP-3 / SOMASI':
        endpoint = 'sp3';
        break;
    }

    if (endpoint.isEmpty) return;

    final String secret =
        '${widget.rentalId}myisn_mobile_invoice_secret_2024';
    final String token = md5.convert(utf8.encode(secret)).toString();
    final url = Uri.parse(
      '${AppConstants.serverRoot}/erp/rentals/$endpoint/${widget.rentalId}?token=$token',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        context.showSuccessSnackBar(
          '${'rent_plan.opening'.tr(context)} ${tab.toLowerCase()}',
        );
      }
    }
  }

  Widget _buildActiveTabContent() {
    if (_activeTab == 'EDIT') return _buildEditTab();
    if (_activeTab == 'VIEW DOKUMEN') return _buildViewDokumenTab();
    if (_activeTab == 'OVERVIEW') return _buildOverviewTab();
    if (_activeTab == 'HUTANG') return _buildHutangTab();
    if (_activeTab == 'RENTAL EXTEND') return _buildRentalExtendTab();
    return _buildPlaceholderTab();
  }

  Widget _buildExtJaminanSelector(int index) {
    final isPribadi =
        (_rentalData!['jenis_sewa'] ?? 'pribadi').toString().toLowerCase() ==
        'pribadi';
    List<dynamic> baseOptions = isPribadi
        ? _jaminanPribadi
        : _jaminanPerusahaan;

    // Filter options to exclude those already selected in OTHER slots
    List<dynamic> availableOptions = baseOptions.where((j) {
      String id = j['constants_id']?.toString() ?? j['id']?.toString() ?? '';
      bool alreadySelectedElsewhere = false;
      _selectedExtJaminanIdsMap.forEach((key, value) {
        if (key != index && value == id) alreadySelectedElsewhere = true;
      });
      return !alreadySelectedElsewhere;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SearchableDropdown(
            label: '${'rent_plan.guarantee'.tr(context)} $index',
            value: _selectedExtJaminanIdsMap[index] != null
                ? availableOptions.firstWhere(
                        (j) =>
                            (j['constants_id']?.toString() ??
                                j['id']?.toString()) ==
                            _selectedExtJaminanIdsMap[index],
                        orElse: () => {},
                      )['category_name'] ??
                      ''
                : '',
            options: availableOptions
                .map(
                  (j) => {
                    'id':
                        j['constants_id']?.toString() ??
                        j['id']?.toString() ??
                        '',
                    'name': j['category_name']?.toString() ?? '',
                  },
                )
                .toList(),
            enabled: index != 1,
            onSelected: index == 1 ? (_) {} : (val) {
              setState(() {
                _selectedExtJaminanIdsMap[index] = val;
              });
            },
            placeholder: '${'rent_plan.select_guarantee'.tr(context)} $index',
          ),
          if (_selectedExtJaminanIdsMap[index] != null) ...[
            Builder(
              builder: (context) {
                final selectedJaminan = baseOptions.firstWhere(
                  (j) => (j['constants_id']?.toString() ?? j['id']?.toString()) == _selectedExtJaminanIdsMap[index],
                  orElse: () => null,
                );
                final isDeposit = selectedJaminan != null &&
                    selectedJaminan['category_name'].toString().toUpperCase().contains('DEPOSIT');

                if (isDeposit) {
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'rent_plan.deposit_no_upload'.tr(context),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildFileUploadTile(
                      '${'rent_plan.guarantee_file'.tr(context)} $index',
                      _extFileJaminanMap[index],
                      () => _pickExtFile(index),
                      icon: Icons.upload_file_rounded,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickExtFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _extFileJaminanMap[index] = File(result.files.single.path!);
      });
    }
  }

  double _calculatePriceForExtension() {
    if (_rentalData == null) return 0;
    int units =
        int.tryParse(_rentalData!['total_laptop']?.toString() ?? '1') ?? 1;
    double price = 0;

    for (var tier in _pricingTiers) {
      int min = int.tryParse(tier['nama_harga'].toString()) ?? 0;
      int max = int.tryParse(tier['nama_harga2'].toString()) ?? 999999;

      if (tier == _pricingTiers.last && units >= min) {
        price = double.tryParse(tier['harga'].toString()) ?? 0;
        break;
      }
      if (units >= min && units <= max) {
        price = double.tryParse(tier['harga'].toString()) ?? 0;
        break;
      }
    }
    return price;
  }

  Widget _buildRentalExtendTab() {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isPribadi =
        (_rentalData!['jenis_sewa'] ?? 'pribadi').toString().toLowerCase() ==
        'pribadi';

    // Calculate price
    final double pricePerDay = _calculatePriceForExtension();
    final int units =
        int.tryParse(_rentalData!['total_laptop']?.toString() ?? '1') ?? 1;
    final int days = int.tryParse(_extLamaSewaController.text) ?? 0;
    final double totalExt = pricePerDay * days * units;

    return Column(
      children: [
        _buildSection(
          title: 'rent_plan.extension_form'.tr(context),
          icon: Icons.history_edu_rounded,
          color: Colors.blue[700]!,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    'rent_plan.duration'.tr(context),
                    controller: _extLamaSewaController,
                    icon: Icons.timer_outlined,
                    suffix: 'rent_plan.days'.tr(context),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateNewEndDate(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    'rent_plan.new_end_date'.tr(context),
                    controller: TextEditingController(
                      text: _newEndDate != null
                          ? DateFormat('yyyy-MM-dd').format(_newEndDate!)
                          : '-',
                    ),
                    enabled: false,
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
              ],
            ),
            if (days > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'rent_plan.ext_price_est'.tr(context),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            '${currencyFormat.format(pricePerDay)} x $days ${'rent_plan.days'.tr(context)} x $units ${'dashboard.unit'.tr(context)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currencyFormat.format(totalExt),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${'rent_plan.guarantee'.tr(context)} *',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 1; i <= (isPribadi ? 3 : 2); i++) ...[
              _buildExtJaminanSelector(i),
            ],
            const SizedBox(height: 24),
            _buildTextField(
              'rent_plan.discount_code'.tr(context),
              controller: _extDiskonController,
              icon: Icons.confirmation_number_outlined,
              isRequired: false,
              hint: 'rent_plan.discount_hint'.tr(context),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'rent_plan.additional_notes'.tr(context),
              controller: _extNotesController,
              icon: Icons.notes_rounded,
              isRequired: false,
              maxLines: 3,
              hint: 'rent_plan.notes_hint'.tr(context),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitExtension,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'rent_plan.process_extension'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updateNewEndDate() {
    final daysStr = _extLamaSewaController.text;
    if (daysStr.isEmpty) {
      setState(() => _newEndDate = null);
      return;
    }
    final int days = int.tryParse(daysStr) ?? 0;
    if (days <= 0) {
      setState(() => _newEndDate = null);
      return;
    }

    DateTime currentEnd;
    try {
      currentEnd = DateFormat(
        'yyyy-MM-dd',
      ).parse(_rentalData!['tanggal_berakhir'] ?? '');
    } catch (_) {
      currentEnd = DateTime.now();
    }

    setState(() {
      _newEndDate = currentEnd.add(Duration(days: days));
    });
  }

  Future<void> _submitExtension() async {
    final isPribadi =
        (_rentalData!['jenis_sewa'] ?? 'pribadi').toString().toLowerCase() ==
        'pribadi';
    final requiredCount = isPribadi ? 3 : 2;

    if (_extLamaSewaController.text.isEmpty) {
      context.showWarningSnackBar('rent_plan.duration_required'.tr(context));
      return;
    }

    final selectedIds = _selectedExtJaminanIdsMap.values
        .where((id) => id != null)
        .cast<String>()
        .toList();
    if (selectedIds.length < requiredCount) {
      context.showWarningSnackBar(
        '${'rent_plan.select'.tr(context)} $requiredCount ${'rent_plan.guarantee'.tr(context)}',
      );
      return;
    }

    final baseOptions = isPribadi ? _jaminanPribadi : _jaminanPerusahaan;

    // Check if files are uploaded for all selected guarantees
    for (int i = 1; i <= requiredCount; i++) {
      final jId = _selectedExtJaminanIdsMap[i];
      if (jId != null) {
        final jType = baseOptions.firstWhere(
          (j) => (j['constants_id']?.toString() ?? j['id']?.toString()) == jId,
          orElse: () => null,
        );
        final isDeposit = jType != null &&
            jType['category_name'].toString().toUpperCase().contains('DEPOSIT');

        if (!isDeposit && _extFileJaminanMap[i] == null) {
          context.showWarningSnackBar(
            '${'rent_plan.upload_guarantee_file'.tr(context)} $i',
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> data = {
      'lama_sewa': _extLamaSewaController.text,
      'tanggal_selesai_baru': _newEndDate != null
          ? DateFormat('yyyy-MM-dd').format(_newEndDate!)
          : null,
      'jaminan_ids': selectedIds,
      'kode_diskon': _extDiskonController.text,
      'catatan': _extNotesController.text,
    };

    final Map<String, File?> fileParams = {};
    _extFileJaminanMap.forEach((key, value) {
      if (value != null) fileParams[key.toString()] = value;
    });

    final res = await _rentPlanService.extendRental(
      widget.rentalId,
      data,
      fileParams,
    );

    setState(() => _isSaving = false);

    if (res['status'] == true) {
      context.showSuccessSnackBar('rent_plan.extension_success'.tr(context));
      _extLamaSewaController.clear();
      _extDiskonController.clear();
      _extNotesController.clear();
      setState(() {
        _selectedExtJaminanIdsMap.forEach((key, value) {
          _selectedExtJaminanIdsMap[key] = null;
        });
        _extFileJaminanMap.forEach((key, value) {
          _extFileJaminanMap[key] = null;
        });
        _newEndDate = null;
        _activeTab = 'OVERVIEW';
      });
      _fetchDetail();
    } else {
      context.showErrorSnackBar(
        res['message'] ?? 'rent_plan.extension_failed'.tr(context),
      );
    }
  }

  Widget _buildEditTab() {
    return Column(
      children: [
        _buildSection(
          title: 'rent_plan.renter_data'.tr(context),
          icon: Icons.person_rounded,
          color: _primaryColor,
          children: [
            _buildTipePenyewaToggle(),
            const SizedBox(height: 16),
            if (_jenisSewa == 'pribadi') ...[
              _buildTextField(
                'rent_plan.full_name'.tr(context),
                controller: _namaPribadiController,
                icon: Icons.badge_rounded,
                onChanged: (value) {
                  _namaPribadiController.value = TextEditingValue(
                    text: value.toUpperCase(),
                    selection: _namaPribadiController.selection,
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'rent_plan.nik'.tr(context),
                controller: _nikPribadiController,
                icon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
              ),
            ] else ...[
              _buildTextField(
                'rent_plan.company_name'.tr(context),
                controller: _namaPerusahaanController,
                icon: Icons.business_rounded,
                onChanged: (value) {
                  _namaPerusahaanController.value = TextEditingValue(
                    text: value.toUpperCase(),
                    selection: _namaPerusahaanController.selection,
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'rent_plan.npwp_number'.tr(context),
                controller: _npwpController,
                icon: Icons.description_rounded,
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              'rent_plan.whatsapp'.tr(context),
              controller: _whatsappController,
              icon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'rent_plan.emergency_contact'.tr(context),
              controller: _emergencyContactController,
              icon: Icons.contact_phone_rounded,
              keyboardType: TextInputType.phone,
              hint: 'rent_plan.phone_hint'.tr(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'rent_plan.ktp_address'.tr(context),
          icon: Icons.assignment_ind_rounded,
          color: Colors.indigo[700]!,
          children: [_buildRegionDropdowns(true)],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'rent_plan.current_address_section'.tr(context),
          icon: Icons.home_rounded,
          color: Colors.teal[700]!,
          children: [_buildRegionDropdowns(false)],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'rent_plan.docs_guarantees'.tr(context),
          icon: Icons.verified_user_rounded,
          color: Colors.deepPurple[700]!,
          children: [
            if (_jenisSewa == 'pribadi') ...[
              _buildFileUploadTile(
                'rent_plan.customer_ktp'.tr(context),
                _fileKtp,
                () => _pickFile(0),
                icon: Icons.camera_alt_rounded,
                existingUrl: _rentalData!['file_ktp'],
              ),
              const Divider(height: 32),
            ] else ...[
              _buildFileUploadTile(
                'rent_plan.upload_npwp'.tr(context),
                _fileNpwp,
                () => _pickFile('npwp'),
                icon: Icons.upload_file_rounded,
                existingUrl: _rentalData!['file_npwp'],
              ),
              const SizedBox(height: 12),
              _buildFileUploadTile(
                'rent_plan.upload_po'.tr(context),
                _filePo,
                () => _pickFile('po'),
                icon: Icons.upload_file_rounded,
                existingUrl: _rentalData!['file_po'],
              ),
              const SizedBox(height: 12),
              _buildFileUploadTile(
                'rent_plan.upload_leader_ktp'.tr(context),
                _fileKtpPimpinan,
                () => _pickFile('ktp_pimpinan'),
                icon: Icons.upload_file_rounded,
                existingUrl: _rentalData!['file_ktp_pimpinan'],
              ),
              const SizedBox(height: 12),
              _buildFileUploadTile(
                'rent_plan.company_domicile'.tr(context),
                _fileDomisiliPerusahaan,
                () => _pickFile('domisili'),
                icon: Icons.upload_file_rounded,
                existingUrl: _rentalData!['domisili'],
              ),
              const Divider(height: 32),
            ],
            Text(
              '${'rent_plan.guarantee'.tr(context)} (${'main.required'.tr(context)} ${_jenisSewa == 'pribadi' ? 3 : 2})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 1; i <= (_jenisSewa == 'pribadi' ? 3 : 2); i++) ...[
              _buildJaminanSelector(i),
              if (i < (_jenisSewa == 'pribadi' ? 3 : 2))
                const SizedBox(height: 12),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'rent_plan.rental_detail_section'.tr(context),
          icon: Icons.calendar_month_rounded,
          color: Colors.orange[800]!,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(_invoiceDateController.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(
                          () => _invoiceDateController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(date),
                        );
                      }
                    },
                    child: _buildTextField(
                      'rent_plan.start_date'.tr(context),
                      controller: _invoiceDateController,
                      enabled: false,
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    'rent_plan.duration'.tr(context),
                    controller: _lamaSewaController,
                    suffix: 'rent_plan.days'.tr(context),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'rent_plan.unit_count'.tr(context),
              controller: _totalLaptopController,
              icon: Icons.laptop_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildShippingDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              'rent_plan.admin_fee'.tr(context),
              controller: TextEditingController(text: 'Rp 7.000'),
              enabled: false,
              icon: Icons.admin_panel_settings_rounded,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'rent_plan.notes'.tr(context),
              controller: _notesController,
              maxLines: 3,
              icon: Icons.notes_rounded,
              isRequired: false,
            ),
          ],
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveDetailChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: _isSaving
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'rent_plan.saving'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save_rounded),
                      const SizedBox(width: 8),
                      Text(
                        'rent_plan.save_changes'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildShippingDropdown() {
    final String selectedName = _selectedShippingId != null
        ? _shippingCosts.firstWhere(
                    (s) => s['nama_kirim']?.toString() == _selectedShippingId,
                    orElse: () => {},
                  )['nama_kirim'] !=
                  null
              ? '${_shippingCosts.firstWhere((s) => s['nama_kirim']?.toString() == _selectedShippingId)['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.parse(_shippingCosts.firstWhere((s) => s['nama_kirim']?.toString() == _selectedShippingId)['field_one']))}'
              : _selectedShippingId ?? ''
        : '';

    return SearchableDropdown(
      label: 'rent_plan.shipping_service'.tr(context),
      value: selectedName,
      options: _shippingCosts
          .map(
            (s) => {
              'id': s['nama_kirim'].toString(),
              'name':
                  '${s['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.parse(s['field_one']))}',
            },
          )
          .toList(),
      onSelected: (val) {
        final ship = _shippingCosts.firstWhere(
          (s) => s['nama_kirim'].toString() == val,
          orElse: () => null,
        );
        setState(() {
          _selectedShippingId = val;
          if (ship != null) {
            _tipePengiriman = ship['category_name'] ?? val;
          } else {
            _tipePengiriman = val;
          }
        });
      },
      placeholder: 'rent_plan.select_shipping'.tr(context),
    );
  }

  Widget _buildTipePenyewaToggle() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleItem(
            'rent_plan.personal'.tr(context),
            _jenisSewa == 'pribadi',
            () => setState(() {
              _jenisSewa = 'pribadi';
            }),
          ),
          _buildToggleItem(
            'rent_plan.company'.tr(context),
            _jenisSewa == 'perusahaan',
            () => setState(() {
              _jenisSewa = 'perusahaan';
              _selectedJaminanIds[3] = null;
              _fileJaminan[3] = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).scaffoldBackgroundColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? _primaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? _primaryColor
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white60
                          : Colors.grey[600]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionDropdowns(bool isKtp) {
    final String? currentProvinceName = isKtp
        ? _selectedProvinceKtp
        : _selectedProvinceCur;
    final String? currentRegencyName = isKtp
        ? _selectedRegencyKtp
        : _selectedRegencyCur;
    final String? currentDistrictName = isKtp
        ? _selectedDistrictKtp
        : _selectedDistrictCur;
    final String? currentVillageName = isKtp
        ? _selectedVillageKtp
        : _selectedVillageCur;

    final List<dynamic> currentRegencies = isKtp
        ? _regenciesKtp
        : _regenciesCur;
    final List<dynamic> currentDistricts = isKtp
        ? _districtsKtp
        : _districtsCur;
    final List<dynamic> currentVillages = isKtp ? _villagesKtp : _villagesCur;

    return Column(
      children: [
        SearchableDropdown(
          label: 'profile.state_province'.tr(context),
          value: currentProvinceName ?? '',
          options: _provinces
              .map(
                (p) => {
                  'id': p['name'].toString(), // DB stores names
                  'name': p['name'].toString(),
                },
              )
              .toList(),
          onSelected: (val) {
            setState(() {
              if (isKtp) {
                _selectedProvinceKtp = val;
              } else {
                _selectedProvinceCur = val;
              }
            });
            final pObj = _provinces.firstWhere((p) => p['name'] == val);
            _loadRegencies(pObj['id'].toString(), isKtp);
          },
          placeholder: 'rent_plan.select_province'.tr(context),
        ),
        const SizedBox(height: 12),
        SearchableDropdown(
          label: 'profile.city_regency'.tr(context),
          value: currentRegencyName ?? '',
          options: currentRegencies
              .map(
                (p) => {
                  'id': p['name'].toString(),
                  'name': p['name'].toString(),
                },
              )
              .toList(),
          onSelected: (val) {
            setState(() {
              if (isKtp) {
                _selectedRegencyKtp = val;
              } else {
                _selectedRegencyCur = val;
              }
            });
            final rObj = currentRegencies.firstWhere((r) => r['name'] == val);
            _loadDistricts(rObj['id'].toString(), isKtp);
          },
          placeholder: (isKtp ? _isLoadingRegKtp : _isLoadingRegCur)
              ? 'profile.loading'.tr(context)
              : 'rent_plan.select_regency'.tr(context),
        ),
        const SizedBox(height: 12),
        SearchableDropdown(
          label: 'rent_plan.district'.tr(context),
          value: currentDistrictName ?? '',
          options: currentDistricts
              .map(
                (p) => {
                  'id': p['name'].toString(),
                  'name': p['name'].toString(),
                },
              )
              .toList(),
          onSelected: (val) {
            setState(() {
              if (isKtp) {
                _selectedDistrictKtp = val;
              } else {
                _selectedDistrictCur = val;
              }
            });
            final dObj = currentDistricts.firstWhere((d) => d['name'] == val);
            _loadVillages(dObj['id'].toString(), isKtp);
          },
          placeholder: (isKtp ? _isLoadingDistKtp : _isLoadingDistCur)
              ? 'profile.loading'.tr(context)
              : 'rent_plan.select_district'.tr(context),
        ),
        const SizedBox(height: 12),
        SearchableDropdown(
          label: 'rent_plan.village'.tr(context),
          value: currentVillageName ?? '',
          options: currentVillages
              .map(
                (p) => {
                  'id': p['name'].toString(),
                  'name': p['name'].toString(),
                },
              )
              .toList(),
          onSelected: (val) {
            setState(() {
              if (isKtp) {
                _selectedVillageKtp = val;
              } else {
                _selectedVillageCur = val;
              }
            });
          },
          placeholder: (isKtp ? _isLoadingVillKtp : _isLoadingVillCur)
              ? 'profile.loading'.tr(context)
              : 'rent_plan.select_village'.tr(context),
        ),
      ],
    );
  }

  Widget _buildJaminanSelector(int index) {
    List<dynamic> baseOptions = _jenisSewa == 'pribadi'
        ? _jaminanPribadi
        : _jaminanPerusahaan;
    List<dynamic> availableOptions = baseOptions.where((j) {
      String id = j['constants_id'].toString();
      bool alreadySelectedElsewhere = false;
      _selectedJaminanIds.forEach((key, value) {
        if (key != index && value == id) alreadySelectedElsewhere = true;
      });
      return !alreadySelectedElsewhere;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          SearchableDropdown(
            label: '${'rent_plan.guarantee'.tr(context)} $index',
            value: _selectedJaminanIds[index] != null
                ? availableOptions.firstWhere(
                        (j) =>
                            j['constants_id'].toString() ==
                            _selectedJaminanIds[index],
                        orElse: () => {},
                      )['category_name'] ??
                      ''
                : '',
            options: availableOptions
                .map(
                  (j) => {
                    'id': j['constants_id'].toString(),
                    'name': j['category_name'].toString(),
                  },
                )
                .toList(),
            enabled: index != 1,
            onSelected: index == 1 ? (_) {} : (val) {
              setState(() {
                _selectedJaminanIds[index] = val;
              });
            },
            placeholder: '${'rent_plan.select_guarantee'.tr(context)} $index',
          ),
          if (_selectedJaminanIds[index] != null) ...[
            Builder(
              builder: (context) {
                final selectedJaminan = baseOptions.firstWhere(
                  (j) => j['constants_id'].toString() == _selectedJaminanIds[index],
                  orElse: () => null,
                );
                final isDeposit = selectedJaminan != null &&
                    selectedJaminan['category_name'].toString().toUpperCase().contains('DEPOSIT');

                if (isDeposit) {
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Jaminan Deposit tidak memerlukan upload file.',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildFileUploadTile(
                      '${'rent_plan.guarantee_file'.tr(context)} $index',
                      _fileJaminan[index],
                      () => _pickFile(index),
                      icon: Icons.upload_file_rounded,
                      existingUrl: _rentalData!['foto_jaminan$index'],
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isPerusahaan =
        _rentalData!['jenis_sewa']?.toString().toLowerCase() == 'perusahaan';

    return Column(
      children: [
        // 1. Identitas Penyewa
        _buildSectionTitle(
          Icons.person_pin_rounded,
          'rent_plan.renter_identity'.tr(context),
        ),
        _buildOverviewCard([
          _buildRowTwoFields(
            isPerusahaan
                ? 'rent_plan.company_name'.tr(context)
                : 'rent_plan.customer_name'.tr(context),
            _rentalData!['first_name'] ??
                _rentalData!['nama_pribadi'] ??
                _rentalData!['nama_perusahaan'] ??
                '-',
            isPerusahaan
                ? 'rent_plan.npwp'.tr(context)
                : 'rent_plan.nik'.tr(context),
            _rentalData!['npwp'] ?? _rentalData!['nik'] ?? '-',
          ),
          _buildRowTwoFields(
            'rent_plan.whatsapp'.tr(context),
            _rentalData!['whatsapp'] ?? _rentalData!['renter_contact'] ?? '-',
            'Nomor Keluarga (Darurat)',
            _rentalData!['emergency_contact_number'] ?? '-',
          ),
          _buildRowTwoFields(
            'rent_plan.ktp_address'.tr(context),
            _rentalData!['alamat_ktp_formatted'] ??
                _rentalData!['alamat_ktp'] ??
                '-',
            'rent_plan.current_address'.tr(context),
            _rentalData!['alamat_current_formatted'] ??
                _rentalData!['alamat_domisili'] ??
                _rentalData!['alamat_instansi'] ??
                '-',
          ),
        ]),

        const SizedBox(height: 20),

        // 2. Detail Sewa
        _buildSectionTitle(
          Icons.laptop_rounded,
          'rent_plan.rental_detail_section'.tr(context),
        ),
        _buildOverviewCard([
          _buildRowTwoFields(
            'rent_plan.laptop'.tr(context),
            _rentalData!['nama_laptop'] ??
                _rentalData!['laptop_name'] ??
                _rentalData!['item_name'] ??
                '-',
            'rent_plan.invoice_number'.tr(context),
            _rentalData!['invoice_number'] ?? '-',
          ),
          _buildRowTwoFields(
            'rent_plan.renter_type'.tr(context),
            (_rentalData!['jenis_sewa']?.toString().toLowerCase() ??
                        'pribadi') ==
                    'perusahaan'
                ? 'rent_plan.company'.tr(context).toUpperCase()
                : 'rent_plan.personal'.tr(context).toUpperCase(),
            'rent_plan.start_date'.tr(context),
            _rentalData!['invoice_date'] ?? '-',
          ),
          _buildRowTwoFields(
            'rent_plan.end_date'.tr(context),
            _rentalData!['tanggal_berakhir'] ?? '-',
            'rent_plan.unit_count'.tr(context),
            '${_rentalData!['total_laptop'] ?? 0} ${'dashboard.unit'.tr(context)}',
          ),
          _buildRowTwoFields(
            'rent_plan.duration'.tr(context),
            '${_rentalData!['lama_sewa'] ?? 0} ${'rent_plan.days'.tr(context)}',
            '',
            '',
          ),
        ]),

        const SizedBox(height: 20),

        // 3. Harga & Status
        _buildSectionTitle(
          Icons.monetization_on_rounded,
          'rent_plan.price_status'.tr(context),
        ),
        _buildOverviewCard([
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _rentalData!['status_pembayaran'] == 'sudah'
                  ? Colors.green.withValues(alpha: 0.05)
                  : Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _rentalData!['status_pembayaran'] == 'sudah'
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'rent_plan.total_cost'.tr(context).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currencyFormat.format(
                        double.tryParse(
                              _rentalData!['grand_total']?.toString() ?? '0',
                            ) ??
                            0,
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _rentalData!['status_pembayaran'] == 'sudah'
                            ? Colors.green
                            : Colors.red,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _rentalData!['status_pembayaran'] == 'sudah'
                        ? Colors.green
                        : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (_rentalData!['status_pembayaran'] == 'sudah'
                            ? 'rent_plan.paid'.tr(context)
                            : 'rent_plan.unpaid'.tr(context))
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildRowTwoFields(
            'Biaya Ongkir',
            currencyFormat.format(
              double.tryParse(
                    _rentalData!['biaya_kirim']?.toString() ?? '0',
                  ) ??
                  0,
            ),
            'Biaya Administrasi',
            'Rp 7.000',
            valColor1: Colors.blue,
            valColor2: Colors.green,
          ),
          _buildRowTwoFields(
            'rent_plan.payment_status'.tr(context),
            _rentalData!['status_pembayaran'] == 'sudah'
                ? 'rent_plan.paid'.tr(context)
                : 'rent_plan.unpaid'.tr(context),
            'rent_plan.fine_status'.tr(context),
            _rentalData!['status_denda'] == 'yes'
                ? 'rent_plan.fine'.tr(context)
                : 'rent_plan.safe'.tr(context),
            valColor1: _rentalData!['status_pembayaran'] == 'sudah'
                ? Colors.green
                : Colors.orange,
            valColor2: _rentalData!['status_denda'] == 'yes'
                ? Colors.red
                : Colors.green,
          ),
          _buildRowTwoFields(
            'rent_plan.approval_status'.tr(context),
            _rentalData!['status_approve'] == 'disetujui'
                ? 'rent_plan.approved'.tr(context)
                : 'rent_plan.pending'.tr(context),
            'rent_plan.rental_status'.tr(context),
            _getRentalStatusLabel(_rentalData!['status'] ?? '-'),
            valColor1: _rentalData!['status_approve'] == 'disetujui'
                ? Colors.green
                : Colors.orange,
            valColor2: _getRentalStatusColor(_rentalData!['status'] ?? ''),
          ),
        ]),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPlaceholderTab() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.construction_rounded,
            size: 64,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            '${'rent_plan.tab_content'.tr(context)} $_activeTab ${'rent_plan.under_development'.tr(context)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRowTwoFields(
    String label1,
    String val1,
    String label2,
    String val2, {
    Color? valColor1,
    Color? valColor2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  val1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: valColor1 ?? Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          if (label2.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    val2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: valColor2 ?? Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getRentalStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'rent_plan.status_new'.tr(context);
      case 'pending':
        return 'rent_plan.status_pending'.tr(context);
      case 'confirmed':
        return 'rent_plan.status_active'.tr(context);
      case 'masalah':
        return 'rent_plan.status_problem'.tr(context);
      case 'completed':
        return 'rent_plan.status_completed'.tr(context);
      default:
        return status.toUpperCase();
    }
  }

  Color _getRentalStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'confirmed':
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'masalah':
        return Colors.red;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCombinedControlCard() {
    final double progress =
        double.tryParse(_rentalData!['progress_day_calc']?.toString() ?? '0') ??
        0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: Radius.circular(_isExpanded ? 0 : 24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'rent_plan.rental_progress'.tr(context),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${value.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.grey[500],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: value / 100,
                              minHeight: 12,
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDateInfo(
                        'rent_plan.start'.tr(context),
                        _rentalData!['invoice_date'] ?? '-',
                        Icons.calendar_today_rounded,
                      ),
                      _buildDateInfo(
                        'rent_plan.end'.tr(context),
                        _rentalData!['tanggal_berakhir'] ?? '-',
                        Icons.event_available_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
                _buildStatusItem(
                  'rent_plan.payment_status'.tr(context),
                  _rentalData!['status_pembayaran'] == 'sudah'
                      ? 'rent_plan.paid'.tr(context)
                      : 'rent_plan.unpaid'.tr(context),
                  _rentalData!['status_pembayaran'] == 'sudah',
                  Icons.account_balance_wallet_rounded,
                  Colors.green,
                  (val) => _updateStatus(
                    'status_pembayaran',
                    val ? 'sudah' : 'belum',
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
                _buildStatusItem(
                  'rent_plan.fine_status'.tr(context),
                  _rentalData!['status_denda'] == 'yes'
                      ? 'rent_plan.fine'.tr(context)
                      : 'rent_plan.safe'.tr(context),
                  _rentalData!['status_denda'] == 'yes',
                  Icons.report_problem_rounded,
                  Colors.red,
                  (val) => _updateStatus('status_denda', val ? 'yes' : 'no'),
                ),
                Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
                _buildStatusItem(
                  'rent_plan.approval_status'.tr(context),
                  _rentalData!['status_approve'] == 'disetujui'
                      ? 'rent_plan.approved'.tr(context)
                      : 'rent_plan.pending'.tr(context),
                  _rentalData!['status_approve'] == 'disetujui',
                  Icons.verified_user_rounded,
                  Colors.blue,
                  (val) => _updateStatus(
                    'status_approve',
                    val ? 'disetujui' : 'pending',
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
                _buildMultiChoiceStatus(),
                const SizedBox(height: 8),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String date, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusItem(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    Color color,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: value ? color : Colors.grey[500],
                    fontWeight: value ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: color,
              activeTrackColor: color.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiChoiceStatus() {
    final String currentStatus = (_rentalData!['status'] ?? 'new')
        .toLowerCase();
    final List<Map<String, dynamic>> statusOptions = [
      {
        'val': 'new',
        'label': 'rent_plan.status_new'.tr(context),
        'icon': Icons.star_border_rounded,
        'color': Colors.blue,
      },
      {
        'val': 'pending',
        'label': 'rent_plan.status_pending'.tr(context),
        'icon': Icons.timer_outlined,
        'color': Colors.orange,
      },
      {
        'val': 'confirmed',
        'label': 'rent_plan.status_active'.tr(context),
        'icon': Icons.bolt_rounded,
        'color': Colors.green,
      },
      {
        'val': 'masalah',
        'label': 'rent_plan.status_problem'.tr(context),
        'icon': Icons.report_problem_outlined,
        'color': Colors.red,
      },
      {
        'val': 'completed',
        'label': 'rent_plan.status_completed'.tr(context),
        'icon': Icons.check_circle_outline_rounded,
        'color': Colors.purple,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text(
                'rent_plan.rental_status'.tr(context).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statusOptions.map((opt) {
              final bool isSelected = currentStatus == opt['val'];
              final Color color = opt['color'];

              return InkWell(
                onTap: () => _updateStatus('status', opt['val']),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.1)
                        : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt['icon'],
                        size: 14,
                        color: isSelected ? color : Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opt['label'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewDokumenTab() {
    if (_rentalData == null) return const SizedBox.shrink();

    final isPerusahaan =
        _rentalData!['jenis_sewa']?.toString().toLowerCase() == 'perusahaan';

    // BACKEND PROXY URL for GDrive
    const String proxyBaseUrl =
        '${AppConstants.baseUrl}/display_gdrive_file/';
    // FALLBACK URL for local files
    const String localBaseUrl = '${AppConstants.baseUrl}/uploads/rentals/';

    // Helper to get image URL (prefers Local Server over GDrive for stability)
    String getImgUrl(
      String? gdriveId,
      String? localFileName, {
      bool isJaminan = false,
    }) {
      // 1. Try local file first for stability
      if (localFileName != null && localFileName.isNotEmpty) {
        return '$localBaseUrl$localFileName';
      }
      // 2. Fallback to GDrive if local file name is not available
      if (gdriveId != null && gdriveId.isNotEmpty) {
        return '$proxyBaseUrl$gdriveId';
      }
      return '';
    }

    // List of docs to show
    List<Map<String, dynamic>> docsToShow = [];

    // 1. KTP (Always)
    docsToShow.add({
      'title': isPerusahaan
          ? 'rent_plan.leader_ktp'.tr(context)
          : 'rent_plan.customer_ktp'.tr(context),
      'url': getImgUrl(
        _rentalData!['gdrive_ktp_id'],
        isPerusahaan
            ? _rentalData!['file_ktp_pimpinan']
            : _rentalData!['file_ktp'],
      ),
    });

    if (isPerusahaan) {
      // 2. NPWP
      docsToShow.add({
        'title': 'rent_plan.company_npwp'.tr(context),
        'url': getImgUrl(
          _rentalData!['gdrive_npwp_id'],
          _rentalData!['file_npwp'],
        ),
      });
      // 3. PO
      docsToShow.add({
        'title': 'rent_plan.purchase_order'.tr(context),
        'url': getImgUrl(_rentalData!['gdrive_po_id'], _rentalData!['file_po']),
      });
      // 4. Domisili
      docsToShow.add({
        'title': 'rent_plan.domicile_file'.tr(context),
        'url': getImgUrl(
          _rentalData!['gdrive_domisili_id'],
          _rentalData!['domisili'],
        ),
      });
    }

    // 5. Jaminan (Dynamic labels)
    final List<dynamic> allJaminanList = isPerusahaan
        ? _jaminanPerusahaan
        : _jaminanPribadi;
    List<dynamic> savedJaminanIds = [];
    try {
      if (_rentalData!['jaminan_tambahan'] != null) {
        savedJaminanIds = json.decode(_rentalData!['jaminan_tambahan']);
      }
    } catch (_) {}

    final int jaminanCount = isPerusahaan ? 2 : 3;
    for (int i = 1; i <= jaminanCount; i++) {
      String label = '${'rent_plan.guarantee'.tr(context)} $i';
      // Try to find actual category name
      if (savedJaminanIds.length >= i) {
        final String? cid = savedJaminanIds[i - 1]?.toString();
        final match = allJaminanList.firstWhere(
          (j) => j['id']?.toString() == cid,
          orElse: () => null,
        );
        if (match != null) label = match['category_name']?.toString() ?? label;
      }

      docsToShow.add({
        'title': label,
        'url': getImgUrl(
          _rentalData!['gdrive_jaminan${i}_id'],
          _rentalData!['foto_jaminan$i'],
          isJaminan: true,
        ),
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          Icons.badge_rounded,
          'rent_plan.identity_docs'.tr(context),
        ),
        const SizedBox(height: 12),

        ...docsToShow.map(
          (doc) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDocumentTile(
              title: doc['title'],
              imageUrl: doc['url'],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTile({required String title, String? imageUrl}) {
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: hasImage ? () => _showImagePopup(imageUrl, title) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasImage
                    ? Colors.black.withOpacity(0.05)
                    : Colors.grey[isDark ? 800 : 100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImage
                    ? Hero(
                        tag: imageUrl,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.black.withOpacity(0.05),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.no_photography_outlined,
                        color: Colors.grey[400],
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!hasImage) ...[
                    const SizedBox(height: 4),
                    Text(
                      'rent_plan.not_available'.tr(context),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasImage)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fullscreen_rounded,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showImagePopup(String imageUrl, String title) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Zoomable Image
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Hero(
                    tag: imageUrl,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 64,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Top Bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () async {
                              final Uri url = Uri.parse(imageUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(scale: anim1, child: child),
        );
      },
    );
  }

  Widget _buildHutangTab() {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (_debtData == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 30),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.redAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'rent_plan.no_debt_data'.tr(context),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'rent_plan.debt_desc'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddDebtDialog,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(
                  'rent_plan.create_new_debt'.tr(context),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.redAccent.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final double total =
        double.tryParse(_debtData!['total_amount']?.toString() ?? '0') ?? 0;
    final double paid =
        double.tryParse(_debtData!['paid_amount']?.toString() ?? '0') ?? 0;
    final double remaining = total - paid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'rent_plan.debt_details'.tr(context),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        _buildDebtSummaryCard(
          'rent_plan.remaining_debt'.tr(context),
          currencyFormat.format(remaining),
          Colors.red[700]!,
          Icons.pending_actions_rounded,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDebtSummaryCard(
                'rent_plan.total_debt'.tr(context),
                currencyFormat.format(total),
                Colors.orange[800]!,
                Icons.account_balance_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDebtSummaryCard(
                'rent_plan.total_paid'.tr(context),
                currencyFormat.format(paid),
                Colors.green[700]!,
                Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(
              Icons.history_rounded,
              'rent_plan.installment_history'.tr(context),
            ),
            IconButton(
              onPressed: () => _confirmDeleteDebt(_debtData!['debt_id']),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
              tooltip: 'rent_plan.delete_debt'.tr(context),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_installments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('rent_plan.no_installments'.tr(context)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _installments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final inst = _installments[index];
              final status =
                  inst['status']?.toString().toLowerCase() ?? 'belum';
              Color statusColor = Colors.grey;
              IconData statusIcon = Icons.timer_outlined;
              String statusLabel = 'rent_plan.unpaid'.tr(context);

              if (status == 'lunas') {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
                statusLabel = 'rent_plan.paid'.tr(context);
              } else if (status == 'terlambat') {
                statusColor = Colors.red;
                statusIcon = Icons.warning_rounded;
                statusLabel = 'rent_plan.late'.tr(context);
              } else if (status == 'sebagian') {
                statusColor = Colors.orange;
                statusIcon = Icons.pending_rounded;
                statusLabel = 'rent_plan.partial'.tr(context);
              } else {
                statusLabel = 'rent_plan.unpaid'.tr(context);
              }

              return InkWell(
                onTap: status != 'lunas'
                    ? () => _showPayInstallmentDialog(inst)
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'rent_plan.installment'.tr(context)} #${inst['installment_no']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${'rent_plan.due_date'.tr(context)}: ${inst['due_date']}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(
                              double.tryParse(
                                    inst['amount']?.toString() ?? '0',
                                  ) ??
                                  0,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (status != 'lunas') ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDebtSummaryCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: isFullWidth
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.7),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDebtDialog() {
    final reasons = [
      'Tunggakan Sewa',
      'Kerusakan Laptop',
      'Denda Keterlambatan',
      'Lainnya',
    ];
    String selectedReason = reasons[0];
    final totalController = TextEditingController();
    final cicilanController = TextEditingController(text: '3');
    final tempoController = TextEditingController(text: '1');
    final mulaiController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final ketController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    List<Map<String, dynamic>> preview = [];

    void updatePreview() {
      double total = double.tryParse(totalController.text) ?? 0;
      int count = int.tryParse(cicilanController.text) ?? 0;
      int dueDay = int.tryParse(tempoController.text) ?? 1;
      DateTime start =
          DateTime.tryParse(mulaiController.text) ?? DateTime.now();

      if (total > 0 && count > 0) {
        preview = _calculateInstallmentsPreview(total, count, start, dueDay);
      } else {
        preview = [];
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'rent_plan.create_debt_data'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SearchableDropdown(
                    label: 'rent_plan.reason'.tr(context),
                    value: selectedReason,
                    options: reasons.map((r) => {'id': r, 'name': r}).toList(),
                    onSelected: (val) {
                      setDialogState(() => selectedReason = val);
                    },
                    placeholder: 'rent_plan.reason'.tr(context),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'rent_plan.total_amount'.tr(context),
                    controller: totalController,
                    icon: Icons.monetization_on_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() => updatePreview()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'rent_plan.installment_count'.tr(context),
                          controller: cicilanController,
                          icon: Icons.repeat_rounded,
                          keyboardType: TextInputType.number,
                          onChanged: (_) =>
                              setDialogState(() => updatePreview()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'rent_plan.day_interval'.tr(context),
                          controller: tempoController,
                          icon: Icons.calendar_today_rounded,
                          keyboardType: TextInputType.number,
                          onChanged: (_) =>
                              setDialogState(() => updatePreview()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setDialogState(
                          () => mulaiController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(date),
                        );
                        setDialogState(() => updatePreview());
                      }
                    },
                    child: _buildTextField(
                      'rent_plan.start_date'.tr(context),
                      controller: mulaiController,
                      enabled: false,
                      icon: Icons.event_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'rent_plan.notes'.tr(context),
                    controller: ketController,
                    maxLines: 2,
                    icon: Icons.notes_rounded,
                    isRequired: false,
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'rent_plan.installment_preview'.tr(context),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...preview
                        .take(3)
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${'rent_plan.installment'.tr(context)} #${p['no']} (${p['due_date']})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(p['amount']),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (preview.length > 3)
                      Text(
                        '... + ${preview.length - 3} ${'rent_plan.more'.tr(context)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        final res = await _rentPlanService.saveDebt({
                          'rental_id': widget.rentalId.toString(),
                          'reason': selectedReason,
                          'total_amount': totalController.text,
                          'jumlah_cicilan': cicilanController.text,
                          'jatuh_tempo_tgl': tempoController.text,
                          'mulai_cicilan': mulaiController.text,
                          'keterangan': ketController.text,
                        });
                        if (res['status'] == true) {
                          _fetchDetail();
                        } else {
                          setState(() => _isLoading = false);
                          context.showErrorSnackBar(
                            res['message'] ??
                                'rent_plan.failed_save'.tr(context),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'rent_plan.save_debt'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _calculateInstallmentsPreview(
    double total,
    int count,
    DateTime start,
    int dueDay,
  ) {
    List<Map<String, dynamic>> preview = [];
    if (count <= 0) return preview;

    double perCicilan = (total / count).floorToDouble();
    double sisaBeda = total - (perCicilan * count);

    for (int i = 1; i <= count; i++) {
      DateTime dueBase = DateTime(start.year, start.month + (i - 1));
      int lastDayOfMonth = DateTime(dueBase.year, dueBase.month + 1, 0).day;
      DateTime due = DateTime(
        dueBase.year,
        dueBase.month,
        dueDay > lastDayOfMonth ? lastDayOfMonth : dueDay,
      );

      double amount = (i == count) ? (perCicilan + sisaBeda) : perCicilan;

      preview.add({
        'no': i,
        'due_date': DateFormat('yyyy-MM-dd').format(due),
        'amount': amount,
      });
    }
    return preview;
  }

  void _showPayInstallmentDialog(dynamic installment) {
    final double totalAmount =
        double.tryParse(installment['amount']?.toString() ?? '0') ?? 0;
    final double paidAmount =
        double.tryParse(installment['paid_amount']?.toString() ?? '0') ?? 0;
    final double remainingAmount = totalAmount - paidAmount;

    final noteController = TextEditingController();
    final amountController = TextEditingController(
      text: remainingAmount.toStringAsFixed(0),
    );
    File? proofFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double inputAmount =
              double.tryParse(amountController.text) ?? 0;
          final bool isFullPayment = inputAmount >= remainingAmount;
          final double diff = remainingAmount - inputAmount;

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final Color inputBg = isDark
              ? Colors.white.withOpacity(0.05)
              : (Colors.grey[50] ?? Colors.grey);
          final Color borderColor = isDark
              ? Colors.white.withOpacity(0.1)
              : (Colors.grey[300] ?? Colors.grey);
          final Color textColor =
              Theme.of(context).textTheme.bodyLarge?.color ??
              (isDark ? Colors.white : Colors.black87);
          final Color subTextColor = isDark
              ? Colors.white70
              : (Colors.grey[600] ?? Colors.grey);

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: const Color(0xFF00C853),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.assignment_turned_in_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'rent_plan.payment_confirmation'.tr(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    left: 20,
                    right: 20,
                    top: 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  'rent_plan.installment_count_label'.tr(
                                    context,
                                  ),
                                  installment['installment_no'].toString(),
                                  isDark: isDark,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: borderColor.withOpacity(0.3),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryItem(
                                  'rent_plan.total_installment'.tr(context),
                                  NumberFormat.currency(
                                    locale: 'id_ID',
                                    symbol: 'Rp ',
                                    decimalDigits: 0,
                                  ).format(totalAmount),
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 30,
                                color: borderColor.withOpacity(0.3),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryItem(
                                  'rent_plan.remaining_to_pay'.tr(context),
                                  NumberFormat.currency(
                                    locale: 'id_ID',
                                    symbol: 'Rp ',
                                    decimalDigits: 0,
                                  ).format(remainingAmount),
                                  valueColor: Colors.red,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          'rent_plan.amount_to_pay_now'.tr(context),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: subTextColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textColor,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBg,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.grey[200],
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Rp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minHeight: 54,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF00C853),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            final double input = double.tryParse(val) ?? 0;
                            if (input > remainingAmount) {
                              amountController.text = remainingAmount
                                  .toStringAsFixed(0);
                              amountController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: amountController.text.length,
                                    ),
                                  );
                            }
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            _buildQuickButton(
                              'rent_plan.pay_full'.tr(context),
                              Icons.check_circle_outline_rounded,
                              () {
                                setDialogState(() {
                                  amountController.text = remainingAmount
                                      .toStringAsFixed(0);
                                });
                              },
                              const Color(0xFF00C853),
                            ),
                            const SizedBox(width: 10),
                            _buildQuickButton(
                              'rent_plan.half_of_remaining'.tr(context),
                              Icons.pie_chart_outline_rounded,
                              () {
                                setDialogState(() {
                                  amountController.text = (remainingAmount / 2)
                                      .toStringAsFixed(0);
                                });
                              },
                              Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isFullPayment
                                ? (isDark
                                      ? Colors.green.withOpacity(0.1)
                                      : const Color(0xFFE8F5E9))
                                : (isDark
                                      ? Colors.blue.withOpacity(0.1)
                                      : const Color(0xFFE3F2FD)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFullPayment
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isFullPayment
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                color: isFullPayment
                                    ? Colors.green
                                    : Colors.blue,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isFullPayment
                                      ? 'rent_plan.installment_will_be_paid'.tr(
                                          context,
                                        )
                                      : '${'rent_plan.pay_partial'.tr(context)}... ${'rent_plan.remaining'.tr(context)} Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(diff)} ${'rent_plan.auto_scheduled_next_month'.tr(context)}.',
                                  style: TextStyle(
                                    color: isFullPayment
                                        ? (isDark
                                              ? Colors.green[300]
                                              : Colors.green[800])
                                        : (isDark
                                              ? Colors.blue[300]
                                              : Colors.blue[800]),
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          'rent_plan.payment_proof_required'.tr(context),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: subTextColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles();
                            if (result != null) {
                              setDialogState(() {
                                proofFile = File(result.files.single.path!);
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: inputBg,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      proofFile?.path.split('/').last ??
                                          'rent_plan.select_payment_proof'.tr(
                                            context,
                                          ),
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.grey[100],
                                    border: Border(
                                      left: BorderSide(color: borderColor),
                                    ),
                                  ),
                                  child: Text(
                                    'Browse',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'rent_plan.notes'.tr(context).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: subTextColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteController,
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'rent_plan.payment_note_hint'.tr(context),
                            hintStyle: TextStyle(
                              color: subTextColor.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF00C853),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  'BATAL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: subTextColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (proofFile == null) {
                                    context.showWarningSnackBar(
                                      'rent_plan.upload_proof_error'.tr(
                                        context,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  setState(() => _isLoading = true);
                                  final res = await _rentPlanService
                                      .payInstallment(
                                        int.parse(
                                          installment['installment_id']
                                              .toString(),
                                        ),
                                        double.parse(amountController.text),
                                        noteController.text,
                                        proofFile,
                                      );
                                  if (res['status'] == true) {
                                    _fetchDetail();
                                  } else {
                                    setState(() => _isLoading = false);
                                    context.showErrorSnackBar(
                                      res['message'] ??
                                          'rent_plan.failed_payment'.tr(
                                            context,
                                          ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, size: 20),
                                label: Text(
                                  'main.confirm'.tr(context).toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C853),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value, {
    Color? valueColor,
    bool isDark = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: isDark ? Colors.white54 : Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: color.withOpacity(0.05),
        ),
      ),
    );
  }

  void _confirmDeleteDebt(dynamic debtId) {
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
                color: Colors.grey.withOpacity(0.3),
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
              'rent_plan.confirm_delete'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'rent_plan.delete_debt_confirm'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      final res = await _rentPlanService.deleteDebt(
                        int.parse(debtId.toString()),
                      );
                      if (res['status'] == true) {
                        _fetchDetail();
                      } else {
                        setState(() => _isLoading = false);
                        context.showErrorSnackBar(
                          res['message'] ??
                              'rent_plan.failed_delete'.tr(context),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text('main.delete'.tr(context)),
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
}
