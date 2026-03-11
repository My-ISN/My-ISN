import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../localization/app_localizations.dart';

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

  // Lookup Data
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
    _controllers['employee_id'] = TextEditingController(); // read-only
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
    _controllers['salay_type'] = TextEditingController(text: '1'); // 1 = per month
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

          // set default dropdowns
          if (_roles.isNotEmpty) _controllers['role']!.text = _roles.first['role_id'].toString();
          if (_departments.isNotEmpty) _controllers['department_id']!.text = _departments.first['department_id'].toString();
          if (_designations.isNotEmpty) _controllers['designation_id']!.text = _designations.first['designation_id'].toString();
          if (_shifts.isNotEmpty) _controllers['office_shift_id']!.text = _shifts.first['office_shift_id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching add form data: $e');
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
      request.fields['user_id'] = creatorId; // For fallback
      
      _controllers.forEach((key, controller) {
        request.fields[key] = controller.text;
      });

      if (_selectedProfileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          _selectedProfileImage!.path!,
          filename: _selectedProfileImage!.name,
        ));
      }

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
            SnackBar(content: Text('main.error_with_msg'.tr(context, args: {'message': data['message']}))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CircularProgressIndicator()))
          else
            TextButton(
              onPressed: _save,
              child: Text('main.save'.tr(context), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
            ),
        ],
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
    return [
      _buildProfilePicturePicker(),
      _buildSectionTitle('Profile'),
      _buildTextField(label: 'First Name', key: 'first_name', textCapitalization: TextCapitalization.words, requiredField: true),
      _buildTextField(label: 'Last Name', key: 'last_name', textCapitalization: TextCapitalization.words),
      _buildTextField(label: 'Employee ID', key: 'employee_id', readOnly: true),
      _buildTextField(label: 'Contact Number', key: 'contact_number', keyboardType: TextInputType.phone),
      _buildDropdown(
        label: 'Gender', 
        key: 'gender', 
        items: {'1': 'Male', '2': 'Female'}
      ),
      
      _buildSectionTitle('Account'),
      _buildTextField(label: 'Email', key: 'email', keyboardType: TextInputType.emailAddress, requiredField: true),
      _buildTextField(label: 'Username', key: 'username', requiredField: true),
      _buildTextField(label: 'Password', key: 'password', requiredField: true),

      _buildSectionTitle('Work Details'),
      _buildDropdown(
        label: 'Status Work', 
        key: 'status_work', 
        items: {'1': 'Contract', '2': 'Probation', '3': 'Trainee', '4': 'Permanent', '5': 'Freelance'}
      ),
      _buildApiDropdown(
        label: 'Office Shift', 
        key: 'office_shift_id', 
        items: _shifts, 
        idKey: 'office_shift_id', 
        nameKey: 'shift_name'
      ),
      _buildApiDropdown(
        label: 'Role', 
        key: 'role', 
        items: _roles, 
        idKey: 'role_id', 
        nameKey: 'role_name'
      ),
      _buildApiDropdown(
        label: 'Department', 
        key: 'department_id', 
        items: _departments, 
        idKey: 'department_id', 
        nameKey: 'department_name'
      ),
      _buildApiDropdown(
        label: 'Designation', 
        key: 'designation_id', 
        items: _designations, 
        idKey: 'designation_id', 
        nameKey: 'designation_name'
      ),
      
      _buildSectionTitle('Salary & Worklog'),
      _buildTextField(label: 'Basic Salary', key: 'basic_salary', keyboardType: TextInputType.number),
      _buildTextField(label: 'Hourly Rate', key: 'hourly_rate', keyboardType: TextInputType.number),
      _buildDropdown(
        label: 'Payslip Type', 
        key: 'salay_type', 
        items: {'1': 'Per Month', '0': 'None'}
      ),
      _buildTextField(label: 'Work Log (Hours)', key: 'worklog', keyboardType: TextInputType.number),
      _buildDropdown(
        label: 'Status Target Worklog', 
        key: 'worklog_active', 
        items: {'1': 'Active', '0': 'Inactive'}
      ),
      const SizedBox(height: 50),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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
            backgroundColor: Colors.grey[200],
            backgroundImage: _selectedProfileImage != null 
                ? null 
                : const AssetImage('assets/images/user/avatar-placeholder.jpg'), // Fallback
            child: _selectedProfileImage != null
                ? const Icon(Icons.check, size: 50, color: Colors.green) // Just showing a check if file selected since it's a PlatformFile path without direct Image.file due to web compatibility or async loading. For mobile, we could use Image.file(File(path)) but this is safer generically.
                : null,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result != null) {
                setState(() {
                  _selectedProfileImage = result.files.single;
                });
              }
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Choose Photo'),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label + (requiredField ? ' *' : ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _controllers[key],
            keyboardType: keyboardType,
            readOnly: readOnly,
            textCapitalization: textCapitalization,
            decoration: _inputDecoration(),
            validator: requiredField ? (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({required String label, required String key, required Map<String, String> items}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: items.containsKey(_controllers[key]!.text) ? _controllers[key]!.text : items.keys.first,
            items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) => setState(() => _controllers[key]!.text = val!),
            decoration: _inputDecoration(),
          ),
        ],
      ),
    );
  }

  Widget _buildApiDropdown({
    required String label, 
    required String key, 
    required List<dynamic> items,
    required String idKey,
    required String nameKey,
  }) {
    String? currentVal = _controllers[key]!.text;
    if (!items.any((e) => e[idKey].toString() == currentVal)) {
      currentVal = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: currentVal,
            items: items.map((e) => DropdownMenuItem(value: e[idKey].toString(), child: Text(e[nameKey]))).toList(),
            onChanged: (val) => setState(() => _controllers[key]!.text = val!),
            decoration: _inputDecoration(),
          ),
        ],
      ),
    );
  }
}
