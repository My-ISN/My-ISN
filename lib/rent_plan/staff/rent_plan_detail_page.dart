import 'package:flutter/material.dart';
import '../../services/rent_plan_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;


class RentPlanDetailPage extends StatefulWidget {
  final int rentalId;
  final String? invoiceNumber;
  const RentPlanDetailPage({super.key, required this.rentalId, this.invoiceNumber});

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
  final _lamaSewaController = TextEditingController();
  final _totalLaptopController = TextEditingController();
  final _notesController = TextEditingController();
  final _alamatKtpController = TextEditingController();
  final _alamatDomisiliController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _tanggalBerakhirController = TextEditingController();

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
  Map<int, File?> _fileJaminan = {1: null, 2: null, 3: null};
  Map<int, String?> _selectedJaminanIds = {1: null, 2: null, 3: null};
  List<dynamic> _jaminanPribadi = [];
  List<dynamic> _jaminanPerusahaan = [];

  final List<String> _menuTabs = [
    'OVERVIEW', 'EDIT', 'RENTAL EXTEND', 'INVOICE', 'VIEW DOKUMEN', 
    'PERJANJIAN SEWA', 'SP-1', 'SP-3 / SOMASI', 'HUTANG'
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal mengambil detail')),
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
        if (key == 0) _fileKtp = File(result.files.single.path!);
        else if (key is int) _fileJaminan[key] = File(result.files.single.path!);
        else if (key == 'npwp') _fileNpwp = File(result.files.single.path!);
        else if (key == 'po') _filePo = File(result.files.single.path!);
        else if (key == 'ktp_pimpinan') _fileKtpPimpinan = File(result.files.single.path!);
        else if (key == 'domisili') _fileDomisiliPerusahaan = File(result.files.single.path!);
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
              .where((j) => j['category_name'].toString().toUpperCase() != 'KTP').toList();
          _jaminanPerusahaan = List<dynamic>.from(data['jaminan_perusahaan'] ?? [])
              .where((j) => j['category_name'].toString().toUpperCase() != 'KTP').toList();
          _shippingCosts = List<dynamic>.from(data['shipping_costs'] ?? []);
          
          // Retry matching shipping if _rentalData is already loaded
          if (_rentalData != null && _rentalData!['tipe_pengiriman'] != null) {
            String tp = _rentalData!['tipe_pengiriman'].toString();
            final match = _shippingCosts.firstWhere(
              (s) => s['nama_kirim']?.toString().toLowerCase().trim() == tp.toLowerCase().trim(),
              orElse: () => null,
            );
            if (match != null) {
              _selectedShippingId = match['nama_kirim']?.toString();
            } else {
              _selectedShippingId = tp;
            }
          }
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
        (p) => p['name']?.toString().toLowerCase() == _selectedProvinceKtp!.toLowerCase(),
        orElse: () => null,
      );
      if (pObj != null) {
        final res = await _rentPlanService.getRegencies(pObj['id'].toString());
        final regencies = List<dynamic>.from(res['data'] ?? []);
        if (mounted) setState(() => _regenciesKtp = regencies);

        if (_selectedRegencyKtp != null && _selectedRegencyKtp!.isNotEmpty) {
          final rObj = regencies.firstWhere(
            (r) => r['name']?.toString().toLowerCase() == _selectedRegencyKtp!.toLowerCase(),
            orElse: () => null,
          );
          if (rObj != null) {
            final res2 = await _rentPlanService.getDistricts(rObj['id'].toString());
            final districts = List<dynamic>.from(res2['data'] ?? []);
            if (mounted) setState(() => _districtsKtp = districts);

            if (_selectedDistrictKtp != null && _selectedDistrictKtp!.isNotEmpty) {
              final dObj = districts.firstWhere(
                (d) => d['name']?.toString().toLowerCase() == _selectedDistrictKtp!.toLowerCase(),
                orElse: () => null,
              );
              if (dObj != null) {
                final res3 = await _rentPlanService.getVillages(dObj['id'].toString());
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
        (p) => p['name']?.toString().toLowerCase() == _selectedProvinceCur!.toLowerCase(),
        orElse: () => null,
      );
      if (pObj != null) {
        final res = await _rentPlanService.getRegencies(pObj['id'].toString());
        final regencies = List<dynamic>.from(res['data'] ?? []);
        if (mounted) setState(() => _regenciesCur = regencies);

        if (_selectedRegencyCur != null && _selectedRegencyCur!.isNotEmpty) {
          final rObj = regencies.firstWhere(
            (r) => r['name']?.toString().toLowerCase() == _selectedRegencyCur!.toLowerCase(),
            orElse: () => null,
          );
          if (rObj != null) {
            final res2 = await _rentPlanService.getDistricts(rObj['id'].toString());
            final districts = List<dynamic>.from(res2['data'] ?? []);
            if (mounted) setState(() => _districtsCur = districts);

            if (_selectedDistrictCur != null && _selectedDistrictCur!.isNotEmpty) {
              final dObj = districts.firstWhere(
                (d) => d['name']?.toString().toLowerCase() == _selectedDistrictCur!.toLowerCase(),
                orElse: () => null,
              );
              if (dObj != null) {
                final res3 = await _rentPlanService.getVillages(dObj['id'].toString());
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mohon tunggu sebentar...'), duration: Duration(seconds: 1)),
        );
        return;
      }
    }
    _lastUpdateTimes[field] = now;

    // Optimistic UI: Update state secara lokal dulu
    final originalValue = _rentalData![field];
    setState(() {
      _rentalData![field] = value;
    });

    final response = await _rentPlanService.updateRentPlanStatus(widget.rentalId, field, value);
    if (response['status'] == true) {
      // Refresh data di background untuk memastikan sinkronisasi
      _fetchDetail(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status berhasil diperbarui'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
        );
      }
    } else {
      // Rollback jika gagal
      setState(() {
        _rentalData![field] = originalValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal memperbarui status'), backgroundColor: Colors.red),
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
    _lamaSewaController.text = (_rentalData!['lama_sewa'] ?? '0').toString();
    _totalLaptopController.text = (_rentalData!['total_laptop'] ?? '0').toString();
    _notesController.text = _rentalData!['notes'] ?? '';
    _invoiceDateController.text = _rentalData!['invoice_date'] ?? '';
    _tanggalBerakhirController.text = _rentalData!['tanggal_berakhir'] ?? '';

    setState(() {
      _jenisSewa = (_rentalData!['jenis_sewa'] ?? 'pribadi').toString().toLowerCase();
      
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
          final List<dynamic> jIds = json.decode(_rentalData!['jaminan_tambahan']);
          for (int i = 0; i < jIds.length; i++) {
            if (i < 3) _selectedJaminanIds[i + 1] = jIds[i]?.toString();
          }
        } catch (_) {}
      }
      
      _tipePengiriman = _rentalData!['tipe_pengiriman']?.toString() ?? '';
      
      // Match shipping id case-insensitively
      if (_shippingCosts.isNotEmpty && _tipePengiriman.isNotEmpty) {
        final match = _shippingCosts.firstWhere(
          (s) => s['nama_kirim']?.toString().toLowerCase().trim() == _tipePengiriman.toLowerCase().trim(),
          orElse: () => null,
        );
        if (match != null) {
          _selectedShippingId = match['nama_kirim']?.toString();
        } else {
          _selectedShippingId = _tipePengiriman;
        }
      } else {
        _selectedShippingId = _tipePengiriman.isNotEmpty ? _tipePengiriman : null;
      }
    });
  }

  Widget _buildSection({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : color.withOpacity(0.1), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))],
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
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
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

  Widget _buildTextField(String label, {TextEditingController? controller, bool enabled = true, TextInputType? keyboardType, Function(String)? onChanged, int maxLines = 1, IconData? icon, String? suffix, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      validator: isRequired ? (val) => val == null || val.isEmpty ? 'Wajib diisi' : null : null,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey[400]) : null,
        suffixText: suffix,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<DropdownMenuItem<String>> items, Function(String?) onChanged, {String? hint, bool isLoading = false}) {
    final Map<String, DropdownMenuItem<String>> uniqueItemsMap = {};
    for (var item in items) {
      if (item.value != null && !uniqueItemsMap.containsKey(item.value)) {
        uniqueItemsMap[item.value!] = item;
      }
    }
    final List<DropdownMenuItem<String>> uniqueItems = uniqueItemsMap.values.toList();

    return DropdownButtonFormField<String>(
      value: (uniqueItems.any((item) => item.value == value)) ? value : null,
      items: uniqueItems.isEmpty ? null : uniqueItems,
      onChanged: isLoading ? null : onChanged,
      isExpanded: true,
      hint: Text(isLoading ? 'Sedang memuat...' : (hint ?? 'Pilih $label'), 
          style: TextStyle(fontSize: 13, color: Colors.grey[400]), overflow: TextOverflow.ellipsis),
      decoration: InputDecoration(
        labelText: value == null ? null : label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Theme.of(context).dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      icon: Icon(Icons.arrow_drop_down_rounded, color: Theme.of(context).colorScheme.primary),
    );
  }

  Widget _buildFileUploadTile(String label, File? file, VoidCallback onTap, {IconData? icon, String? existingUrl}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool hasFile = file != null || (existingUrl != null && existingUrl.isNotEmpty);
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !hasFile ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]) : Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: !hasFile ? (isDark ? Colors.white12 : Theme.of(context).dividerColor) : Colors.green[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: !hasFile ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon ?? Icons.attach_file_rounded, color: !hasFile ? Colors.blue : Colors.green, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(file != null ? file.path.split('/').last : (existingUrl != null && existingUrl.isNotEmpty ? 'File tersimpan' : 'Ketuk untuk pilih file'), 
                    style: TextStyle(fontSize: 12, color: !hasFile ? Colors.grey[500] : Colors.green[700])),
                ],
              ),
            ),
            if (hasFile) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
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
      'jaminan_ids': json.encode(_selectedJaminanIds.values.where((v) => v != null).toList()),
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
    if (_fileKtp != null) files.add(await http.MultipartFile.fromPath('file_ktp', _fileKtp!.path));
    if (_fileNpwp != null) files.add(await http.MultipartFile.fromPath('file_npwp', _fileNpwp!.path));
    if (_filePo != null) files.add(await http.MultipartFile.fromPath('file_po', _filePo!.path));
    if (_fileKtpPimpinan != null) files.add(await http.MultipartFile.fromPath('file_ktp_pimpinan', _fileKtpPimpinan!.path));
    if (_fileDomisiliPerusahaan != null) files.add(await http.MultipartFile.fromPath('file_domisili_perusahaan', _fileDomisiliPerusahaan!.path));
    
    for (int i = 1; i <= 3; i++) {
      if (_fileJaminan[i] != null) {
        files.add(await http.MultipartFile.fromPath('file_jaminan_$i', _fileJaminan[i]!.path));
      }
    }

    final response = await _rentPlanService.updateRentPlanDetail(widget.rentalId, updateData, files: files);
    
    setState(() => _isSaving = false);

    if (response['status'] == true) {
      _fetchDetail(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detail berhasil diperbarui'), backgroundColor: Colors.green),
        );
        setState(() => _activeTab = 'OVERVIEW');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal memperbarui detail'), backgroundColor: Colors.red),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.invoiceNumber ?? 'Detail Rental', style: const TextStyle(fontSize: 16))),
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_rentalData == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.invoiceNumber ?? 'Detail Rental', style: const TextStyle(fontSize: 16))),
        body: const Center(child: Text('Data tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_rentalData!['invoice_number'] ?? widget.invoiceNumber ?? 'Detail Rental', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
      child: Row(
        children: _menuTabs.map((tab) {
          final bool isActive = _activeTab == tab;
          final bool isHutang = tab == 'HUTANG';
          final bool hasDebt = _debtData != null;
          final Color? debtColor = (isHutang && hasDebt) ? Colors.red : null;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () async {
                if (['INVOICE', 'PERJANJIAN SEWA', 'SP-1', 'SP-3 / SOMASI'].contains(tab)) {
                  _launchDocumentUrl(tab);
                } else {
                  setState(() => _activeTab = tab);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: debtColor != null
                    ? (isActive ? debtColor : debtColor.withOpacity(0.1))
                    : (isActive ? _primaryColor : Theme.of(context).cardColor),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: debtColor ?? (isActive ? _primaryColor : Theme.of(context).dividerColor.withOpacity(0.1))
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? Colors.white : (debtColor ?? Colors.grey[500]),
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

  Future<void> _launchDocumentUrl(String tab) async {
    String endpoint = '';
    switch (tab) {
      case 'INVOICE':
        endpoint = 'invoice';
        break;
      case 'VIEW DOKUMEN':
        endpoint = 'ktp';
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

    final String secret = '${widget.rentalId}foxgeen_mobile_invoice_secret_2024';
    final String token = md5.convert(utf8.encode(secret)).toString();
    final url = Uri.parse('https://foxgeen.com/HRIS/erp/rentals/$endpoint/${widget.rentalId}?token=$token');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka ${tab.toLowerCase()}')),
        );
      }
    }
  }

  Widget _buildActiveTabContent() {
    if (_activeTab == 'EDIT') return _buildEditTab();
    if (_activeTab == 'VIEW DOKUMEN') return _buildViewDokumenTab();
    if (_activeTab == 'OVERVIEW') return _buildOverviewTab();
    if (_activeTab == 'HUTANG') return _buildHutangTab();
    return _buildPlaceholderTab();
  }

  Widget _buildEditTab() {
    return Column(
      children: [
        _buildSection(
          title: 'Data Penyewa',
          icon: Icons.person_rounded,
          color: _primaryColor,
          children: [
            _buildTipePenyewaToggle(),
            const SizedBox(height: 16),
            if (_jenisSewa == 'pribadi') ...[
              _buildTextField('NAMA LENGKAP', controller: _namaPribadiController, icon: Icons.badge_rounded),
              const SizedBox(height: 16),
              _buildTextField('NIK', controller: _nikPribadiController, icon: Icons.credit_card_rounded, keyboardType: TextInputType.number),
            ] else ...[
              _buildTextField('NAMA PERUSAHAAN', controller: _namaPerusahaanController, icon: Icons.business_rounded),
              const SizedBox(height: 16),
              _buildTextField('NOMOR NPWP', controller: _npwpController, icon: Icons.description_rounded),
            ],
            const SizedBox(height: 16),
            _buildTextField('WHATSAPP', controller: _whatsappController, icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Alamat KTP',
          icon: Icons.assignment_ind_rounded,
          color: Colors.indigo[700]!,
          children: [_buildRegionDropdowns(true)],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Alamat Domisili / Instansi',
          icon: Icons.home_rounded,
          color: Colors.teal[700]!,
          children: [_buildRegionDropdowns(false)],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Dokumen & Jaminan',
          icon: Icons.verified_user_rounded,
          color: Colors.deepPurple[700]!,
          children: [
            if (_jenisSewa == 'pribadi') ...[
              _buildFileUploadTile('KTP Pelanggan', _fileKtp, () => _pickFile(0), icon: Icons.camera_alt_rounded, existingUrl: _rentalData!['file_ktp']),
              const Divider(height: 32),
            ] else ...[
              _buildFileUploadTile('Upload NPWP', _fileNpwp, () => _pickFile('npwp'), icon: Icons.upload_file_rounded, existingUrl: _rentalData!['file_npwp']),
              const SizedBox(height: 12),
              _buildFileUploadTile('Upload PO', _filePo, () => _pickFile('po'), icon: Icons.upload_file_rounded, existingUrl: _rentalData!['file_po']),
              const SizedBox(height: 12),
              _buildFileUploadTile('Upload KTP Pimpinan', _fileKtpPimpinan, () => _pickFile('ktp_pimpinan'), icon: Icons.upload_file_rounded, existingUrl: _rentalData!['file_ktp_pimpinan']),
              const SizedBox(height: 12),
              _buildFileUploadTile('Domisili Perusahaan', _fileDomisiliPerusahaan, () => _pickFile('domisili'), icon: Icons.upload_file_rounded, existingUrl: _rentalData!['domisili']),
              const Divider(height: 32),
            ],
            Text('Jaminan (Wajib ${_jenisSewa == 'pribadi' ? 3 : 2})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            for (int i = 1; i <= (_jenisSewa == 'pribadi' ? 3 : 2); i++) ...[
              _buildJaminanSelector(i),
              if (i < (_jenisSewa == 'pribadi' ? 3 : 2)) const SizedBox(height: 12),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Detail Sewa',
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
                        initialDate: DateTime.tryParse(_invoiceDateController.text) ?? DateTime.now(), 
                        firstDate: DateTime(2000), 
                        lastDate: DateTime(2100)
                      );
                      if (date != null) {
                        setState(() => _invoiceDateController.text = DateFormat('yyyy-MM-dd').format(date));
                      }
                    },
                    child: _buildTextField('TANGGAL MULAI', controller: _invoiceDateController, enabled: false, icon: Icons.event_available_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('LAMA SEWA', controller: _lamaSewaController, suffix: 'Hari', keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('JUMLAH UNIT', controller: _totalLaptopController, icon: Icons.laptop_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _buildDropdown('Tipe Pengiriman', _selectedShippingId, _shippingCosts.map((s) => DropdownMenuItem(
              value: s['nama_kirim']?.toString() ?? '', 
              child: Text(s['nama_kirim']?.toString() ?? '-', overflow: TextOverflow.ellipsis)
            )).toList(), (val) {
              setState(() => _selectedShippingId = val);
            }, hint: 'Pilih Tipe Pengiriman'),
            const SizedBox(height: 16),
            _buildTextField('CATATAN', controller: _notesController, maxLines: 3, icon: Icons.notes_rounded, isRequired: false),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isSaving
              ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 12), Text('MENYIMPAN...', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))])
              : const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.save_rounded), SizedBox(width: 8), Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))]),
          ),
        ),
      ],
    );
  }

  Widget _buildTipePenyewaToggle() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleItem('Pribadi', _jenisSewa == 'pribadi', () => setState(() {
            _jenisSewa = 'pribadi';
          })),
          _buildToggleItem('Perusahaan', _jenisSewa == 'perusahaan', () => setState(() {
            _jenisSewa = 'perusahaan';
            _selectedJaminanIds[3] = null;
            _fileJaminan[3] = null;
          })),
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
            color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _primaryColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600]))),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionDropdowns(bool isKtp) {
    return Column(
      children: [
        _buildDropdown('Provinsi', isKtp ? _selectedProvinceKtp : _selectedProvinceCur, _provinces.map((p) => DropdownMenuItem(
          value: p['name'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) {
              setState(() { if (isKtp) _selectedProvinceKtp = val; else _selectedProvinceCur = val; });
              final pObj = _provinces.firstWhere((p) => p['name'] == val, orElse: () => null);
              if (pObj != null) _loadRegencies(pObj['id'].toString(), isKtp);
            }
        }, hint: 'Pilih Provinsi'),
        const SizedBox(height: 12),
        _buildDropdown('Kabupaten', isKtp ? _selectedRegencyKtp : _selectedRegencyCur, (isKtp ? _regenciesKtp : _regenciesCur).map((p) => DropdownMenuItem(
          value: p['name'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) {
              setState(() { if (isKtp) _selectedRegencyKtp = val; else _selectedRegencyCur = val; });
              final rObj = (isKtp ? _regenciesKtp : _regenciesCur).firstWhere((r) => r['name'] == val, orElse: () => null);
              if (rObj != null) _loadDistricts(rObj['id'].toString(), isKtp);
            }
        }, hint: 'Pilih Kabupaten', isLoading: isKtp ? _isLoadingRegKtp : _isLoadingRegCur),
        const SizedBox(height: 12),
        _buildDropdown('Kecamatan', isKtp ? _selectedDistrictKtp : _selectedDistrictCur, (isKtp ? _districtsKtp : _districtsCur).map((p) => DropdownMenuItem(
          value: p['name'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) {
              setState(() { if (isKtp) _selectedDistrictKtp = val; else _selectedDistrictCur = val; });
              final dObj = (isKtp ? _districtsKtp : _districtsCur).firstWhere((d) => d['name'] == val, orElse: () => null);
              if (dObj != null) _loadVillages(dObj['id'].toString(), isKtp);
            }
        }, hint: 'Pilih Kecamatan', isLoading: isKtp ? _isLoadingDistKtp : _isLoadingDistCur),
        const SizedBox(height: 12),
        _buildDropdown('Desa', isKtp ? _selectedVillageKtp : _selectedVillageCur, (isKtp ? _villagesKtp : _villagesCur).map((p) => DropdownMenuItem(
          value: p['name'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) setState(() { if (isKtp) _selectedVillageKtp = val; else _selectedVillageCur = val; });
        }, hint: 'Pilih Desa', isLoading: isKtp ? _isLoadingVillKtp : _isLoadingVillCur),
      ],
    );
  }

  Widget _buildJaminanSelector(int index) {
    List<dynamic> baseOptions = _jenisSewa == 'pribadi' ? _jaminanPribadi : _jaminanPerusahaan;
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
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _primaryColor.withOpacity(0.1))),
      child: Column(
        children: [
          _buildDropdown('Jaminan $index', _selectedJaminanIds[index], availableOptions.map((j) => DropdownMenuItem(
            value: j['constants_id'].toString(), child: Text(j['category_name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
              setState(() { _selectedJaminanIds[index] = val; });
          }, hint: 'Pilih Jaminan $index'),
          if (_selectedJaminanIds[index] != null) ...[
            const SizedBox(height: 12),
            _buildFileUploadTile('File Jaminan $index', _fileJaminan[index], () => _pickFile(index), icon: Icons.upload_file_rounded, existingUrl: _rentalData!['foto_jaminan$index']),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isPerusahaan = _rentalData!['jenis_sewa']?.toString().toLowerCase() == 'perusahaan';

    return Column(
      children: [
        // 1. Identitas Penyewa
        _buildSectionTitle(Icons.person_pin_rounded, 'IDENTITAS PENYEWA'),
        _buildOverviewCard([
          _buildRowTwoFields(
            isPerusahaan ? 'NAMA PERUSAHAAN' : 'NAMA PELANGGAN', 
            _rentalData!['first_name'] ?? _rentalData!['nama_pribadi'] ?? _rentalData!['nama_perusahaan'] ?? '-',
            isPerusahaan ? 'NPWP' : 'NIK', 
            _rentalData!['npwp'] ?? _rentalData!['nik'] ?? '-'
          ),
          _buildRowTwoFields(
            'WHATSAPP', 
            _rentalData!['whatsapp'] ?? _rentalData!['renter_contact'] ?? '-',
            '', ''
          ),
          _buildRowTwoFields(
            'ALAMAT KTP', 
            _rentalData!['alamat_ktp_formatted'] ?? _rentalData!['alamat_ktp'] ?? '-',
            'ALAMAT DOMISILI', 
            _rentalData!['alamat_current_formatted'] ?? _rentalData!['alamat_domisili'] ?? _rentalData!['alamat_instansi'] ?? '-'
          ),
        ]),

        const SizedBox(height: 20),

        // 2. Detail Sewa
        _buildSectionTitle(Icons.laptop_rounded, 'DETAIL SEWA'),
        _buildOverviewCard([
          _buildRowTwoFields(
            'LAPTOP', 
            _rentalData!['nama_laptop'] ?? _rentalData!['laptop_name'] ?? _rentalData!['item_name'] ?? '-',
            'INVOICE NUMBER', 
            _rentalData!['invoice_number'] ?? '-'
          ),
          _buildRowTwoFields(
            'JENIS PENYEWA', 
            (_rentalData!['jenis_sewa']?.toString() ?? '-').toUpperCase(),
            'TANGGAL MULAI', 
            _rentalData!['invoice_date'] ?? '-'
          ),
          _buildRowTwoFields(
            'TANGGAL SELESAI', 
            _rentalData!['tanggal_berakhir'] ?? '-',
            'JUMLAH UNIT', 
            '${_rentalData!['total_laptop'] ?? 0} unit'
          ),
          _buildRowTwoFields(
            'DURASI', 
            '${_rentalData!['lama_sewa'] ?? 0} hari',
            '', ''
          ),
        ]),

        const SizedBox(height: 20),

          // 3. Harga & Status
        _buildSectionTitle(Icons.monetization_on_rounded, 'HARGA & STATUS'),
        _buildOverviewCard([
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _rentalData!['status_pembayaran'] == 'sudah'
                  ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.05)]
                  : [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _rentalData!['status_pembayaran'] == 'sudah'
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2)
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL BIAYA', 
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Text(currencyFormat.format(double.tryParse(_rentalData!['grand_total']?.toString() ?? '0') ?? 0), 
                      style: TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.w900, 
                        color: _rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.red,
                        letterSpacing: -0.5,
                      )),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.red).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _rentalData!['status_pembayaran'] == 'sudah' ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: _rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          _buildRowTwoFields(
            'STATUS PEMBAYARAN', 
            _rentalData!['status_pembayaran'] == 'sudah' ? 'Lunas' : 'Belum Bayar',
            'STATUS DENDA', 
            _rentalData!['status_denda'] == 'yes' ? 'Denda' : 'Aman',
            valColor1: _rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.orange,
            valColor2: _rentalData!['status_denda'] == 'yes' ? Colors.red : Colors.green
          ),
          _buildRowTwoFields(
            'STATUS APPROVAL', 
            (_rentalData!['status_approve'] ?? '-').toUpperCase(),
            'STATUS RENTAL', 
            _getRentalStatusLabel(_rentalData!['status'] ?? '-'),
            valColor1: _rentalData!['status_approve'] == 'disetujui' ? Colors.green : Colors.orange,
            valColor2: _getRentalStatusColor(_rentalData!['status'] ?? '')
          ),
        ]),
      ],
    );
  }

  Widget _buildPlaceholderTab() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.construction_rounded, size: 64, color: Theme.of(context).dividerColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('Konten Tab $_activeTab sedang dalam pengembangan', 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _primaryColor)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
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
          Icon(icon, size: 18, color: _primaryColor),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRowTwoFields(String label1, String val1, String label2, String val2, {Color? valColor1, Color? valColor2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label1, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(val1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valColor1)),
              ],
            ),
          ),
          if (label2.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label2, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(val2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valColor2)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getRentalStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new': return 'New';
      case 'pending': return 'Pending';
      case 'confirmed': return 'Aktif';
      case 'masalah': return 'Masalah';
      case 'completed': return 'Selesai';
      default: return status.toUpperCase();
    }
  }

  Color _getRentalStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new': return Colors.blue;
      case 'confirmed':
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'masalah': return Colors.red;
      case 'completed': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Widget _buildCombinedControlCard() {
    final double progress = double.tryParse(_rentalData!['progress_day_calc']?.toString() ?? '0') ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(top: const Radius.circular(20), bottom: Radius.circular(_isExpanded ? 0 : 20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progres Masa Sewa', 
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                      Row(
                        children: [
                          Text('${progress.toStringAsFixed(0)}%', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
                          const SizedBox(width: 8),
                          Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, 
                            color: Colors.grey[500]),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 12,
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDateInfo('Mulai', _rentalData!['invoice_date'] ?? '-'),
                      _buildDateInfo('Berakhir', _rentalData!['tanggal_berakhir'] ?? '-'),
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
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildStatusItem(
                  'Status Pembayaran', 
                  _rentalData!['status_pembayaran'] == 'sudah' ? 'Lunas' : 'Belum Bayar',
                  _rentalData!['status_pembayaran'] == 'sudah',
                  Icons.account_balance_wallet_rounded,
                  Colors.green,
                  (val) => _updateStatus('status_pembayaran', val ? 'sudah' : 'belum')
                ),
                Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildStatusItem(
                  'Status Denda', 
                  _rentalData!['status_denda'] == 'yes' ? 'Kena Denda' : 'Aman',
                  _rentalData!['status_denda'] == 'yes',
                  Icons.report_problem_rounded,
                  Colors.red,
                  (val) => _updateStatus('status_denda', val ? 'yes' : 'no')
                ),
                Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildStatusItem(
                  'Status Approve', 
                  _rentalData!['status_approve'] == 'disetujui' ? 'Disetujui' : 'Pending',
                  _rentalData!['status_approve'] == 'disetujui',
                  Icons.verified_user_rounded,
                  Colors.blue,
                  (val) => _updateStatus('status_approve', val ? 'disetujui' : 'pending')
                ),
                Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildMultiChoiceStatus(),
                const SizedBox(height: 8),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String date) {
    return Column(
      crossAxisAlignment: label == 'Mulai' ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusItem(String title, String subtitle, bool value, IconData icon, Color color, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: value ? color : Colors.grey[500])),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: color,
      ),
    );
  }

  Widget _buildMultiChoiceStatus() {
    final String currentStatus = (_rentalData!['status'] ?? 'new').toLowerCase();
    final List<Map<String, dynamic>> statusOptions = [
      {'val': 'new', 'label': 'New', 'icon': Icons.star_border_rounded, 'color': Colors.blue},
      {'val': 'pending', 'label': 'Pending', 'icon': Icons.timer_outlined, 'color': Colors.orange},
      {'val': 'confirmed', 'label': 'Aktif', 'icon': Icons.bolt_rounded, 'color': Colors.green},
      {'val': 'masalah', 'label': 'Masalah', 'icon': Icons.report_problem_outlined, 'color': Colors.red},
      {'val': 'completed', 'label': 'Selesai', 'icon': Icons.check_circle_outline_rounded, 'color': Colors.purple},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Status Rental', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt['icon'], size: 16, color: isSelected ? color : Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        opt['label'],
                        style: TextStyle(
                          fontSize: 12, 
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
    final isPerusahaan = _rentalData!['jenis_sewa']?.toString().toLowerCase() == 'perusahaan';
    final String baseUrl = 'https://foxgeen.com/HRIS/uploads/rentals/';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.badge_rounded, 'DOKUMEN IDENTITAS'),
        
        // KTP Image Card
        _buildDocumentImageCard(
          title: isPerusahaan ? 'KTP PIMPINAN / PJ' : 'KTP PELANGGAN',
          fileName: _rentalData!['file_ktp'],
          baseUrl: baseUrl,
        ),
        
        if (isPerusahaan) ...[
          const SizedBox(height: 16),
          _buildDocumentImageCard(
            title: 'NPWP PERUSAHAAN',
            fileName: _rentalData!['file_npwp'],
            baseUrl: baseUrl,
          ),
          const SizedBox(height: 16),
          _buildDocumentImageCard(
            title: 'PURCHASE ORDER (PO)',
            fileName: _rentalData!['file_po'],
            baseUrl: baseUrl,
          ),
        ],

        const SizedBox(height: 24),
        _buildSectionTitle(Icons.location_on_rounded, 'ALAMAT TERDAFTAR'),
        _buildOverviewCard([
          _buildAddressRow('ALAMAT KTP', _rentalData!['alamat_ktp_formatted'] ?? _rentalData!['alamat_ktp'] ?? '-'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Colors.black12),
          ),
          _buildAddressRow('ALAMAT DOMISILI / SEKARANG', _rentalData!['alamat_current_formatted'] ?? _rentalData!['alamat_domisili'] ?? '-'),
        ]),
      ],
    );
  }

  Widget _buildDocumentImageCard({required String title, String? fileName, required String baseUrl}) {
    if (fileName == null || fileName.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.no_photography_outlined, color: Colors.grey[400], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Dokumen $title tidak tersedia', 
                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final String imageUrl = '$baseUrl$fileName';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                ),
                Text('ZOOM ENABLED', style: TextStyle(fontSize: 8, color: _primaryColor.withOpacity(0.6), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              height: 180, // Fixed height to prevent being too large
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.contain, // Contain keeps aspect ratio within 180 height
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[50],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHutangTab() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    if (_debtData == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 30),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05), 
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withOpacity(0.1))
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.redAccent, size: 48),
            ),
            const SizedBox(height: 32),
            const Text('Belum Ada Data Hutang', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Seluruh kewajiban pembayaran penyewa terpantau lunas atau belum tercatat di sistem.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.6)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddDebtDialog,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('BUAT DATA HUTANG BARU', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: Colors.redAccent.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final double total = double.tryParse(_debtData!['total_amount']?.toString() ?? '0') ?? 0;
    final double paid = double.tryParse(_debtData!['paid_amount']?.toString() ?? '0') ?? 0;
    final double remaining = total - paid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildDebtSummaryCard('TOTAL HUTANG', currencyFormat.format(total), const Color(0xFFE57373), Icons.account_balance_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildDebtSummaryCard('DIBAYAR', currencyFormat.format(paid), Colors.green, Icons.check_circle_outline_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDebtSummaryCard('SISA HUTANG', currencyFormat.format(remaining), Colors.orange, Icons.pending_actions_rounded, isFullWidth: true),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(Icons.history_rounded, 'RIWAYAT CICILAN'),
            IconButton(
              onPressed: () => _confirmDeleteDebt(_debtData!['debt_id']),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Hapus Hutang',
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_installments.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Tidak ada jadwal cicilan')))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _installments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final inst = _installments[index];
              final status = inst['status']?.toString().toLowerCase() ?? 'belum';
              Color statusColor = Colors.grey;
              IconData statusIcon = Icons.timer_outlined;
              String statusLabel = 'Belum';

              if (status == 'lunas') {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
                statusLabel = 'Lunas';
              } else if (status == 'terlambat') {
                statusColor = Colors.red;
                statusIcon = Icons.warning_rounded;
                statusLabel = 'Terlambat';
              } else if (status == 'sebagian') {
                statusColor = Colors.orange;
                statusIcon = Icons.pending_rounded;
                statusLabel = 'Sebagian';
              }

              return InkWell(
                onTap: status != 'lunas' ? () => _showPayInstallmentDialog(inst) : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cicilan #${inst['installment_no']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Jatuh Tempo: ${inst['due_date']}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currencyFormat.format(double.tryParse(inst['amount']?.toString() ?? '0') ?? 0), 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (status != 'lunas') ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDebtSummaryCard(String label, String value, Color color, IconData icon, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withOpacity(0.7), letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddDebtDialog() {
    final reasons = ['Tunggakan Sewa', 'Kerusakan Laptop', 'Denda Keterlambatan', 'Lainnya'];
    String selectedReason = reasons[0];
    final totalController = TextEditingController();
    final cicilanController = TextEditingController(text: '3');
    final tempoController = TextEditingController(text: '1');
    final mulaiController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final ketController = TextEditingController();
    final totalFocusNode = FocusNode();
    
    List<Map<String, dynamic>> preview = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          void updatePreview() {
            double total = double.tryParse(totalController.text) ?? 0;
            int count = int.tryParse(cicilanController.text) ?? 0;
            int dueDay = int.tryParse(tempoController.text) ?? 1;
            DateTime start = DateTime.tryParse(mulaiController.text) ?? DateTime.now();
            
            if (total > 0 && count > 0) {
              setDialogState(() {
                preview = _calculateInstallmentsPreview(total, count, start, dueDay);
              });
            } else {
              setDialogState(() { preview = []; });
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 12
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFE57373).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.add_card_rounded, color: Color(0xFFE57373), size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Text('Tambah Data Hutang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    _buildPremiumFieldLabel('ALASAN HUTANG'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50], 
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1))
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedReason,
                          items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (val) {
                            setDialogState(() { selectedReason = val!; });
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    _buildPremiumFieldLabel('TOTAL HUTANG'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: totalController,
                      focusNode: totalFocusNode,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixText: totalFocusNode.hasFocus ? 'Rp ' : null,
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                      ),
                      onChanged: (_) => updatePreview(),
                      onTap: () {
                        setDialogState(() {}); // Force rebuild to show prefix
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPremiumFieldLabel('JUMLAH CICILAN'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: cicilanController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  suffixText: 'Bulan',
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                                ),
                                onChanged: (_) => updatePreview(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPremiumFieldLabel('TGL JATUH TEMPO'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: tempoController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '1-31',
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                                ),
                                onChanged: (_) => updatePreview(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    _buildPremiumFieldLabel('MULAI CICILAN PERTAMA'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (date != null) {
                          setDialogState(() { mulaiController.text = DateFormat('yyyy-MM-dd').format(date); });
                          updatePreview();
                        }
                      },
                      child: TextField(
                        controller: mulaiController, enabled: false, 
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFFE57373)),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                        )
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    _buildPremiumFieldLabel('KETERANGAN / CATATAN'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ketController, maxLines: 2, 
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                      )
                    ),
                    
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined, size: 14, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('PREVIEW JADWAL CICILAN', 
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.blue[600])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxHeight: 180), // Limit height for ~5 items
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.03), 
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.withOpacity(0.1))
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: preview.map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Cicilan #${p['no']} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(p['due_date']))}', 
                                    style: const TextStyle(fontSize: 12)),
                                  Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(p['amount']), 
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: const Color(0xFFE57373).withOpacity(0.5))
                            ),
                            child: const Text('BATAL', style: TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (totalController.text.isEmpty || cicilanController.text.isEmpty) return;
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
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan')));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE57373),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text('SIMPAN DATA', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _calculateInstallmentsPreview(double total, int count, DateTime start, int dueDay) {
    List<Map<String, dynamic>> preview = [];
    if (count <= 0) return preview;
    
    double perCicilan = (total / count).floorToDouble(); 
    double sisaBeda = total - (perCicilan * count);
    
    for (int i = 1; i <= count; i++) {
      DateTime dueBase = DateTime(start.year, start.month + (i - 1));
      int lastDayOfMonth = DateTime(dueBase.year, dueBase.month + 1, 0).day;
      DateTime due = DateTime(dueBase.year, dueBase.month, dueDay > lastDayOfMonth ? lastDayOfMonth : dueDay);
      
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
    final double totalAmount = double.tryParse(installment['amount']?.toString() ?? '0') ?? 0;
    final double paidAmount = double.tryParse(installment['paid_amount']?.toString() ?? '0') ?? 0;
    final double remainingAmount = totalAmount - paidAmount;
    
    final noteController = TextEditingController();
    final amountController = TextEditingController(text: remainingAmount.toStringAsFixed(0));
    File? proofFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double inputAmount = double.tryParse(amountController.text) ?? 0;
          final bool isFullPayment = inputAmount >= remainingAmount;
          final double diff = remainingAmount - inputAmount;
          
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final Color inputBg = isDark ? Colors.white.withOpacity(0.05) : (Colors.grey[50] ?? Colors.grey);
          final Color borderColor = isDark ? Colors.white.withOpacity(0.1) : (Colors.grey[300] ?? Colors.grey);
          final Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);
          final Color subTextColor = isDark ? Colors.white70 : (Colors.grey[600] ?? Colors.grey);

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: const Color(0xFF00C853),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text('Konfirmasi Pembayaran', 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5)),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    left: 20, right: 20, top: 24
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _buildSummaryItem('CICILAN KE-', installment['installment_no'].toString(), isDark: isDark)),
                              Container(width: 1, height: 30, color: borderColor.withOpacity(0.3)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSummaryItem('TOTAL CICILAN', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount), isDark: isDark)),
                              const SizedBox(width: 12),
                              Container(width: 1, height: 30, color: borderColor.withOpacity(0.3)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSummaryItem('SISA HARUS BAYAR', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(remainingAmount), valueColor: Colors.red, isDark: isDark)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text('NOMINAL DIBAYAR SEKARANG', 
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTextColor, letterSpacing: 1)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBg,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Rp', style: TextStyle(fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7))),
                                ],
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minHeight: 54),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)),
                          ),
                          onChanged: (val) {
                            final double input = double.tryParse(val) ?? 0;
                            if (input > remainingAmount) {
                              amountController.text = remainingAmount.toStringAsFixed(0);
                              // Ensure cursor stays at the end
                              amountController.selection = TextSelection.fromPosition(
                                TextPosition(offset: amountController.text.length),
                              );
                            }
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            _buildQuickButton('Bayar Penuh (Lunas)', Icons.check_circle_outline_rounded, () {
                              setDialogState(() { amountController.text = remainingAmount.toStringAsFixed(0); });
                            }, const Color(0xFF00C853)),
                            const SizedBox(width: 10),
                            _buildQuickButton('½ dari sisa', Icons.pie_chart_outline_rounded, () {
                              setDialogState(() { amountController.text = (remainingAmount / 2).toStringAsFixed(0); });
                            }, Colors.blue),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isFullPayment 
                              ? (isDark ? Colors.green.withOpacity(0.1) : const Color(0xFFE8F5E9)) 
                              : (isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFE3F2FD)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isFullPayment ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(isFullPayment ? Icons.check_circle_rounded : Icons.info_outline_rounded, 
                                color: isFullPayment ? Colors.green : Colors.blue, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isFullPayment 
                                    ? 'Cicilan ini akan lunas!' 
                                    : 'Bayar sebagian... Sisa Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(diff)} otomatis dijadwalkan ke cicilan baru bulan depan.',
                                  style: TextStyle(
                                    color: isFullPayment 
                                      ? (isDark ? Colors.green[300] : Colors.green[800]) 
                                      : (isDark ? Colors.blue[300] : Colors.blue[800]), 
                                    fontSize: 13, height: 1.4, fontWeight: FontWeight.w600
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text('BUKTI PEMBAYARAN (WAJIB)', 
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTextColor, letterSpacing: 1)),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            FilePickerResult? result = await FilePicker.platform.pickFiles();
                            if (result != null) {
                              setDialogState(() { proofFile = File(result.files.single.path!); });
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
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(proofFile?.path.split('/').last ?? 'Pilih file bukti transfer...', 
                                      style: TextStyle(color: subTextColor, fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[100], 
                                    border: Border(left: BorderSide(color: borderColor)),
                                  ),
                                  child: Text('Browse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text('CATATAN', 
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTextColor, letterSpacing: 1)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteController,
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'cth: Transfer BCA, ref 12345...',
                            hintStyle: TextStyle(color: subTextColor.withOpacity(0.5), fontSize: 14),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00C853), width: 2)),
                          ),
                        ),
                        const SizedBox(height: 36),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                ),
                                child: Text('BATAL', style: TextStyle(fontWeight: FontWeight.bold, color: subTextColor, letterSpacing: 1)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                    if (proofFile == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan unggah bukti pembayaran terlebih dahulu')));
                                        return;
                                    }
                                    Navigator.pop(context);
                                    setState(() => _isLoading = true);
                                    final res = await _rentPlanService.payInstallment(
                                        int.parse(installment['installment_id'].toString()), 
                                        double.parse(amountController.text), 
                                        noteController.text,
                                        proofFile
                                    );
                                    if (res['status'] == true) {
                                        _fetchDetail();
                                    } else {
                                        setState(() => _isLoading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Gagal memproses pembayaran')));
                                    }
                                },
                                icon: const Icon(Icons.check_rounded, size: 20),
                                label: const Text('KONFIRMASI', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C853),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildSummaryItem(String label, String value, {Color? valueColor, bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 8, color: isDark ? Colors.white54 : Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? (isDark ? Colors.white : Colors.black87))),
      ],
    );
  }

  Widget _buildQuickButton(String label, IconData icon, VoidCallback onTap, Color color) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: color),
        label: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: color.withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _buildPremiumFieldLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5));
  }


  Widget _buildAddressRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4)),
      ],
    );
  }

  void _confirmDeleteDebt(dynamic debtId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data Hutang?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Seluruh data hutang dan riwayat cicilan ini akan dihapus permanen secara sistem. Lanjutkan?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('BATAL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final res = await _rentPlanService.deleteDebt(int.parse(debtId.toString()));
              if (res['status'] == true) {
                _fetchDetail();
              } else {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Gagal menghapus hutang')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('HAPUS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
