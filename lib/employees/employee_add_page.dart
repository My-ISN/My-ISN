import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';

import '../widgets/searchable_dropdown.dart';
import '../widgets/secondary_app_bar.dart';

class EmployeeAddPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EmployeeAddPage({super.key, required this.userData});

  @override
  State<EmployeeAddPage> createState() => _EmployeeAddPageState();
}

class _EmployeeAddPageState extends State<EmployeeAddPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingLookups = true;

  final Map<String, TextEditingController> _controllers = {};
  PlatformFile? _selectedProfileImage;

  List<dynamic> _roles = [];
  List<dynamic> _departments = [];
  List<dynamic> _designations = [];
  List<dynamic> _shifts = [];

  final Color _primaryColor = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _initControllers();
    _fetchLookups();
  }

  void _initControllers() {
    _controllers['first_name'] = TextEditingController();
    _controllers['last_name'] = TextEditingController();
    _controllers['employee_id'] = TextEditingController();
    _controllers['contact_number'] = TextEditingController();
    _controllers['gender'] = TextEditingController(text: '1');
    _controllers['email'] = TextEditingController();
    _controllers['username'] = TextEditingController();
    _controllers['password'] = TextEditingController();
    _controllers['status_work'] = TextEditingController(text: '1');
    _controllers['office_shift_id'] = TextEditingController();
    _controllers['role'] = TextEditingController();
    _controllers['department_id'] = TextEditingController();
    _controllers['designation_id'] = TextEditingController();
    _controllers['basic_salary'] = TextEditingController(text: '0');
    _controllers['hourly_rate'] = TextEditingController(text: '0');
    _controllers['salay_type'] = TextEditingController(text: '1');
    _controllers['worklog'] = TextEditingController(text: '0');
    _controllers['worklog_active'] = TextEditingController(text: '0');
  }

  Future<void> _fetchLookups() async {
    setState(() => _isLoadingLookups = true);
    try {
      String userId = widget.userData['user_id']?.toString() ?? '';
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/get_employee_form_data'),
        body: {'user_id': userId},
      );
      if (!mounted) return;
      final data = json.decode(response.body);
      if (data['status'] == true) {
        setState(() {
          _controllers['employee_id']!.text =
              data['generated_employee_id']?.toString() ?? '';
          _roles = data['roles'] ?? [];
          _departments = data['departments'] ?? [];
          _designations = data['designations'] ?? [];
          _shifts = data['office_shifts'] ?? [];
          if (_roles.isNotEmpty) {
            _controllers['role']!.text = _roles.first['role_id'].toString();
          }
          if (_departments.isNotEmpty) {
            _controllers['department_id']!.text = _departments
                .first['department_id']
                .toString();
          }
          if (_designations.isNotEmpty) {
            _controllers['designation_id']!.text = _designations
                .first['designation_id']
                .toString();
          }
          if (_shifts.isNotEmpty) {
            _controllers['office_shift_id']!.text = _shifts
                .first['office_shift_id']
                .toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLookups = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      String companyId = widget.userData['company_id']?.toString() ?? '';
      String creatorId = widget.userData['user_id']?.toString() ?? '';
      final url = Uri.parse('${AppConstants.baseUrl}/add_employee');
      final request = http.MultipartRequest('POST', url);
      request.fields['company_id'] = companyId;
      request.fields['user_id'] = creatorId;
      _controllers.forEach((key, controller) {
        request.fields[key] = controller.text;
      });
      if (_selectedProfileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedProfileImage!.path!,
            filename: _selectedProfileImage!.name,
          ),
        );
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;
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
    return Scaffold(
      appBar: SecondaryAppBar(title: 'employees.add_employee'.tr(context)),
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
    );
  }

  List<Widget> _buildFormFields() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      _buildProfilePicturePicker(),
      _buildSectionTitle('employees.sections.profile'.tr(context), isDark),
      _buildTextField(
        label: 'employees.first_name'.tr(context),
        key: 'first_name',
        textCapitalization: TextCapitalization.words,
        requiredField: true,
        prefixIcon: const Icon(
          Icons.person_rounded,
          size: 20,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildTextField(
        label: 'employees.last_name'.tr(context),
        key: 'last_name',
        textCapitalization: TextCapitalization.words,
        prefixIcon: const Icon(
          Icons.person_outline_rounded,
          size: 20,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildTextField(
        label: 'employees.employee_id'.tr(context),
        key: 'employee_id',
        readOnly: true,
        prefixIcon: const Icon(
          Icons.badge_rounded,
          size: 18,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildTextField(
        label: 'employees.contact_number'.tr(context),
        key: 'contact_number',
        keyboardType: TextInputType.phone,
        prefixIcon: const Icon(
          Icons.phone_rounded,
          size: 20,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildDropdown(
        label: 'employees.gender'.tr(context),
        key: 'gender',
        items: {'1': 'main.male'.tr(context), '2': 'main.female'.tr(context)},
        icon: Icons.people_rounded,
      ),
      _buildSectionTitle('employees.sections.account'.tr(context), isDark),
      _buildTextField(
        label: 'employees.email'.tr(context),
        key: 'email',
        keyboardType: TextInputType.emailAddress,
        requiredField: true,
        prefixIcon: const Icon(
          Icons.email_rounded,
          size: 20,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildTextField(
        label: 'employees.username'.tr(context),
        key: 'username',
        requiredField: true,
        prefixIcon: const Icon(
          Icons.alternate_email_rounded,
          size: 20,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildTextField(
        label: 'employees.password'.tr(context),
        key: 'password',
        requiredField: true,
        prefixIcon: const Icon(
          Icons.lock_rounded,
          size: 20,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildSectionTitle('employees.sections.work_details'.tr(context), isDark),
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
        icon: Icons.work_history_rounded,
      ),
      _buildApiDropdown(
        label: 'employees.office_shift'.tr(context),
        key: 'office_shift_id',
        items: _shifts,
        idKey: 'office_shift_id',
        nameKey: 'shift_name',
        icon: Icons.schedule_rounded,
      ),
      _buildApiDropdown(
        label: 'employees.role'.tr(context),
        key: 'role',
        items: _roles,
        idKey: 'role_id',
        nameKey: 'role_name',
        icon: Icons.security_rounded,
      ),
      _buildApiDropdown(
        label: 'employees.department'.tr(context),
        key: 'department_id',
        items: _departments,
        idKey: 'department_id',
        nameKey: 'department_name',
        icon: Icons.business_rounded,
      ),
      _buildApiDropdown(
        label: 'employees.designation'.tr(context),
        key: 'designation_id',
        items: _designations,
        idKey: 'designation_id',
        nameKey: 'designation_name',
        icon: Icons.work_rounded,
      ),
      _buildSectionTitle(
        'employees.sections.salary_worklog'.tr(context),
        isDark,
      ),
      _buildTextField(
        label: 'employees.basic_salary'.tr(context),
        key: 'basic_salary',
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(
          Icons.payments_rounded,
          size: 20,
          color: Color(0xFF7E57C2),
        ),
      ),
      _buildTextField(
        label: 'employees.hourly_rate'.tr(context),
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
        label: 'employees.work_log_hours'.tr(context),
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
      const SizedBox(height: 50),
    ];
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
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
        ],
      ),
    );
  }

  Widget _buildProfilePicturePicker() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: _primaryColor.withValues(alpha: 0.1),
            backgroundImage:
                _selectedProfileImage != null &&
                    _selectedProfileImage!.path != null
                ? FileImage(File(_selectedProfileImage!.path!))
                : const CachedNetworkImageProvider(
                        '${AppConstants.serverRoot}/public/uploads/clients/default/default_formal.webp',
                      )
                      as ImageProvider,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result != null) {
                setState(() => _selectedProfileImage = result.files.single);
              }
            },
            icon: const Icon(Icons.camera_alt),
            label: Text('employees.form.select_file'.tr(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String key,
    TextInputType? keyboardType,
    bool readOnly = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool requiredField = false,
    Widget? prefixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: keyboardType,
        readOnly: readOnly,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Padding(padding: const EdgeInsets.all(12), child: prefixIcon)
              : null,
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
        validator: requiredField
            ? (val) => (val == null || val.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String key,
    required Map<String, String> items,
    IconData? icon,
  }) {
    final String currentId = _controllers[key]!.text;
    final String selectedName =
        items[currentId] ?? (items.isNotEmpty ? items.values.first : '');

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
}
