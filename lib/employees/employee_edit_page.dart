import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../localization/app_localizations.dart';

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
      _controllers['first_name'] = TextEditingController(text: info['first_name'] ?? '');
      _controllers['last_name'] = TextEditingController(text: info['last_name'] ?? '');
      _controllers['email'] = TextEditingController(text: info['email'] ?? '');
      _controllers['contact_number'] = TextEditingController(text: info['contact_number'] ?? '');
      _controllers['address_1'] = TextEditingController(text: info['address_1'] ?? '');
      _controllers['city'] = TextEditingController(text: info['city'] ?? '');
      _controllers['state'] = TextEditingController(text: info['state'] ?? '');
      _controllers['zipcode'] = TextEditingController(text: info['zipcode'] ?? '');
      _controllers['nationality'] = TextEditingController(text: info['country'] ?? '');
    } else if (widget.section == 'kontrak') {
      _controllers['basic_salary'] = TextEditingController(text: emp['basic_salary']?.toString() ?? '0');
      _controllers['hourly_rate'] = TextEditingController(text: emp['hourly_rate']?.toString() ?? '0');
      _controllers['salay_type'] = TextEditingController(text: emp['salay_type'] == 'Per Month' ? '1' : '0');
      _controllers['worklog'] = TextEditingController(text: emp['worklog']?.toString() ?? '0');
      _controllers['worklog_active'] = TextEditingController(text: emp['worklog_active']?.toString() ?? '0');
      _controllers['date_of_joining'] = TextEditingController(text: emp['date_of_joining'] ?? '');
      _controllers['date_of_leaving'] = TextEditingController(text: emp['contract_end'] ?? '');
      _controllers['leave_categories'] = TextEditingController(text: emp['leave_categories'] ?? 'all');
    } else if (widget.section == 'pekerjaan') {
      _controllers['department_id'] = TextEditingController(text: emp['department_id']?.toString() ?? '');
      _controllers['designation_id'] = TextEditingController(text: emp['designation_id']?.toString() ?? '');
      _controllers['office_shift_id'] = TextEditingController(text: emp['office_shift_id']?.toString() ?? '');
      _controllers['status_work'] = TextEditingController(text: emp['status_work']?.toString() ?? '');
    } else if (widget.section == 'pribadi') {
      _controllers['date_of_birth'] = TextEditingController(text: personal['date_of_birth'] ?? '');
      _controllers['marital_status'] = TextEditingController(text: personal['marital_status']?.toString() ?? '0');
      _controllers['religion_id'] = TextEditingController(text: personal['religion_id']?.toString() ?? '');
      _controllers['blood_group'] = TextEditingController(text: personal['blood_group'] ?? '');
      _controllers['gender'] = TextEditingController(text: info['gender_raw']?.toString() ?? '1');
      
      // Bank fields
      final bank = widget.employeeData['bank_account'] ?? {};
      _controllers['account_title'] = TextEditingController(text: bank['account_title'] ?? '');
      _controllers['account_number'] = TextEditingController(text: bank['account_number'] ?? '');
      _controllers['bank_name'] = TextEditingController(text: bank['bank_name'] ?? '');
      _controllers['iban'] = TextEditingController(text: bank['iban'] ?? '');
      _controllers['swift_code'] = TextEditingController(text: bank['swift_code'] ?? '');
      _controllers['bank_branch'] = TextEditingController(text: bank['bank_branch'] ?? '');
    }
  }

  Future<void> _fetchLookups() async {
    setState(() => _isLoadingLookups = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_departments')),
        http.get(Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_designations')),
        http.get(Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_shifts')),
        http.get(Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_religions')),
      ]);

      if (responses.every((r) => r.statusCode == 200)) {
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
      final url = Uri.parse('https://foxgeen.com/HRIS/mobileapi/update_employee');
      final request = http.MultipartRequest('POST', url);
      
      request.fields['user_id'] = widget.employeeData['user_info']['user_id'].toString();
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

  @override
  Widget build(BuildContext context) {
    String title = 'employees.edit_title'.tr(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CircularProgressIndicator()))
          else
            TextButton(
              onPressed: _save,
              child: Text('employees.save'.tr(context), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
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
    if (widget.section == 'profil') {
      return [
        _buildTextField(label: 'profile.first_name'.tr(context), key: 'first_name'),
        _buildTextField(label: 'profile.last_name'.tr(context), key: 'last_name'),
        _buildTextField(label: 'profile.email'.tr(context), key: 'email', keyboardType: TextInputType.emailAddress),
        _buildTextField(label: 'profile.phone'.tr(context), key: 'contact_number', keyboardType: TextInputType.phone),
        _buildTextField(label: 'profile.address'.tr(context), key: 'address_1'),
        _buildTextField(label: 'profile.city_regency'.tr(context), key: 'city'),
        _buildTextField(label: 'profile.state_province'.tr(context), key: 'state'),
        _buildTextField(label: 'profile.zip_code'.tr(context), key: 'zipcode'),
        _buildTextField(label: 'profile.nationality'.tr(context), key: 'nationality'),
      ];
    } else if (widget.section == 'kontrak') {
      return [
        _buildTextField(label: 'profile.basic_salary'.tr(context), key: 'basic_salary', keyboardType: TextInputType.number),
        _buildTextField(label: 'profile.hourly_rate'.tr(context), key: 'hourly_rate', keyboardType: TextInputType.number),
        _buildDropdown(
          label: 'employees.payslip_type'.tr(context), 
          key: 'salay_type', 
          items: {'1': 'employees.per_month'.tr(context), '0': 'employees.none'.tr(context)}
        ),
        _buildTextField(label: 'employees.worklog_target'.tr(context), key: 'worklog', keyboardType: TextInputType.number),
        _buildDropdown(
          label: 'employees.status_target_worklog'.tr(context), 
          key: 'worklog_active', 
          items: {
            '1': 'main.active'.tr(context), 
            '0': 'main.inactive'.tr(context)
          }
        ),
        _buildDateField(label: 'profile.contract_date'.tr(context), key: 'date_of_joining'),
        _buildDateField(label: 'profile.contract_end'.tr(context), key: 'date_of_leaving'),
        _buildTextField(label: 'employees.leave_categories'.tr(context), key: 'leave_categories'),
      ];
    } else if (widget.section == 'pekerjaan') {
      return [
        _buildApiDropdown(
          label: 'profile.department'.tr(context), 
          key: 'department_id', 
          items: _departments, 
          idKey: 'department_id', 
          nameKey: 'department_name'
        ),
        _buildApiDropdown(
          label: 'profile.designation'.tr(context), 
          key: 'designation_id', 
          items: _designations, 
          idKey: 'designation_id', 
          nameKey: 'designation_name'
        ),
        _buildApiDropdown(
          label: 'profile.office_shift'.tr(context), 
          key: 'office_shift_id', 
          items: _shifts, 
          idKey: 'office_shift_id', 
          nameKey: 'shift_name'
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
          }
        ),
      ];
    } else if (widget.section == 'pribadi') {
      return [
        _buildDateField(label: 'profile.dob'.tr(context), key: 'date_of_birth'),
        _buildDropdown(
          label: 'profile.gender'.tr(context), 
          key: 'gender', 
          items: {'1': 'main.male'.tr(context), '2': 'main.female'.tr(context)}
        ),
        _buildDropdown(
          label: 'profile.marital_status'.tr(context), 
          key: 'marital_status', 
          items: {
            '0': 'profile.single'.tr(context), 
            '1': 'profile.married'.tr(context), 
            '2': 'profile.widowed'.tr(context), 
            '3': 'profile.separated'.tr(context)
          }
        ),
        _buildApiDropdown(
          label: 'profile.religion'.tr(context), 
          key: 'religion_id', 
          items: _religions, 
          idKey: 'constants_id', 
          nameKey: 'category_name'
        ),
        _buildTextField(label: 'profile.blood_group'.tr(context), key: 'blood_group'),
        
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        ),
        Text('employees.bank_info'.tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 16),
        _buildTextField(label: 'profile.bank_name'.tr(context), key: 'bank_name'),
        _buildTextField(label: 'profile.account_title'.tr(context), key: 'account_title'),
        _buildTextField(label: 'profile.account_number'.tr(context), key: 'account_number'),
        _buildTextField(label: 'profile.swift_code'.tr(context), key: 'swift_code'),
        _buildTextField(label: 'profile.bank_branch'.tr(context), key: 'bank_branch'),
      ];
    } else if (widget.section == 'riwayat') {
      return [
        _buildListManager(
          title: 'employees.work_exp'.tr(context),
          items: widget.employeeData['experience'] as List? ?? [],
          onAdd: () => _showAddExperienceDialog(),
          onDelete: (id) => _deleteListItem('delete_experience', {'experience_id': id}),
          subtitle: (item) => '${item['company_name']} - ${item['post']}',
        ),
        const SizedBox(height: 24),
        _buildListManager(
          title: 'employees.education'.tr(context),
          items: widget.employeeData['education'] as List? ?? [],
          onAdd: () => _showAddEducationDialog(),
          onDelete: (id) => _deleteListItem('delete_education', {'education_id': id}),
          subtitle: (item) => '${item['school_university']} - ${item['education_level']}',
        ),
      ];
    } else if (widget.section == 'dokumen') {
      return [
        _buildListManager(
          title: 'employees.emp_docs'.tr(context),
          items: widget.employeeData['documents'] as List? ?? [],
          onAdd: () => _showAddDocumentDialog(),
          onDelete: (id) => _deleteListItem('delete_user_document', {'document_id': id}),
          subtitle: (item) => '${item['name']} (${item['type']})',
        ),
      ];
    }
    return [const Text('No fields available')];
  }

  Widget _buildTextField({
    required String label, 
    required String key, 
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _controllers[key],
            keyboardType: keyboardType,
            decoration: _inputDecoration(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({required String label, required String key}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _controllers[key],
            readOnly: true,
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
                  _controllers[key]!.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                });
              }
            },
            decoration: _inputDecoration().copyWith(suffixIcon: const Icon(Icons.calendar_month_outlined)),
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
            value: items.containsKey(_controllers[key]!.text) ? _controllers[key]!.text : null,
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

  Widget _buildListManager({
    required String title,
    required List<dynamic> items,
    required VoidCallback onAdd,
    required Function(dynamic) onDelete,
    required String Function(dynamic) subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: onAdd,
              icon: Icon(Icons.add_circle_outline, color: _primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('No data found', style: TextStyle(color: Colors.grey))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              // Use appropriate ID key based on the list type
              final idKey = item.containsKey('experience_id') ? 'experience_id' : 
                          item.containsKey('education_id') ? 'education_id' : 
                          item.containsKey('id') ? 'id' : 'document_id';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(subtitle(item), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => onDelete(item[idKey]),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _deleteListItem(String endpoint, Map<String, String> body) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('main.confirm'.tr(context)),
        content: Text('main.confirm_delete'.tr(context)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('main.cancel'.tr(context))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('main.delete'.tr(context), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/$endpoint'),
        body: body,
      );
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
              TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Company')),
              TextField(controller: postController, decoration: const InputDecoration(labelText: 'Post')),
              TextField(controller: fromController, decoration: const InputDecoration(labelText: 'From Year')),
              TextField(controller: toController, decoration: const InputDecoration(labelText: 'To Year')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('main.cancel'.tr(context))),
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
              TextField(controller: schoolController, decoration: const InputDecoration(labelText: 'School/Uni')),
              TextField(controller: levelController, decoration: const InputDecoration(labelText: 'Level')),
              TextField(controller: fromController, decoration: const InputDecoration(labelText: 'From Year')),
              TextField(controller: toController, decoration: const InputDecoration(labelText: 'To Year')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('main.cancel'.tr(context))),
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
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Document Name')),
                TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Document Type (e.g. Identity, Certificate)')),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
                    );
                    if (result != null) {
                      setDialogState(() {
                        selectedFile = result.files.single;
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(selectedFile != null ? selectedFile!.name : 'Select File'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('main.cancel'.tr(context))),
            TextButton(
              onPressed: () {
                if (titleController.text.isEmpty || typeController.text.isEmpty || selectedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields and select a file')));
                  return;
                }
                _uploadDocument(titleController.text, typeController.text, selectedFile!);
              },
              child: Text('main.save'.tr(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocument(String name, String type, PlatformFile file) async {
    Navigator.pop(context); // Close dialog
    setState(() => _isSaving = true);
    try {
      final url = Uri.parse('https://foxgeen.com/HRIS/mobileapi/add_user_document');
      var request = http.MultipartRequest('POST', url);
      
      request.fields['user_id'] = widget.employeeData['user_info']['user_id'].toString();
      request.fields['document_name'] = name;
      request.fields['document_type'] = type;
      
      request.files.add(await http.MultipartFile.fromPath(
        'document_file',
        file.path!,
        filename: file.name,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = json.decode(response.body);
      
      if (data['status'] == true) {
        if (mounted) Navigator.pop(context, true); // Refresh detail
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['message']}')));
      }
    } catch (e) {
      debugPrint('Error uploading document: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addListItem(String endpoint, Map<String, String> body) async {
    Navigator.pop(context); // Close dialog
    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/$endpoint'),
        body: body,
      );
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

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor)),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }
}
