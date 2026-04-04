import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../localization/app_localizations.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/secondary_app_bar.dart';

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
  File? _image;
  final _picker = ImagePicker();

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
      if (!mounted) return;
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
      if (!mounted) return;
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _cropImage(pickedFile.path);
    }
  }

  Future<void> _cropImage(String filePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: filePath,
      maxHeight: 1024,
      maxWidth: 1024,
      compressQuality: 70,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'profile.edit_photo'.tr(context),
          toolbarColor: const Color(0xFF7E57C2),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'profile.edit_photo'.tr(context),
          cancelButtonTitle: 'main.cancel'.tr(context),
          doneButtonTitle: 'main.save'.tr(context),
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      if (!mounted) return;
      setState(() {
        _image = File(croppedFile.path);
      });
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
        text: basic['nationality']?.toString() ?? '',
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
            SnackBar(content: Text('profile.update_success'.tr(context))),
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
                  args: {'message': data['message'].toString()},
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile.conn_error'.tr(context))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveHeaderSection() async {
    if (!_formKey.currentState!.validate()) return;

    _controllers['first_name']!.text = _controllers['first_name']!.text
        .toUpperCase();
    _controllers['last_name']!.text = _controllers['last_name']!.text
        .toUpperCase();

    setState(() => _isSaving = true);

    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      const url = 'https://foxgeen.com/HRIS/mobileapi/update_profile';

      var request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['user_id'] = userId.toString();
      request.fields['section'] = widget.section;

      _controllers.forEach((key, controller) {
        request.fields[key] = controller.text;
      });

      if (_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_photo', _image!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('profile.update_success'.tr(context))),
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
                  args: {'message': data['message'].toString()},
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile.conn_error'.tr(context))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getPageTitle(BuildContext context) {
    switch (widget.section) {
      case 'basic':
        return 'profile.edit_basic'.tr(context);
      case 'personal':
        return 'profile.edit_personal'.tr(context);
      case 'bank':
        return 'profile.edit_bank'.tr(context);
      default:
        return 'profile.edit_profile'.tr(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(title: _getPageTitle(context)),
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
            color: Theme.of(context).dividerColor.withOpacity(0.1),
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
            border: Border.all(
              color: const Color(0xFF7E57C2).withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7E57C2).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSaving
                ? null
                : (widget.section == 'header'
                      ? _saveHeaderSection
                      : _saveProfile),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
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
                    'profile.save'.tr(context).toUpperCase(),
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
    if (widget.section == 'header') {
      return [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF7E57C2).withOpacity(0.2),
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.light
                            ? const Color(0xFFF3F6FF)
                            : Theme.of(context).cardColor,
                        backgroundImage: _image != null
                            ? FileImage(_image!)
                            : (widget.profileData['basic_info']?['profile_photo'] !=
                                          null &&
                                      widget
                                          .profileData['basic_info']['profile_photo']
                                          .toString()
                                          .isNotEmpty
                                  ? NetworkImage(
                                      'https://foxgeen.com/HRIS/public/uploads/users/thumb/${widget.profileData['basic_info']['profile_photo']}',
                                    )
                                  : null),
                        child:
                            _image == null &&
                                (widget.profileData['basic_info']?['profile_photo'] ==
                                        null ||
                                    widget
                                        .profileData['basic_info']['profile_photo']
                                        .toString()
                                        .isEmpty)
                            ? const Icon(
                                Icons.person_outline,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF7E57C2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'profile.edit_photo'.tr(context),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7E57C2),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          label: 'profile.first_name'.tr(context),
          controller: _controllers['first_name']!,
          prefixIcon: const Icon(
            Icons.person_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          required: true,
          validator: (v) => v!.isEmpty ? 'profile.required'.tr(context) : null,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
        ),
        _buildTextField(
          label: 'profile.last_name'.tr(context),
          controller: _controllers['last_name']!,
          prefixIcon: const Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
        ),
        _buildTextField(
          label: 'profile.email'.tr(context),
          controller: _controllers['email']!,
          prefixIcon: const Icon(
            Icons.email_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          required: true,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v!.isEmpty ? 'profile.required'.tr(context) : null,
        ),
        _buildTextField(
          label: 'profile.phone'.tr(context),
          controller: _controllers['contact_number']!,
          prefixIcon: const Icon(
            Icons.phone_android_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          keyboardType: TextInputType.phone,
        ),
      ];
    } else if (widget.section == 'basic') {
      return [
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: _buildTextField(
              label: 'profile.dob'.tr(context),
              controller: _controllers['date_of_birth']!,
              prefixIcon: const Icon(
                Icons.cake_rounded,
                size: 18,
                color: Color(0xFF7E57C2),
              ),
              suffixIcon: const Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: Color(0xFF7E57C2),
              ),
            ),
          ),
        ),
        _buildDropdownField(
          label: 'profile.gender'.tr(context),
          value: _controllers['gender']!.text,
          icon: Icons.people_rounded,
          items: {
            '1': 'profile.male'.tr(context),
            '2': 'profile.female'.tr(context),
          },
          onChanged: (v) => setState(() => _controllers['gender']!.text = v!),
        ),
        _buildDropdownField(
          label: 'profile.marital_status'.tr(context),
          value: _controllers['marital_status']!.text,
          icon: Icons.favorite_rounded,
          items: {
            '0': 'profile.single'.tr(context),
            '1': 'profile.married'.tr(context),
            '2': 'profile.widowed'.tr(context),
            '3': 'profile.separated'.tr(context),
          },
          onChanged: (v) =>
              setState(() => _controllers['marital_status']!.text = v!),
        ),
        _buildDropdownField(
          label: 'profile.religion'.tr(context),
          value: _controllers['religion_id']!.text,
          icon: Icons.mosque_rounded,
          items: {
            '': 'profile.select_religion'.tr(context),
            '23': 'profile.islam'.tr(context),
            '20': 'profile.christianity'.tr(context),
            '19': 'profile.buddhism'.tr(context),
            '22': 'profile.hinduism'.tr(context),
            '21': 'profile.humanism'.tr(context),
          },
          onChanged: (v) =>
              setState(() => _controllers['religion_id']!.text = v!),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'profile.blood_group'.tr(context),
          controller: _controllers['blood_group']!,
          prefixIcon: const Icon(
            Icons.bloodtype_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.nationality'.tr(context),
          controller: _controllers['nationality']!,
          prefixIcon: const Icon(
            Icons.flag_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.address'.tr(context),
          controller: _controllers['address_1']!,
          prefixIcon: const Icon(
            Icons.home_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          maxLines: 2,
        ),
        _buildLocationDropdown(
          label: 'profile.state_province'.tr(context),
          items: _provinces,
          currentValue: _controllers['state']!.text,
          isLoading: _isLoadingProvinces,
          icon: Icons.map_rounded,
          onChanged: (val, name) {
            setState(() {
              _controllers['state']!.text = name;
            });
            _fetchRegencies(val);
          },
        ),
        _buildLocationDropdown(
          label: 'profile.city_regency'.tr(context),
          items: _regencies,
          currentValue: _controllers['city']!.text,
          isLoading: _isLoadingRegencies,
          enabled: _regencies.isNotEmpty,
          icon: Icons.location_city_rounded,
          hint: _controllers['state']!.text.isEmpty
              ? 'profile.select_state_first'.tr(context)
              : 'profile.select_city'.tr(context),
          onChanged: (val, name) {
            setState(() {
              _controllers['city']!.text = name;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'profile.zip_code'.tr(context),
          controller: _controllers['zipcode']!,
          prefixIcon: const Icon(
            Icons.pin_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          keyboardType: TextInputType.number,
        ),
      ];
    } else if (widget.section == 'personal') {
      return [
        _buildTextField(
          label: 'profile.bio'.tr(context),
          controller: _controllers['bio']!,
          prefixIcon: const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          maxLines: 3,
        ),
        _buildTextField(
          label: 'profile.experience'.tr(context),
          controller: _controllers['experience']!,
          prefixIcon: const Icon(
            Icons.work_outline_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          maxLines: 3,
        ),
        _buildTextField(
          label: 'profile.fb_url'.tr(context),
          controller: _controllers['fb_profile']!,
          prefixIcon: const FaIcon(
            FontAwesomeIcons.facebook,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.linkedin_url'.tr(context),
          controller: _controllers['linkedin_profile']!,
          prefixIcon: const FaIcon(
            FontAwesomeIcons.linkedin,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
      ];
    } else if (widget.section == 'bank') {
      return [
        _buildTextField(
          label: 'profile.account_title'.tr(context),
          controller: _controllers['account_title']!,
          prefixIcon: const Icon(
            Icons.person_pin_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.account_number'.tr(context),
          controller: _controllers['account_number']!,
          prefixIcon: const Icon(
            Icons.numbers_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          keyboardType: TextInputType.number,
        ),
        _buildTextField(
          label: 'profile.bank_name'.tr(context),
          controller: _controllers['bank_name']!,
          prefixIcon: const Icon(
            Icons.account_balance_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.iban'.tr(context),
          controller: _controllers['iban']!,
          prefixIcon: const Icon(
            Icons.public_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.swift_code'.tr(context),
          controller: _controllers['swift_code']!,
          prefixIcon: const Icon(
            Icons.speed_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
        ),
        _buildTextField(
          label: 'profile.bank_branch'.tr(context),
          controller: _controllers['bank_branch']!,
          prefixIcon: const Icon(
            Icons.location_on_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
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
    Widget? prefixIcon,
    bool required = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Padding(padding: const EdgeInsets.all(12), child: prefixIcon)
              : null,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey[200]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey[200]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
    IconData? icon,
  }) {
    final String selectedName = items[value] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SearchableDropdown(
        label: label,
        value: selectedName,
        icon: icon,
        options: items.entries
            .map((e) => {'id': e.key, 'name': e.value})
            .toList(),
        onSelected: (id) => onChanged(id),
      ),
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
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SearchableDropdown(
        label: label,
        value: currentValue,
        icon: icon,
        placeholder: isLoading
            ? 'profile.loading'.tr(context)
            : (hint ??
                  'profile.select_item'.tr(context, args: {'item': label})),
        options: items
            .map((e) => {'id': e['id'].toString(), 'name': e['name'] as String})
            .toList(),
        onSelected: (id) {
          final item = items.firstWhere((e) => e['id'].toString() == id);
          onChanged(id, item['name'] as String);
        },
      ),
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
