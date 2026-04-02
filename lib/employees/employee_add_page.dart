import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../localization/app_localizations.dart';
import '../widgets/searchable_dropdown.dart';

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
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_employee_form_data'),
        body: {'user_id': userId},
      );
      final data = json.decode(response.body);
      if (data['status'] == true) {
        setState(() {
          _controllers['employee_id']!.text = data['generated_employee_id']?.toString() ?? '';
          _roles = data['roles'] ?? [];
          _departments = data['departments'] ?? [];
          _designations = data['designations'] ?? [];
          _shifts = data['office_shifts'] ?? [];
          if (_roles.isNotEmpty) _controllers['role']!.text = _roles.first['role_id'].toString();
          if (_departments.isNotEmpty) _controllers['department_id']!.text = _departments.first['department_id'].toString();
          if (_designations.isNotEmpty) _controllers['designation_id']!.text = _designations.first['designation_id'].toString();
          if (_shifts.isNotEmpty) _controllers['office_shift_id']!.text = _shifts.first['office_shift_id'].toString();
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
      final url = Uri.parse('https://foxgeen.com/HRIS/mobileapi/add_employee');
      final request = http.MultipartRequest('POST', url);
      request.fields['company_id'] = companyId;
      request.fields['user_id'] = creatorId;
      _controllers.forEach((key, controller) {
        request.fields[key] = controller.text;
      });
      if (_selectedProfileImage != null) {
        request.files.add(await http.MultipartFile.fromPath('file', _selectedProfileImage!.path!, filename: _selectedProfileImage!.name));
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('employees.save_success'.tr(context))));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('main.error_with_msg'.tr(context, args: {'message': data['message']}))));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('employees.add_employee'.tr(context), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), color: _primaryColor, onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoadingLookups 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildFormFields()),
            ),
          ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isSaving 
            ? const SizedBox(
                height: 24, 
                width: 24, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
            : Text('main.save'.tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    return [
      _buildProfilePicturePicker(),
      _buildSectionTitle('employees.sections.profile'.tr(context)),
      _buildTextField(label: 'employees.first_name'.tr(context), key: 'first_name', textCapitalization: TextCapitalization.words, requiredField: true),
      _buildTextField(label: 'employees.last_name'.tr(context), key: 'last_name', textCapitalization: TextCapitalization.words),
      _buildTextField(label: 'employees.employee_id'.tr(context), key: 'employee_id', readOnly: true),
      _buildTextField(label: 'employees.contact_number'.tr(context), key: 'contact_number', keyboardType: TextInputType.phone),
      _buildDropdown(label: 'employees.gender'.tr(context), key: 'gender', items: {'1': 'main.male'.tr(context), '2': 'main.female'.tr(context)}),
      _buildSectionTitle('employees.sections.account'.tr(context)),
      _buildTextField(label: 'employees.email'.tr(context), key: 'email', keyboardType: TextInputType.emailAddress, requiredField: true),
      _buildTextField(label: 'employees.username'.tr(context), key: 'username', requiredField: true),
      _buildTextField(label: 'employees.password'.tr(context), key: 'password', requiredField: true),
      _buildSectionTitle('employees.sections.work_details'.tr(context)),
      _buildDropdown(
        label: 'employees.status_work_label'.tr(context), 
        key: 'status_work', 
        items: {
          '1': 'employees.status_work_list.contract'.tr(context), 
          '2': 'employees.status_work_list.probation'.tr(context), 
          '3': 'employees.status_work_list.trainee'.tr(context), 
          '4': 'employees.status_work_list.permanent'.tr(context), 
          '5': 'employees.status_work_list.freelance'.tr(context)
        }
      ),
      _buildApiDropdown(label: 'employees.office_shift'.tr(context), key: 'office_shift_id', items: _shifts, idKey: 'office_shift_id', nameKey: 'shift_name'),
      _buildApiDropdown(label: 'employees.role'.tr(context), key: 'role', items: _roles, idKey: 'role_id', nameKey: 'role_name'),
      _buildApiDropdown(label: 'employees.department'.tr(context), key: 'department_id', items: _departments, idKey: 'department_id', nameKey: 'department_name'),
      _buildApiDropdown(label: 'employees.designation'.tr(context), key: 'designation_id', items: _designations, idKey: 'designation_id', nameKey: 'designation_name'),
      _buildSectionTitle('employees.sections.salary_worklog'.tr(context)),
      _buildTextField(label: 'employees.basic_salary'.tr(context), key: 'basic_salary', keyboardType: TextInputType.number),
      _buildTextField(label: 'employees.hourly_rate'.tr(context), key: 'hourly_rate', keyboardType: TextInputType.number),
      _buildDropdown(label: 'employees.payslip_type'.tr(context), key: 'salay_type', items: {'1': 'employees.per_month'.tr(context), '0': 'employees.none'.tr(context)}),
      _buildTextField(label: 'employees.work_log_hours'.tr(context), key: 'worklog', keyboardType: TextInputType.number),
      _buildDropdown(label: 'employees.status_target_worklog'.tr(context), key: 'worklog_active', items: {'1': 'main.active'.tr(context), '0': 'main.inactive'.tr(context)}),
      const SizedBox(height: 50),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildProfilePicturePicker() {
    return Center(
      child: Column(children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: _primaryColor.withOpacity(0.1),
          backgroundImage: _selectedProfileImage != null && _selectedProfileImage!.path != null 
              ? FileImage(File(_selectedProfileImage!.path!)) 
              : const NetworkImage('https://foxgeen.com/HRIS/public/uploads/clients/default/default_formal.webp') as ImageProvider,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
            if (result != null) setState(() => _selectedProfileImage = result.files.single);
          },
          icon: const Icon(Icons.camera_alt),
          label: Text('employees.form.select_file'.tr(context)),
        ),
      ]),
    );
  }

  Widget _buildTextField({required String label, required String key, TextInputType? keyboardType, bool readOnly = false, TextCapitalization textCapitalization = TextCapitalization.none, bool requiredField = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label + (requiredField ? ' *' : ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controllers[key],
          keyboardType: keyboardType,
          readOnly: readOnly,
          textCapitalization: textCapitalization,
          decoration: _inputDecoration(),
          validator: requiredField ? (val) => (val == null || val.isEmpty) ? 'Required' : null : null,
        ),
      ]),
    );
  }

  Widget _buildDropdown({required String label, required String key, required Map<String, String> items}) {
    final String currentId = _controllers[key]!.text;
    final String selectedName = items[currentId] ?? items.values.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SearchableDropdown(
        label: label,
        value: selectedName,
        options: items.entries.map((e) => {'id': e.key, 'name': e.value}).toList(),
        onSelected: (id) => setState(() => _controllers[key]!.text = id),
      ),
    );
  }

  Widget _buildApiDropdown({required String label, required String key, required List<dynamic> items, required String idKey, required String nameKey}) {
    final String currentId = _controllers[key]!.text;
    final dynamic selectedItem = items.firstWhere(
      (e) => e[idKey].toString() == currentId,
      orElse: () => null,
    );
    final String selectedName = selectedItem != null ? selectedItem[nameKey].toString() : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SearchableDropdown(
        label: label,
        value: selectedName,
        options: items.map((e) => {
          'id': e[idKey].toString(),
          'name': e[nameKey].toString(),
        }).toList(),
        onSelected: (id) => setState(() => _controllers[key]!.text = id),
      ),
    );
  }
}
