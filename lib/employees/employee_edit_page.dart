import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';

import '../widgets/searchable_dropdown.dart';
import '../widgets/secondary_app_bar.dart';

class EmployeeEditPage extends StatefulWidget {
  final Map<String, dynamic> employeeData;
  final String section;

  const EmployeeEditPage({
    super.key,
    required this.employeeData,
    this.section = 'profil',
  });

  @override
  State<EmployeeEditPage> createState() => _EmployeeEditPageState();
}

class _EmployeeEditPageState extends State<EmployeeEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  final Map<String, TextEditingController> _controllers = {};

  // Lookup Data
  List<dynamic> _departments = [];
  List<dynamic> _designations = [];
  List<dynamic> _shifts = [];
  List<dynamic> _religions = [];
  bool _isLoadingLookups = false;

  final Color _primaryColor = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _initControllers();
    _fetchLookups();
  }

  void _initControllers() {
    final info = widget.employeeData['user_info'] ?? {};
    final emp = widget.employeeData['employment'] ?? {};
    final personal = widget.employeeData['personal'] ?? {};

    if (widget.section == 'profil') {
      _controllers['first_name'] = TextEditingController(
        text: info['first_name'] ?? '',
      );
      _controllers['last_name'] = TextEditingController(
        text: info['last_name'] ?? '',
      );
      _controllers['email'] = TextEditingController(text: info['email'] ?? '');
      _controllers['contact_number'] = TextEditingController(
        text: info['contact_number'] ?? '',
      );
      _controllers['address_1'] = TextEditingController(
        text: info['address_1'] ?? '',
      );
      _controllers['city'] = TextEditingController(text: info['city'] ?? '');
      _controllers['state'] = TextEditingController(text: info['state'] ?? '');
      _controllers['zipcode'] = TextEditingController(
        text: info['zipcode'] ?? '',
      );
      _controllers['nationality'] = TextEditingController(
        text: info['country'] ?? '',
      );
    } else if (widget.section == 'kontrak') {
      _controllers['basic_salary'] = TextEditingController(
        text: emp['basic_salary']?.toString() ?? '0',
      );
      _controllers['hourly_rate'] = TextEditingController(
        text: emp['hourly_rate']?.toString() ?? '0',
      );
      _controllers['salay_type'] = TextEditingController(
        text: emp['salay_type'] == 'Per Month' ? '1' : '0',
      );
      _controllers['worklog'] = TextEditingController(
        text: emp['worklog']?.toString() ?? '0',
      );
      _controllers['worklog_active'] = TextEditingController(
        text: emp['worklog_active']?.toString() ?? '0',
      );
      _controllers['date_of_joining'] = TextEditingController(
        text: emp['date_of_joining'] ?? '',
      );
      _controllers['date_of_leaving'] = TextEditingController(
        text: emp['contract_end'] ?? '',
      );
      _controllers['leave_categories'] = TextEditingController(
        text: emp['leave_categories'] ?? 'all',
      );
    } else if (widget.section == 'pekerjaan') {
      _controllers['department_id'] = TextEditingController(
        text: emp['department_id']?.toString() ?? '',
      );
      _controllers['designation_id'] = TextEditingController(
        text: emp['designation_id']?.toString() ?? '',
      );
      _controllers['office_shift_id'] = TextEditingController(
        text: emp['office_shift_id']?.toString() ?? '',
      );
      _controllers['status_work'] = TextEditingController(
        text: emp['status_work']?.toString() ?? '',
      );
    } else if (widget.section == 'pribadi') {
      _controllers['date_of_birth'] = TextEditingController(
        text: personal['date_of_birth'] ?? '',
      );
      _controllers['marital_status'] = TextEditingController(
        text: personal['marital_status']?.toString() ?? '0',
      );
      _controllers['religion_id'] = TextEditingController(
        text: personal['religion_id']?.toString() ?? '',
      );
      _controllers['blood_group'] = TextEditingController(
        text: personal['blood_group'] ?? '',
      );
      _controllers['gender'] = TextEditingController(
        text: info['gender_raw']?.toString() ?? '1',
      );

      // Bank fields
      final bank = widget.employeeData['bank_account'] ?? {};
      _controllers['account_title'] = TextEditingController(
        text: bank['account_title'] ?? '',
      );
      _controllers['account_number'] = TextEditingController(
        text: bank['account_number'] ?? '',
      );
      _controllers['bank_name'] = TextEditingController(
        text: bank['bank_name'] ?? '',
      );
      _controllers['iban'] = TextEditingController(text: bank['iban'] ?? '');
      _controllers['swift_code'] = TextEditingController(
        text: bank['swift_code'] ?? '',
      );
      _controllers['bank_branch'] = TextEditingController(
        text: bank['bank_branch'] ?? '',
      );
    }
  }

  Future<void> _fetchLookups() async {
    setState(() => _isLoadingLookups = true);
    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('${AppConstants.baseUrl}/get_departments'),
        ),
        http.get(
          Uri.parse('${AppConstants.baseUrl}/get_designations'),
        ),
        http.get(Uri.parse('${AppConstants.baseUrl}/get_shifts')),
        http.get(Uri.parse('${AppConstants.baseUrl}/get_religions')),
      ]);

      if (responses.every((r) => r.statusCode == 200)) {
        if (!mounted) return;
        setState(() {
          _departments = json.decode(responses[0].body)['data'];
          _designations = json.decode(responses[1].body)['data'];
          _shifts = json.decode(responses[2].body)['data'];
          _religions = json.decode(responses[3].body)['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching lookups: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLookups = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}/update_employee',
      );
      final request = http.MultipartRequest('POST', url);

      request.fields['user_id'] = widget.employeeData['user_info']['user_id']
          .toString();
      request.fields['section'] = widget.section;

      _controllers.forEach((key, controller) {
        request.fields[key] = controller.text;
      });

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('employees.save_success'.tr(context))),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'main.error_with_msg'.tr(
                  context,
                  args: {'message': data['message']},
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title;
    switch (widget.section) {
      case 'kontrak':
        title = 'employees.edit_contract'.tr(context);
        break;
      case 'pekerjaan':
        title = 'employees.edit_employment'.tr(context);
        break;
      case 'pribadi':
        title = 'employees.edit_personal'.tr(context);
        break;
      case 'riwayat':
        title = 'employees.edit_history'.tr(context);
        break;
      case 'dokumen':
        title = 'employees.edit_documents'.tr(context);
        break;
      default:
        title = 'employees.edit_profile'.tr(context);
    }

    return Scaffold(
      appBar: SecondaryAppBar(title: title),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'employees.save'.tr(context).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildFormFields(),
                ),
              ),
            ),
    );
  }

  List<Widget> _buildFormFields() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.section == 'profil') {
      return [
        _buildTextField(
          label: 'profile.first_name'.tr(context),
          key: 'first_name',
          prefixIcon: const Icon(
            Icons.person_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.last_name'.tr(context),
          key: 'last_name',
          prefixIcon: const Icon(
            Icons.person_outline_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.email'.tr(context),
          key: 'email',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(
            Icons.email_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.phone'.tr(context),
          key: 'contact_number',
          keyboardType: TextInputType.phone,
          prefixIcon: const Icon(
            Icons.phone_android_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.address'.tr(context),
          key: 'address_1',
          prefixIcon: const Icon(
            Icons.home_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.city_regency'.tr(context),
          key: 'city',
          prefixIcon: const Icon(
            Icons.location_city_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.state_province'.tr(context),
          key: 'state',
          prefixIcon: const Icon(
            Icons.map_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.zip_code'.tr(context),
          key: 'zipcode',
          prefixIcon: const Icon(
            Icons.pin_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.nationality'.tr(context),
          key: 'nationality',
          prefixIcon: const Icon(
            Icons.flag_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
      ];
    } else if (widget.section == 'kontrak') {
      return [
        _buildTextField(
          label: 'profile.basic_salary'.tr(context),
          key: 'basic_salary',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(
            Icons.payments_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.hourly_rate'.tr(context),
          key: 'hourly_rate',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(
            Icons.timer_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildDropdown(
          label: 'employees.payslip_type'.tr(context),
          key: 'salay_type',
          items: {
            '1': 'employees.per_month'.tr(context),
            '0': 'employees.none'.tr(context),
          },
          icon: Icons.receipt_long_rounded,
        ),
        _buildTextField(
          label: 'employees.worklog_target'.tr(context),
          key: 'worklog',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(
            Icons.assignment_turned_in_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildDropdown(
          label: 'employees.status_target_worklog'.tr(context),
          key: 'worklog_active',
          items: {
            '1': 'main.active'.tr(context),
            '0': 'main.inactive'.tr(context),
          },
          icon: Icons.toggle_on_rounded,
        ),
        _buildDateField(
          label: 'profile.contract_date'.tr(context),
          key: 'date_of_joining',
          prefixIcon: const Icon(
            Icons.calendar_today_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildDateField(
          label: 'profile.contract_end'.tr(context),
          key: 'date_of_leaving',
          prefixIcon: const Icon(
            Icons.event_busy_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'employees.leave_categories'.tr(context),
          key: 'leave_categories',
          prefixIcon: const Icon(
            Icons.beach_access_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
      ];
    } else if (widget.section == 'pekerjaan') {
      return [
        _buildApiDropdown(
          label: 'profile.department'.tr(context),
          key: 'department_id',
          items: _departments,
          idKey: 'department_id',
          nameKey: 'department_name',
          icon: Icons.business_rounded,
        ),
        _buildApiDropdown(
          label: 'profile.designation'.tr(context),
          key: 'designation_id',
          items: _designations,
          idKey: 'designation_id',
          nameKey: 'designation_name',
          icon: Icons.work_rounded,
        ),
        _buildApiDropdown(
          label: 'profile.office_shift'.tr(context),
          key: 'office_shift_id',
          items: _shifts,
          idKey: 'office_shift_id',
          nameKey: 'shift_name',
          icon: Icons.access_time_filled_rounded,
        ),
        _buildDropdown(
          label: 'employees.status_work_label'.tr(context),
          key: 'status_work',
          items: {
            '1': 'employees.status_work_list.contract'.tr(context),
            '2': 'employees.status_work_list.probation'.tr(context),
            '3': 'employees.status_work_list.trainee'.tr(context),
            '4': 'employees.status_work_list.permanent'.tr(context),
            '5': 'employees.status_work_list.freelance'.tr(context),
          },
          icon: Icons.badge_rounded,
        ),
      ];
    } else if (widget.section == 'pribadi') {
      return [
        _buildDateField(
          label: 'profile.dob'.tr(context),
          key: 'date_of_birth',
          prefixIcon: const Icon(
            Icons.cake_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildDropdown(
          label: 'profile.gender'.tr(context),
          key: 'gender',
          items: {'1': 'main.male'.tr(context), '2': 'main.female'.tr(context)},
          icon: Icons.people_rounded,
        ),
        _buildDropdown(
          label: 'profile.marital_status'.tr(context),
          key: 'marital_status',
          items: {
            '0': 'profile.single'.tr(context),
            '1': 'profile.married'.tr(context),
            '2': 'profile.widowed'.tr(context),
            '3': 'profile.separated'.tr(context),
          },
          icon: Icons.favorite_rounded,
        ),
        _buildApiDropdown(
          label: 'profile.religion'.tr(context),
          key: 'religion_id',
          items: _religions,
          idKey: 'constants_id',
          nameKey: 'category_name',
          icon: Icons.mosque_rounded,
        ),
        _buildTextField(
          label: 'profile.blood_group'.tr(context),
          key: 'blood_group',
          prefixIcon: const Icon(
            Icons.bloodtype_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              Text(
                'employees.bank_info'.tr(context).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Divider(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
              ),
            ],
          ),
        ),
        _buildTextField(
          label: 'profile.bank_name'.tr(context),
          key: 'bank_name',
          prefixIcon: const Icon(
            Icons.account_balance_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.account_title'.tr(context),
          key: 'account_title',
          prefixIcon: const Icon(
            Icons.person_pin_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.account_number'.tr(context),
          key: 'account_number',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(
            Icons.numbers_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.swift_code'.tr(context),
          key: 'swift_code',
          prefixIcon: const Icon(
            Icons.speed_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.bank_branch'.tr(context),
          key: 'bank_branch',
          prefixIcon: const Icon(
            Icons.location_on_rounded,
            size: 20,
            color: Color(0xFF7E57C2),
          ),
        ),
      ];
    } else if (widget.section == 'riwayat') {
      return [
        _buildListManager(
          title: 'employees.work_exp'.tr(context).toUpperCase(),
          items: widget.employeeData['experience'] as List? ?? [],
          onAdd: () => _showAddExperienceDialog(),
          onDelete: (id) =>
              _deleteListItem('delete_experience', {'experience_id': id}),
          subtitle: (item) => '${item['company_name']} - ${item['post']}',
          isDark: isDark,
        ),
        const SizedBox(height: 40),
        _buildListManager(
          title: 'employees.education'.tr(context).toUpperCase(),
          items: widget.employeeData['education'] as List? ?? [],
          onAdd: () => _showAddEducationDialog(),
          onDelete: (id) =>
              _deleteListItem('delete_education', {'education_id': id}),
          subtitle: (item) =>
              '${item['school_university']} - ${item['education_level']}',
          isDark: isDark,
        ),
      ];
    } else if (widget.section == 'dokumen') {
      return [
        _buildListManager(
          title: 'employees.emp_docs'.tr(context).toUpperCase(),
          items: widget.employeeData['documents'] as List? ?? [],
          onAdd: () => _showAddDocumentDialog(),
          onDelete: (id) =>
              _deleteListItem('delete_user_document', {'document_id': id}),
          subtitle: (item) =>
              '${item['document_name']} (${item['document_type']})',
          isDark: isDark,
        ),
      ];
    }
    return [Text('employees.form.no_fields'.tr(context))];
  }

  Widget _buildTextField({
    required String label,
    required String key,
    TextInputType? keyboardType,
    Widget? prefixIcon,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Padding(padding: const EdgeInsets.all(12), child: prefixIcon)
              : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String key,
    Widget? prefixIcon,
  }) {
    return _buildTextField(
      label: label,
      key: key,
      readOnly: true,
      prefixIcon: prefixIcon,
      suffixIcon: const Icon(
        Icons.calendar_month_rounded,
        size: 20,
        color: Color(0xFF7E57C2),
      ),
      onTap: () async {
        DateTime initialDate = DateTime.now();
        if (_controllers[key]!.text.isNotEmpty) {
          try {
            initialDate = DateTime.parse(_controllers[key]!.text);
          } catch (_) {}
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() {
            _controllers[key]!.text =
                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          });
        }
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String key,
    required Map<String, String> items,
    IconData? icon,
  }) {
    final String currentId = _controllers[key]!.text;
    final String selectedName = items[currentId] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SearchableDropdown(
        label: label,
        value: selectedName,
        icon: icon,
        options: items.entries
            .map((e) => {'id': e.key, 'name': e.value})
            .toList(),
        onSelected: (id) => setState(() => _controllers[key]!.text = id),
      ),
    );
  }

  Widget _buildApiDropdown({
    required String label,
    required String key,
    required List<dynamic> items,
    required String idKey,
    required String nameKey,
    IconData? icon,
  }) {
    final String currentId = _controllers[key]!.text;
    final dynamic selectedItem = items.firstWhere(
      (e) => e[idKey].toString() == currentId,
      orElse: () => null,
    );
    final String selectedName = selectedItem != null
        ? selectedItem[nameKey].toString()
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SearchableDropdown(
        label: label,
        value: selectedName,
        icon: icon,
        options: items
            .map(
              (e) => {'id': e[idKey].toString(), 'name': e[nameKey].toString()},
            )
            .toList(),
        onSelected: (id) => setState(() => _controllers[key]!.text = id),
      ),
    );
  }

  Widget _buildListManager({
    required String title,
    required List<dynamic> items,
    required VoidCallback onAdd,
    required Function(dynamic) onDelete,
    required String Function(dynamic) subtitle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            IconButton(
              onPressed: onAdd,
              icon: Icon(
                Icons.add_circle_rounded,
                color: _primaryColor,
                size: 28,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  color: Colors.grey.withOpacity(0.5),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'attendance.no_data'.tr(context),
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final idKey = item.containsKey('experience_id')
                  ? 'experience_id'
                  : item.containsKey('education_id')
                  ? 'education_id'
                  : item.containsKey('id')
                  ? 'id'
                  : 'document_id';

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.containsKey('experience_id')
                          ? Icons.work_outline_rounded
                          : item.containsKey('education_id')
                          ? Icons.school_outlined
                          : Icons.description_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    subtitle(item),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    onPressed: () => onDelete(item[idKey]),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _deleteListItem(
    String endpoint,
    Map<String, String> body,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('main.confirm'.tr(context)),
        content: Text('main.confirm_delete'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('main.cancel'.tr(context)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'main.delete'.tr(context),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/$endpoint'),
        body: body,
      );
      if (!mounted) return;
      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (mounted) Navigator.pop(context, true); // Refresh detail
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddExperienceDialog() {
    final companyController = TextEditingController();
    final postController = TextEditingController();
    final fromController = TextEditingController();
    final toController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('employees.work_exp'.tr(context)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyController,
                decoration: InputDecoration(
                  labelText: 'employees.form.company'.tr(context),
                ),
              ),
              TextField(
                controller: postController,
                decoration: InputDecoration(
                  labelText: 'employees.form.post'.tr(context),
                ),
              ),
              TextField(
                controller: fromController,
                decoration: InputDecoration(
                  labelText: 'employees.form.from_year'.tr(context),
                ),
              ),
              TextField(
                controller: toController,
                decoration: InputDecoration(
                  labelText: 'employees.form.to_year'.tr(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('main.cancel'.tr(context)),
          ),
          TextButton(
            onPressed: () => _addListItem('add_experience', {
              'user_id': widget.employeeData['user_info']['user_id'].toString(),
              'company_name': companyController.text,
              'post': postController.text,
              'from_year': fromController.text,
              'to_year': toController.text,
              'description': '',
            }),
            child: Text('main.save'.tr(context)),
          ),
        ],
      ),
    );
  }

  void _showAddEducationDialog() {
    final schoolController = TextEditingController();
    final levelController = TextEditingController();
    final fromController = TextEditingController();
    final toController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('employees.education'.tr(context)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: schoolController,
                decoration: InputDecoration(
                  labelText: 'employees.form.school_uni'.tr(context),
                ),
              ),
              TextField(
                controller: levelController,
                decoration: InputDecoration(
                  labelText: 'employees.form.education_level'.tr(context),
                ),
              ),
              TextField(
                controller: fromController,
                decoration: InputDecoration(
                  labelText: 'employees.form.from_year'.tr(context),
                ),
              ),
              TextField(
                controller: toController,
                decoration: InputDecoration(
                  labelText: 'employees.form.to_year'.tr(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('main.cancel'.tr(context)),
          ),
          TextButton(
            onPressed: () => _addListItem('add_education', {
              'user_id': widget.employeeData['user_info']['user_id'].toString(),
              'school_university': schoolController.text,
              'education_level': levelController.text,
              'from_year': fromController.text,
              'to_year': toController.text,
            }),
            child: Text('main.save'.tr(context)),
          ),
        ],
      ),
    );
  }

  void _showAddDocumentDialog() {
    final titleController = TextEditingController();
    final typeController = TextEditingController();
    PlatformFile? selectedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('employees.emp_docs'.tr(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'employees.form.doc_name'.tr(context),
                  ),
                ),
                TextField(
                  controller: typeController,
                  decoration: InputDecoration(
                    labelText: 'employees.form.doc_type'.tr(context),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform
                        .pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'jpg',
                            'jpeg',
                            'png',
                            'pdf',
                            'doc',
                            'docx',
                          ],
                        );
                    if (result != null) {
                      setDialogState(() {
                        selectedFile = result.files.single;
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    selectedFile != null
                        ? selectedFile!.name
                        : 'employees.form.select_file'.tr(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('main.cancel'.tr(context)),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isEmpty ||
                    typeController.text.isEmpty ||
                    selectedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'employees.form.fill_all_fields'.tr(context),
                      ),
                    ),
                  );
                  return;
                }
                _uploadDocument(
                  titleController.text,
                  typeController.text,
                  selectedFile!,
                );
              },
              child: Text('main.save'.tr(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocument(
    String name,
    String type,
    PlatformFile file,
  ) async {
    Navigator.pop(context); // Close dialog
    setState(() => _isSaving = true);
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}/add_user_document',
      );
      var request = http.MultipartRequest('POST', url);

      request.fields['user_id'] = widget.employeeData['user_info']['user_id']
          .toString();
      request.fields['document_name'] = name;
      request.fields['document_type'] = type;

      request.files.add(
        await http.MultipartFile.fromPath(
          'document_file',
          file.path!,
          filename: file.name,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;
      var data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) Navigator.pop(context, true); // Refresh detail
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${data['message']}')));
        }
      }
    } catch (e) {
      debugPrint('Error uploading document: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addListItem(String endpoint, Map<String, String> body) async {
    Navigator.pop(context); // Close dialog
    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/$endpoint'),
        body: body,
      );
      if (!mounted) return;
      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (mounted) Navigator.pop(context, true); // Refresh
      }
    } catch (e) {
      debugPrint('Error adding item: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }
}
