import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';
import '../widgets/side_drawer.dart';
import 'models/job_desk_model.dart';
import 'models/designation_model.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/custom_snackbar.dart';

class JobDeskPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const JobDeskPage({super.key, required this.userData});

  @override
  State<JobDeskPage> createState() => _JobDeskPageState();
}

class _JobDeskPageState extends State<JobDeskPage> {
  final Color _defaultPrimaryColor = const Color(0xFF7E57C2);
  bool _isLoading = true;
  List<JobDesk> _jobDesks = [];
  List<DesignationStat> _designations = [];
  int _selectedDesignationId = 0; // 0 means "All"
  String? _error;

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedHexColor = "#673AB7";
  int? _formDesignationId;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchJobDesks();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1') return true;
    final dynamic resources = widget.userData['role_resources'];
    if (resources == null || resources == '') return false;
    
    if (resources is String) {
      final List<String> resourceList = resources.split(',').map((e) => e.trim()).toList();
      return resourceList.contains(resource);
    }
    
    if (resources is List) {
      return resources.any((r) => r is Map ? r['resource_slug'] == resource : r.toString() == resource);
    }
    
    return false;
  }

  void _confirmDelete(JobDesk jobDesk) {
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
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'job_desk.confirm_delete_title'.tr(context),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'job_desk.confirm_delete_msg'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'job_desk.btn_cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteJobDesk(jobDesk.id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'main.delete'.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
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

  Future<void> _deleteJobDesk(int id) async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = Uri.parse('${AppConstants.baseUrl}/delete_jobdesk');
      
      final response = await http.post(url, body: {
        'user_id': userId.toString(),
        'jobdesk_id': id.toString(),
      });

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          if (mounted) {
            CustomSnackBar.showSuccess(context, 'job_desk.success_delete'.tr(context));
            _fetchJobDesks();
          }
        } else {
          throw result['message'] ?? 'Unknown error';
        }
      } else {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(context, 'job_desk.failed_delete'.tr(context) + ': $e');
      }
    }
  }

  Future<void> _fetchJobDesks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = Uri.parse(
        '${AppConstants.baseUrl}/get_jobdesks?user_id=$userId'
        '${_selectedDesignationId != 0 ? '&designation_id=$_selectedDesignationId' : ''}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          final List<dynamic> data = result['data'] ?? [];
          final List<dynamic> desigData = result['designations'] ?? [];

          if (mounted) {
            setState(() {
              _jobDesks = data.map((json) => JobDesk.fromJson(json)).toList();
              _designations =
                  desigData.map((json) => DesignationStat.fromJson(json)).toList();
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _error = result['message'] ?? 'Failed to load job desk';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Server error: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return _defaultPrimaryColor;
    }
  }

  Color _getDesignationColor(String name) {
    final cleanName = name.toUpperCase();
    if (cleanName.contains('ADMIN')) return _defaultPrimaryColor; // Use primary purple for Admin
    if (cleanName.contains('COURIER')) return const Color(0xFF90CAF9); // Soft Blue
    if (cleanName.contains('STRATEGIC')) return const Color(0xFFA5D6A7); // Soft Green
    if (cleanName.contains('IT BUDI')) return const Color(0xFFFFCC80); // Soft Orange
    if (cleanName.contains('FINANCE')) return const Color(0xFFF48FB1); // Soft Pink
    if (cleanName.contains('HR')) return const Color(0xFF80DEEA); // Soft Cyan
    return _defaultPrimaryColor.withValues(alpha: 0.6);
  }

  void _showAddJobDeskSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Reset form
    _titleController.clear();
    _noteController.clear();
    _selectedHexColor = "#673AB7";
    _formDesignationId = _selectedDesignationId != 0 ? _selectedDesignationId : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _defaultPrimaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add_task_rounded, color: _defaultPrimaryColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'job_desk.add_job_desk'.tr(context),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Title Input
                  _buildLabel('job_desk.f_title'.tr(context)),
                  TextField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      'Job Desk Title...',
                      Icons.title_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note Input
                  _buildLabel('job_desk.f_note'.tr(context)),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      'Job Desk Note...',
                      Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Designation Dropdown
                  _buildLabel('job_desk.f_designation'.tr(context)),
                  SearchableDropdown(
                    label: 'job_desk.f_designation'.tr(context),
                    placeholder: "Search designation...",
                    value: _formDesignationId != null ? _designations.firstWhere((e) => e.id == _formDesignationId).name : "",
                    options: _designations.map((e) => {'id': e.id.toString(), 'name': e.name}).toList(),
                    onSelected: (val) {
                      setModalState(() {
                        _formDesignationId = int.parse(val);
                      });
                    },
                    icon: Icons.work_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Color Picker
                  _buildLabel('job_desk.f_color'.tr(context)),
                  Row(
                    children: [
                      _colorOption(setModalState, "#673AB7"), // Purple
                      _colorOption(setModalState, "#2196F3"), // Blue
                      _colorOption(setModalState, "#4CAF50"), // Green
                      _colorOption(setModalState, "#FF9800"), // Orange
                      _colorOption(setModalState, "#E91E63"), // Pink
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          onChanged: (val) {
                            if (val.startsWith('#') && (val.length == 7 || val.length == 4)) {
                              setModalState(() => _selectedHexColor = val);
                            }
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: "#Hex",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _saveJobDesk(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _defaultPrimaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'job_desk.btn_save'.tr(context),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'job_desk.btn_cancel'.tr(context),
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _colorOption(StateSetter setModalState, String colorHex) {
    final bool isSelected = _selectedHexColor == colorHex;
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: () => setModalState(() => _selectedHexColor = colorHex),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)] : [],
        ),
      ),
    );
  }

  Future<void> _saveJobDesk(BuildContext context) async {
    if (_titleController.text.isEmpty || _noteController.text.isEmpty || _formDesignationId == null) {
      CustomSnackBar.showError(context, 'job_desk.field_required'.tr(context));
      return;
    }

    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = Uri.parse('${AppConstants.baseUrl}/save_jobdesk');
      
      final response = await http.post(url, body: {
        'user_id': userId.toString(),
        'title': _titleController.text,
        'note': _noteController.text,
        'color': _selectedHexColor,
        'designation_id': _formDesignationId.toString(),
      });

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          if (mounted) {
            Navigator.pop(context);
            CustomSnackBar.showSuccess(context, 'job_desk.success_save'.tr(context));
            _fetchJobDesks();
          }
        } else {
          throw result['message'] ?? 'Unknown error';
        }
      } else {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'job_desk.failed_save'.tr(context) + ': $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission('mobile_jobdesk_view')) {
      return Scaffold(
        appBar: CustomAppBar(
          userData: widget.userData,
          title: 'My ISN',
        ),
        endDrawer: SideDrawer(
          userData: widget.userData, 
          activePage: 'job_desk',
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_rounded, size: 80, color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Akses Ditolak',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Anda tidak memiliki izin untuk melihat modul Job Desk. Silakan hubungi admin perusahaan Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ConnectivityWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          userData: widget.userData,
          title: 'My ISN',
        ),
        endDrawer: SideDrawer(
          userData: widget.userData, 
          activePage: 'job_desk',
        ),
        floatingActionButton: _hasPermission('mobile_jobdesk_add')
            ? FloatingActionButton.extended(
                onPressed: _showAddJobDeskSheet,
                backgroundColor: _defaultPrimaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'job_desk.add_job_desk'.tr(context),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              )
            : null,
        body: Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchJobDesks,
                  color: _defaultPrimaryColor,
                  displacement: 20,
                  child: _buildListArea(theme, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    if (_designations.isEmpty && !_isLoading) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 70,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _designations.length + 1, // +1 for "All"
        itemBuilder: (context, index) {
          final bool isAll = index == 0;
          final int designationId = isAll ? 0 : _designations[index - 1].id;
          final String name =
              isAll ? 'job_desk.all'.tr(context) : _designations[index - 1].name;
          final int count = isAll
              ? _designations.fold(0, (sum, item) => sum + item.totalCount)
              : _designations[index - 1].totalCount;

          final bool isSelected = _selectedDesignationId == designationId;
          final Color desigColor = isAll ? (isDark ? Colors.grey[600]! : Colors.grey[400]!) : _getDesignationColor(name);

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  setState(() {
                    _selectedDesignationId = designationId;
                  });
                  _fetchJobDesks();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? desigColor
                      : desigColor.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: desigColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                  border: Border.all(
                    color: isSelected 
                        ? desigColor 
                        : desigColor.withValues(alpha: isDark ? 0.3 : 0.15),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected 
                            ? Colors.white 
                            : (isDark ? desigColor.withValues(alpha: 0.9) : desigColor),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : desigColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? Colors.white : desigColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListArea(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded,
                    color: Colors.red[300], size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchJobDesks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _defaultPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('main.retry'.tr(context)),
              ),
            ],
          ),
        ),
      );
    }

    if (_jobDesks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.5,
              child: Icon(Icons.assignment_turned_in_outlined,
                  color: theme.dividerColor, size: 80),
            ),
            const SizedBox(height: 24),
            Text(
              'job_desk.empty_msg'.tr(context),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: _jobDesks.length,
      itemBuilder: (context, index) {
        final item = _jobDesks[index];
        final itemColor = _parseColor(item.color);

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.primaryColor.withValues(alpha: 0.05)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: itemColor,
                        size: 24,
                      ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (_hasPermission('mobile_jobdesk_delete'))
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _confirmDelete(item),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  expandedAlignment: Alignment.topLeft,
                  iconColor: theme.hintColor,
                  collapsedIconColor: theme.hintColor,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark 
                          ? Colors.white.withValues(alpha: 0.03) 
                          : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes_rounded,
                                  size: 14, color: theme.hintColor),
                              const SizedBox(width: 6),
                              Text(
                                'job_desk.note'.tr(context),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.hintColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.note,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
