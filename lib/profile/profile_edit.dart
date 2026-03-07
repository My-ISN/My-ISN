import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/connectivity_wrapper.dart';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> profileData;
  final String section; // 'header', 'basic', 'personal', 'bank'

  const ProfileEditPage({
    super.key,
    required this.userData,
    required this.profileData,
    this.section = 'header',
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Location Data
  List<dynamic> _provinces = [];
  List<dynamic> _regencies = [];
  bool _isLoadingProvinces = false;
  bool _isLoadingRegencies = false;

  // Controllers
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
    if (widget.section == 'basic') {
      _fetchProvinces();
      // If there's an existing state, try to fetch regencies
      final basic = widget.profileData['basic_info'] ?? {};
      if (basic['state'] != null && basic['state'].toString().isNotEmpty) {
        // We'd need the ID to fetch regencies, but the DB stores names.
        // This is a common issue with name-based storage.
        // For now, let's assume we'll just fetch provinces and let user re-select if they want to change.
      }
    }
  }

  Future<void> _fetchProvinces() async {
    setState(() => _isLoadingProvinces = true);
    try {
      const url = 'https://foxgeen.com/HRIS/mobileapi/get_provinces';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == true) {
        setState(() => _provinces = data['data']);

        // Auto-fetch regencies if state name exists
        final stateName = _controllers['state']?.text;
        if (stateName != null && stateName.isNotEmpty) {
          final province = _provinces.firstWhere(
            (p) =>
                p['name'].toString().toLowerCase() == stateName.toLowerCase(),
            orElse: () => null,
          );
          if (province != null) {
            _fetchRegencies(province['id'].toString(), resetCity: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching provinces: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _fetchRegencies(
    String provinceId, {
    bool resetCity = true,
  }) async {
    setState(() {
      _isLoadingRegencies = true;
      _regencies = [];
      if (resetCity) _controllers['city']!.text = '';
    });
    try {
      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_regencies?province_id=$provinceId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == true) {
        setState(() => _regencies = data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching regencies: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRegencies = false);
    }
  }

  void _initControllers() {
    final basic = widget.profileData['basic_info'] ?? {};
    final personal = widget.profileData['personal_info'] ?? {};
    final bank = widget.profileData['bank_info'] ?? {};

    if (widget.section == 'header') {
      _controllers['first_name'] = TextEditingController(
        text: basic['first_name'] ?? '',
      );
      _controllers['last_name'] = TextEditingController(
        text: basic['last_name'] ?? '',
      );
      _controllers['email'] = TextEditingController(text: basic['email'] ?? '');
      _controllers['contact_number'] = TextEditingController(
        text: basic['contact_number'] ?? '',
      );
    } else if (widget.section == 'basic') {
      _controllers['date_of_birth'] = TextEditingController(
        text: basic['date_of_birth'] ?? '',
      );
      _controllers['marital_status'] = TextEditingController(
        text: basic['marital_status']?.toString() ?? '0',
      );
      _controllers['religion_id'] = TextEditingController(
        text: basic['religion_id']?.toString() ?? '',
      );
      _controllers['blood_group'] = TextEditingController(
        text: basic['blood_group'] ?? '',
      );
      _controllers['gender'] = TextEditingController(
        text: basic['gender']?.toString() ?? '1',
      );
      _controllers['nationality'] = TextEditingController(
        text: basic['nationality']?.toString() ?? 'Indonesia',
      );
      _controllers['address_1'] = TextEditingController(
        text: basic['address_1'] ?? '',
      );
      _controllers['city'] = TextEditingController(text: basic['city'] ?? '');
      _controllers['state'] = TextEditingController(text: basic['state'] ?? '');
      _controllers['zipcode'] = TextEditingController(
        text: basic['zipcode'] ?? '',
      );
    } else if (widget.section == 'personal') {
      _controllers['bio'] = TextEditingController(text: personal['bio'] ?? '');
      _controllers['experience'] = TextEditingController(
        text: personal['experience'] ?? '',
      );
      _controllers['fb_profile'] = TextEditingController(
        text: personal['fb_profile'] ?? '',
      );
      _controllers['linkedin_profile'] = TextEditingController(
        text: personal['linkedin_profile'] ?? '',
      );
    } else if (widget.section == 'bank') {
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

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.section == 'header') {
      _controllers['first_name']!.text = _controllers['first_name']!.text
          .toUpperCase();
      _controllers['last_name']!.text = _controllers['last_name']!.text
          .toUpperCase();
    }

    setState(() => _isSaving = true);

    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      const url = 'https://foxgeen.com/HRIS/mobileapi/update_profile';

      Map<String, String> body = {
        'user_id': userId.toString(),
        'section': widget.section,
      };

      _controllers.forEach((key, controller) {
        body[key] = controller.text;
      });

      final response = await http.post(Uri.parse(url), body: body);

      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${data['message']}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan. Periksa koneksi internet Anda.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getPageTitle() {
    switch (widget.section) {
      case 'basic':
        return 'Edit Basic Info';
      case 'personal':
        return 'Edit Personal Info';
      case 'bank':
        return 'Edit Bank Account';
      default:
        return 'Edit Profile';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          _getPageTitle(),
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Color(0xFF7E57C2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildFormFields(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    if (widget.section == 'header') {
      return [
        _buildTextField(
          label: 'First Name',
          controller: _controllers['first_name']!,
          validator: (v) => v!.isEmpty ? 'Required' : null,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Last Name',
          controller: _controllers['last_name']!,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Email',
          controller: _controllers['email']!,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Contact Number',
          controller: _controllers['contact_number']!,
          keyboardType: TextInputType.phone,
        ),
      ];
    } else if (widget.section == 'basic') {
      return [
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: _buildTextField(
              label: 'Date of Birth',
              controller: _controllers['date_of_birth']!,
              suffixIcon: const Icon(Icons.calendar_today, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          label: 'Gender',
          value: _controllers['gender']!.text,
          items: const {'1': 'Male', '2': 'Female'},
          onChanged: (v) => setState(() => _controllers['gender']!.text = v!),
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          label: 'Marital Status',
          value: _controllers['marital_status']!.text,
          items: const {
            '0': 'Single',
            '1': 'Married',
            '2': 'Widowed',
            '3': 'Separated',
          },
          onChanged: (v) =>
              setState(() => _controllers['marital_status']!.text = v!),
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          label: 'Religion',
          value: _controllers['religion_id']!.text,
          items: const {
            '': 'Select Religion',
            '23': 'Islam',
            '20': 'Christianity',
            '19': 'Buddhism',
            '22': 'Hinduism',
            '21': 'Humanism',
          },
          onChanged: (v) =>
              setState(() => _controllers['religion_id']!.text = v!),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Blood Group',
          controller: _controllers['blood_group']!,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Nationality',
          controller: _controllers['nationality']!,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Address',
          controller: _controllers['address_1']!,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        // State Dropdown
        _buildLocationDropdown(
          label: 'State (Province)',
          items: _provinces,
          currentValue: _controllers['state']!.text,
          isLoading: _isLoadingProvinces,
          onChanged: (val, name) {
            setState(() {
              _controllers['state']!.text = name;
            });
            _fetchRegencies(val);
          },
        ),
        const SizedBox(height: 16),
        // City Dropdown
        _buildLocationDropdown(
          label: 'City (Regency)',
          items: _regencies,
          currentValue: _controllers['city']!.text,
          isLoading: _isLoadingRegencies,
          enabled: _regencies.isNotEmpty,
          hint: _controllers['state']!.text.isEmpty
              ? 'Select state first'
              : 'Select city',
          onChanged: (val, name) {
            setState(() {
              _controllers['city']!.text = name;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Zip Code',
          controller: _controllers['zipcode']!,
          keyboardType: TextInputType.number,
        ),
      ];
    } else if (widget.section == 'personal') {
      return [
        _buildTextField(
          label: 'Bio',
          controller: _controllers['bio']!,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Experience',
          controller: _controllers['experience']!,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Facebook Profile URL',
          controller: _controllers['fb_profile']!,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'LinkedIn Profile URL',
          controller: _controllers['linkedin_profile']!,
        ),
      ];
    } else if (widget.section == 'bank') {
      return [
        _buildTextField(
          label: 'Account Title',
          controller: _controllers['account_title']!,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Account Number',
          controller: _controllers['account_number']!,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Bank Name',
          controller: _controllers['bank_name']!,
        ),
        const SizedBox(height: 16),
        _buildTextField(label: 'IBAN', controller: _controllers['iban']!),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Swift Code',
          controller: _controllers['swift_code']!,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Bank Branch',
          controller: _controllers['bank_branch']!,
        ),
      ];
    }
    return [];
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(_controllers['date_of_birth']!.text) ??
          DateTime(1995),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _controllers['date_of_birth']!.text = picked.toString().split(' ')[0];
      });
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7E57C2)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          items: items.entries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.value));
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7E57C2)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required List<dynamic> items,
    required String currentValue,
    required bool isLoading,
    required void Function(String id, String name) onChanged,
    bool enabled = true,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: items.any((e) => e['name'] == currentValue)
              ? currentValue
              : null,
          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e['name'] as String,
              onTap: () {
                onChanged(e['id'].toString(), e['name'] as String);
              },
              child: Text(e['name'] as String),
            );
          }).toList(),
          onChanged: enabled ? (val) {} : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            hintText: isLoading ? 'Loading...' : (hint ?? 'Select $label'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7E57C2)),
            ),
          ),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
