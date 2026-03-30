import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/rent_plan_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_app_bar.dart';
import '../../localization/app_localizations.dart';

class AddRentPlanPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AddRentPlanPage({super.key, required this.userData});

  @override
  State<AddRentPlanPage> createState() => _AddRentPlanPageState();
}

class _AddRentPlanPageState extends State<AddRentPlanPage> {
  final RentPlanService _rentPlanService = RentPlanService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  bool _isLoadingRegKtp = false;
  bool _isLoadingDistKtp = false;
  bool _isLoadingVillKtp = false;
  bool _isLoadingRegCur = false;
  bool _isLoadingDistCur = false;
  bool _isLoadingVillCur = false;

  // Form Data from API
  String _orderNumber = '';
  List<dynamic> _customers = [];
  List<dynamic> _laptops = [];
  List<dynamic> _jaminanPribadi = [];
  List<dynamic> _jaminanPerusahaan = [];
  List<dynamic> _shippingCosts = [];
  List<dynamic> _provinces = [];
  List<dynamic> _pricingTiers = [];

  // Form Values
  String? _selectedCustomerId;
  String _jenisSewa = 'pribadi'; // pribadi, perusahaan
  DateTime _invoiceDate = DateTime.now();
  int _lamaSewa = 1;

  // Address KTP
  String? _selectedProvinceKtp;
  String? _selectedRegencyKtp;
  String? _selectedDistrictKtp;
  String? _selectedVillageKtp;
  List<dynamic> _regenciesKtp = [];
  List<dynamic> _districtsKtp = [];
  List<dynamic> _villagesKtp = [];

  // Address Domisili
  String? _selectedProvinceCur;
  String? _selectedRegencyCur;
  String? _selectedDistrictCur;
  String? _selectedVillageCur;
  List<dynamic> _regenciesCur = [];
  List<dynamic> _districtsCur = [];
  List<dynamic> _villagesCur = [];

  // Personal / Company Info
  final _namaLengkapController = TextEditingController();
  final _nikController = TextEditingController();
  final _namaPerusahaanController = TextEditingController();
  final _npwpController = TextEditingController();
  final _notesController = TextEditingController();
  final _whatsappController = TextEditingController();

  // Files
  File? _fileKtp;
  File? _fileNpwp;
  File? _filePo;
  File? _fileKtpPimpinan;
  File? _fileDomisiliPerusahaan;
  Map<int, File?> _fileJaminan = {1: null, 2: null, 3: null};
  Map<int, String?> _selectedJaminanIds = {1: null, 2: null, 3: null};

  // Items
  List<Map<String, dynamic>> _itemRows = [
    {'laptop_id': null, 'qty': 1, 'price': 0}
  ];

  // Shipping
  String? _selectedShippingId;
  int _shippingCostAmount = 0;
  String _tipePengiriman = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final response = await _rentPlanService.getRentFormData();
    if (response['status'] == true) {
      final data = response['data'];
      setState(() {
        _orderNumber = data['order_number'] ?? '';
        _customers = List<dynamic>.from(data['customers'] ?? []);
        _laptops = List<dynamic>.from(data['laptops'] ?? []);
        // Filter out "KTP" from guarantees as it has its own field
        _jaminanPribadi = List<dynamic>.from(data['jaminan_pribadi'] ?? [])
            .where((j) => j['category_name'].toString().toUpperCase() != 'KTP').toList();
        _jaminanPerusahaan = List<dynamic>.from(data['jaminan_perusahaan'] ?? [])
            .where((j) => j['category_name'].toString().toUpperCase() != 'KTP').toList();
        _shippingCosts = List<dynamic>.from(data['shipping_costs'] ?? []);
        _provinces = List<dynamic>.from(data['provinces'] ?? []);
        _pricingTiers = List<dynamic>.from(data['pricing_tiers'] ?? []);
        _isLoadingData = false;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'rent_plan.error.fetch_failed'.tr(context))),
        );
        Navigator.pop(context);
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

  void _calculatePriceForRow(int index) {
    if (_itemRows[index]['laptop_id'] == null) return;
    int qty = _itemRows[index]['qty'] ?? 1;
    double price = 0;
    for (var tier in _pricingTiers) {
      int min = int.tryParse(tier['nama_harga'].toString()) ?? 0;
      int max = int.tryParse(tier['nama_harga2'].toString()) ?? 999999;
      
      // If qty exceeds the current tier's max, but it's the last tier, use this price
      if (tier == _pricingTiers.last && qty >= min) {
        price = double.tryParse(tier['harga'].toString()) ?? 0;
        break;
      }

      if (qty >= min && qty <= max) {
        price = double.tryParse(tier['harga'].toString()) ?? 0;
        break;
      }
    }

    setState(() {
      _itemRows[index]['price'] = price;
    });
  }

  double get _totalPrice {
    double total = 0;
    for (var row in _itemRows) {
      double price = (row['price'] is num) ? (row['price'] as num).toDouble() : 0.0;
      int qty = row['qty'] ?? 1;
      total += (price * qty * _lamaSewa);
    }
    return total + _shippingCostAmount;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_jenisSewa == 'pribadi' && _fileKtp == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('rent_plan.validation.ktp_required'.tr(context))));
      return;
    }

    int minJaminan = _jenisSewa == 'pribadi' ? 3 : 2;
    int jaminanCount = _selectedJaminanIds.entries.where((e) => e.key <= minJaminan && e.value != null).length;
    int jaminanFileCount = _fileJaminan.entries.where((e) => e.key <= minJaminan && e.value != null).length;

    if (jaminanCount < minJaminan || jaminanFileCount < minJaminan) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('rent_plan.validation.guarantee_min'.tr(context, args: {'min': minJaminan.toString()}))));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Map<String, String> body = {
        'customer_id': _selectedCustomerId!,
        'order_number': _orderNumber,
        'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        'lama_sewa': _lamaSewa.toString(),
        'jenis_sewa': _jenisSewa,
        'whatsapp': _whatsappController.text,
        'nama_lengkap': _namaLengkapController.text,
        'nik': _nikController.text,
        'nama_perusahaan': _namaPerusahaanController.text,
        'npwp': _npwpController.text,
        'notes': _notesController.text,
        'province_ktp_name': _selectedProvinceKtp != null ? (_provinces.firstWhere((p) => p['id'].toString() == _selectedProvinceKtp, orElse: () => {'name': ''})['name'] ?? '') : '',
        'regency_ktp_name': _selectedRegencyKtp != null ? (_regenciesKtp.firstWhere((r) => r['id'].toString() == _selectedRegencyKtp, orElse: () => {'name': ''})['name'] ?? '') : '',
        'district_ktp_name': _selectedDistrictKtp != null ? (_districtsKtp.firstWhere((d) => d['id'].toString() == _selectedDistrictKtp, orElse: () => {'name': ''})['name'] ?? '') : '',
        'village_ktp_name': _selectedVillageKtp != null ? (_villagesKtp.firstWhere((v) => v['id'].toString() == _selectedVillageKtp, orElse: () => {'name': ''})['name'] ?? '') : '',
        'province_current_name': _selectedProvinceCur != null ? (_provinces.firstWhere((p) => p['id'].toString() == _selectedProvinceCur, orElse: () => {'name': ''})['name'] ?? '') : '',
        'regency_current_name': _selectedRegencyCur != null ? (_regenciesCur.firstWhere((r) => r['id'].toString() == _selectedRegencyCur, orElse: () => {'name': ''})['name'] ?? '') : '',
        'district_current_name': _selectedDistrictCur != null ? (_districtsCur.firstWhere((d) => d['id'].toString() == _selectedDistrictCur, orElse: () => {'name': ''})['name'] ?? '') : '',
        'village_current_name': _selectedVillageCur != null ? (_villagesCur.firstWhere((v) => v['id'].toString() == _selectedVillageCur, orElse: () => {'name': ''})['name'] ?? '') : '',
        'laptop_codes': json.encode(_itemRows.map((e) => e['laptop_id']).toList()),
        'quantities': json.encode(_itemRows.map((e) => e['qty']).toList()),
        'unit_prices': json.encode(_itemRows.map((e) => e['price']).toList()),
        'jaminan_ids': json.encode(_selectedJaminanIds.values.toList()),
        'biaya_kirim': _shippingCostAmount.toString(),
        'tipe_pengiriman': _tipePengiriman,
      };

      Map<String, String> files = {
        if (_jenisSewa == 'pribadi' && _fileKtp != null) 'file_ktp': _fileKtp!.path,
        if (_fileJaminan[1] != null) 'file_jaminan_1': _fileJaminan[1]!.path,
        if (_fileJaminan[2] != null) 'file_jaminan_2': _fileJaminan[2]!.path,
        if (_fileJaminan[3] != null) 'file_jaminan_3': _fileJaminan[3]!.path,
        
        if (_jenisSewa == 'perusahaan') ...{
          if (_fileNpwp != null) 'file_npwp': _fileNpwp!.path,
          if (_filePo != null) 'file_po': _filePo!.path,
          if (_fileKtpPimpinan != null) 'file_ktp_pimpinan': _fileKtpPimpinan!.path,
          if (_fileDomisiliPerusahaan != null) 'file_domisili_perusahaan': _fileDomisiliPerusahaan!.path,
        }
      };

      final res = await _rentPlanService.storeRentPlan(body, files);
      setState(() => _isSubmitting = false);

      if (res['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('rent_plan.success.created'.tr(context))));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'rent_plan.error.failed_save'.tr(context))));
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('rent_plan.error.generic'.tr(context, args: {'error': e.toString()}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: true,
        showActions: false,
        title: 'rent_plan.add_new_order'.tr(context),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _buildOrderInfoCard(),
            const SizedBox(height: 20),
            _buildSection(
              title: 'rent_plan.customer_data'.tr(context),
              icon: Icons.person_add_rounded,
              color: Theme.of(context).colorScheme.primary,
              children: [
                _buildDropdown('rent_plan.customer'.tr(context), _selectedCustomerId, _customers.map((c) => DropdownMenuItem(
                  value: c['user_id'].toString(),
                  child: Text('${c['first_name']} ${c['last_name']}', overflow: TextOverflow.ellipsis),
                )).toList(), (val) {
                  setState(() {
                    _selectedCustomerId = val;
                    if (val != null) {
                      final customer = _customers.firstWhere((c) => c['user_id'].toString() == val, orElse: () => null);
                      if (customer != null && customer['contact_number'] != null) {
                        _whatsappController.text = customer['contact_number'].toString();
                      }
                    }
                  });
                }, hint: 'rent_plan.select_customer'.tr(context)),
                const SizedBox(height: 16),
                _buildTextField('rent_plan.whatsapp'.tr(context), controller: _whatsappController, icon: Icons.phone_rounded, keyboardType: TextInputType.phone),
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
              title: 'rent_plan.domicile_address'.tr(context),
              icon: Icons.home_rounded,
              color: Colors.teal[700]!,
              children: [_buildRegionDropdowns(false)],
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'rent_plan.rent_detail'.tr(context),
              icon: Icons.calendar_month_rounded,
              color: Colors.orange[800]!,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildDatePicker('rent_plan.rent_start'.tr(context))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('rent_plan.rent_duration'.tr(context), 
                      suffix: 'rent_plan.days'.tr(context),
                      initialValue: _lamaSewa.toString(), 
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setState(() {
                          _lamaSewa = int.tryParse(val) ?? 1;
                          for (int i = 0; i < _itemRows.length; i++) _calculatePriceForRow(i);
                        });
                      }
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTipePenyewaToggle(),
                const SizedBox(height: 16),
                if (_jenisSewa == 'pribadi') ...[
                  _buildTextField('rent_plan.full_name'.tr(context), controller: _namaLengkapController, icon: Icons.badge_rounded),
                  const SizedBox(height: 16),
                  _buildTextField('rent_plan.nik'.tr(context), controller: _nikController, icon: Icons.credit_card_rounded, keyboardType: TextInputType.number),
                ] else ...[
                  _buildTextField('rent_plan.company_name'.tr(context), controller: _namaPerusahaanController, icon: Icons.business_rounded),
                  const SizedBox(height: 16),
                  _buildTextField('rent_plan.npwp_number'.tr(context), controller: _npwpController, icon: Icons.description_rounded),
                ],
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'rent_plan.docs_guarantees'.tr(context),
              icon: Icons.verified_user_rounded,
              color: Colors.deepPurple[700]!,
              children: [
                if (_jenisSewa == 'pribadi') ...[
                  _buildFileUploadTile('rent_plan.upload_ktp'.tr(context), _fileKtp, () => _pickFile(0), icon: Icons.camera_alt_rounded),
                  const Divider(height: 32),
                ] else ...[
                  _buildFileUploadTile('rent_plan.upload_npwp'.tr(context), _fileNpwp, () => _pickFile('npwp'), icon: Icons.upload_file_rounded),
                  const SizedBox(height: 12),
                  _buildFileUploadTile('rent_plan.upload_po'.tr(context), _filePo, () => _pickFile('po'), icon: Icons.upload_file_rounded),
                  const SizedBox(height: 12),
                  _buildFileUploadTile('rent_plan.upload_ktp_leader'.tr(context), _fileKtpPimpinan, () => _pickFile('ktp_pimpinan'), icon: Icons.upload_file_rounded),
                  const SizedBox(height: 12),
                  _buildFileUploadTile('rent_plan.company_domicile'.tr(context), _fileDomisiliPerusahaan, () => _pickFile('domisili'), icon: Icons.upload_file_rounded),
                  const Divider(height: 32),
                ],
                Text('${'rent_plan.guarantee'.tr(context)} (${'rent_plan.required_min'.tr(context, args: {'min': (_jenisSewa == 'pribadi' ? 3 : 2).toString()})})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                const SizedBox(height: 12),
                for (int i = 1; i <= (_jenisSewa == 'pribadi' ? 3 : 2); i++) ...[
                  _buildJaminanSelector(i),
                  if (i < (_jenisSewa == 'pribadi' ? 3 : 2)) const SizedBox(height: 12),
                ],
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'rent_plan.rent_item'.tr(context),
              icon: Icons.laptop_mac_rounded,
              color: Colors.blueGrey[700]!,
              children: [_buildItemTable()],
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'rent_plan.shipping_notes'.tr(context),
              icon: Icons.local_shipping_rounded,
              color: Colors.cyan[800]!,
              children: [
                _buildShippingDropdown(),
                const SizedBox(height: 16),
                _buildTextField('rent_plan.additional_notes'.tr(context), controller: _notesController, maxLines: 3, icon: Icons.notes_rounded, isRequired: false),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : color.withOpacity(0.1), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)], 
          begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('rent_plan.order_number'.tr(context), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(_orderNumber, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(Icons.receipt_long_rounded, color: Colors.white.withOpacity(0.5), size: 30),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, {Key? key, TextEditingController? controller, String? initialValue, bool enabled = true, TextInputType? keyboardType, Function(String)? onChanged, int maxLines = 1, IconData? icon, String? suffix, bool isRequired = true}) {
    return TextFormField(
      key: key,
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      validator: isRequired ? (val) => val == null || val.isEmpty ? 'rent_plan.validation.required'.tr(context) : null : null,
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
  
  @override
  void dispose() {
    _namaLengkapController.dispose();
    _nikController.dispose();
    _namaPerusahaanController.dispose();
    _npwpController.dispose();
    _notesController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Widget _buildDropdown(String label, String? value, List<DropdownMenuItem<String>> items, Function(String?) onChanged, {String? hint, bool isLoading = false}) {
    // Deduplicate items by value
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
      hint: Text(isLoading ? 'rent_plan.loading'.tr(context) : (hint ?? 'rent_plan.select_item'.tr(context, args: {'item': label})), 
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
      validator: (val) => val == null ? 'rent_plan.validation.required'.tr(context) : null,
    );
  }

  Widget _buildRegionDropdowns(bool isKtp) {
    return Column(
      children: [
        _buildDropdown('profile.state_province'.tr(context), isKtp ? _selectedProvinceKtp : _selectedProvinceCur, _provinces.map((p) => DropdownMenuItem(
          value: p['id'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) {
              setState(() { if (isKtp) _selectedProvinceKtp = val; else _selectedProvinceCur = val; });
              _loadRegencies(val, isKtp);
            }
        }, hint: 'rent_plan.select_province'.tr(context)),
        const SizedBox(height: 12),
        _buildDropdown('profile.city_regency'.tr(context), isKtp ? _selectedRegencyKtp : _selectedRegencyCur, (isKtp ? _regenciesKtp : _regenciesCur).map((p) => DropdownMenuItem(
          value: p['id'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) {
              setState(() { if (isKtp) _selectedRegencyKtp = val; else _selectedRegencyCur = val; });
              _loadDistricts(val, isKtp);
            }
        }, hint: 'rent_plan.select_regency'.tr(context), isLoading: isKtp ? _isLoadingRegKtp : _isLoadingRegCur),
        const SizedBox(height: 12),
        _buildDropdown('rent_plan.district'.tr(context), isKtp ? _selectedDistrictKtp : _selectedDistrictCur, (isKtp ? _districtsKtp : _districtsCur).map((p) => DropdownMenuItem(
          value: p['id'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) {
              setState(() { if (isKtp) _selectedDistrictKtp = val; else _selectedDistrictCur = val; });
              _loadVillages(val, isKtp);
            }
        }, hint: 'rent_plan.select_district'.tr(context), isLoading: isKtp ? _isLoadingDistKtp : _isLoadingDistCur),
        const SizedBox(height: 12),
        _buildDropdown('rent_plan.village'.tr(context), isKtp ? _selectedVillageKtp : _selectedVillageCur, (isKtp ? _villagesKtp : _villagesCur).map((p) => DropdownMenuItem(
          value: p['id'].toString(), child: Text(p['name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
            if (val != null) setState(() { if (isKtp) _selectedVillageKtp = val; else _selectedVillageCur = val; });
        }, hint: 'rent_plan.select_village'.tr(context), isLoading: isKtp ? _isLoadingVillKtp : _isLoadingVillCur),
      ],
    );
  }

  Widget _buildDatePicker(String label) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: _invoiceDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (date != null) setState(() => _invoiceDate = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white,
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_invoiceDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipePenyewaToggle() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleItem('rent_plan.personal'.tr(context), _jenisSewa == 'pribadi', () => setState(() {
            _jenisSewa = 'pribadi';
          })),
          _buildToggleItem('rent_plan.company'.tr(context), _jenisSewa == 'perusahaan', () => setState(() {
            _jenisSewa = 'perusahaan';
            // Clear 3rd jaminan if switching to perusahaan (which only needs 2)
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
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Theme.of(context).colorScheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600]))),
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadTile(String label, File? file, VoidCallback onTap, {IconData? icon}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: file == null ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]) : Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: file == null ? (isDark ? Colors.white12 : Theme.of(context).dividerColor) : Colors.green[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: file == null ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon ?? Icons.attach_file_rounded, color: file == null ? Colors.blue : Colors.green, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(file == null ? 'rent_plan.tap_to_pick'.tr(context) : file.path.split('/').last, style: TextStyle(fontSize: 12, color: file == null ? Colors.grey[500] : Colors.green[700])),
                ],
              ),
            ),
            if (file != null) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildJaminanSelector(int index) {
    List<dynamic> baseOptions = _jenisSewa == 'pribadi' ? _jaminanPribadi : _jaminanPerusahaan;
    
    // Filter options to exclude those already selected in OTHER slots
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
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1))),
      child: Column(
        children: [
          _buildDropdown('${'rent_plan.guarantee'.tr(context)} $index', _selectedJaminanIds[index], availableOptions.map((j) => DropdownMenuItem(
            value: j['constants_id'].toString(), child: Text(j['category_name'], overflow: TextOverflow.ellipsis))).toList(), (val) {
              setState(() { _selectedJaminanIds[index] = val; });
          }, hint: '${'rent_plan.select_guarantee'.tr(context)} $index'),
          if (_selectedJaminanIds[index] != null) ...[
            const SizedBox(height: 12),
            _buildFileUploadTile('${'rent_plan.guarantee_file'.tr(context)} $index', _fileJaminan[index], () => _pickFile(index), icon: Icons.upload_file_rounded),
          ],
        ],
      ),
    );
  }

  Widget _buildItemTable() {
    return Column(
      children: [
        for (int i = 0; i < _itemRows.length; i++) ...[
          _buildItemRow(i),
          if (i < _itemRows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildItemRow(int index) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Theme.of(context).dividerColor)),
      child: Column(
        children: [
          _buildDropdown('rent_plan.laptop'.tr(context), _itemRows[index]['laptop_id'], _laptops.map((l) => DropdownMenuItem(
            value: l['id'].toString(), child: Text(l['nama_laptop'], overflow: TextOverflow.ellipsis))).toList(), (val) {
              setState(() { _itemRows[index]['laptop_id'] = val; _calculatePriceForRow(index); });
          }, hint: 'rent_plan.select_laptop'.tr(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(width: 80, child: _buildTextField('rent_plan.qty'.tr(context), initialValue: _itemRows[index]['qty'].toString(), keyboardType: TextInputType.number, onChanged: (val) {
                setState(() { _itemRows[index]['qty'] = int.tryParse(val) ?? 1; _calculatePriceForRow(index); });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(
                'rent_plan.unit_price'.tr(context), 
                key: ValueKey('price_${index}_${_itemRows[index]['price']}'),
                initialValue: NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(_itemRows[index]['price']), 
                enabled: false,
                isRequired: false,
                suffix: 'IDR'
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShippingDropdown() {
    return _buildDropdown('rent_plan.shipping_service'.tr(context), _selectedShippingId, _shippingCosts.map((s) => DropdownMenuItem(
      value: s['constants_id'].toString(),
      child: Text('${s['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.parse(s['field_one']))}', overflow: TextOverflow.ellipsis),
    )).toList(), (val) {
      if (val != null) {
        final ship = _shippingCosts.firstWhere((s) => s['constants_id'].toString() == val);
        setState(() {
          _selectedShippingId = val;
          _shippingCostAmount = int.parse(ship['field_one']);
          _tipePengiriman = ship['category_name'];
        });
      }
    }, hint: 'rent_plan.select_shipping'.tr(context));
  }

  Widget _buildBottomAction() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('rent_plan.estimated_total'.tr(context), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
              Text(currencyFormat.format(_totalPrice), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                : Text('rent_plan.create_order_now'.tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
