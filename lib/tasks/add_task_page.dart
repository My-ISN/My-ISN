import 'package:flutter/material.dart';
import '../services/project_task_service.dart';
import '../widgets/custom_snackbar.dart';
import 'package:intl/intl.dart';
import '../widgets/secondary_app_bar.dart';
import '../widgets/searchable_dropdown.dart';
import '../localization/app_localizations.dart';

class AddTaskPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AddTaskPage({super.key, required this.userData});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final ProjectTaskService _service = ProjectTaskService();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _endDateController = TextEditingController();
  final _summaryController = TextEditingController();
  final _taskHourController = TextEditingController();
  
  List<dynamic> _projects = [];
  List<dynamic> _employees = [];
  int? _selectedProjectId;
  String _selectedProjectName = '';
  
  // Assign Member
  List<String> _selectedAssigneeIds = [];
  List<String> _selectedAssigneeNames = [];
  
  // Team
  List<String> _selectedTeamIds = [];
  List<String> _selectedTeamNames = [];
  
  bool _isLoading = true;
  bool _isSubmitting = false;

  Color get _primaryColor => const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProjects(),
      _fetchEmployees(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProjects() async {
    final result = await _service.getAllProjects();
    if (result['status'] == true) {
      if (mounted) {
        setState(() {
          _projects = result['data'] ?? [];
        });
      }
    } else {
      if (mounted) {
        CustomSnackBar.showError(context, 'tasks.fetch_projects_error'.tr(context));
      }
    }
  }

  Future<void> _fetchEmployees() async {
    final result = await _service.getEmployees();
    if (result['status'] == true) {
      if (mounted) {
        setState(() {
          _employees = result['data'] ?? [];
        });
      }
    } else {
      if (mounted) {
        CustomSnackBar.showError(context, 'tasks.fetch_staff_error'.tr(context));
      }
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showAssigneePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return _buildMultiPicker(
            title: 'tasks.select_assignee'.tr(context),
            selectedIds: _selectedAssigneeIds,
            selectedNames: _selectedAssigneeNames,
            setModalState: setModalState,
            showSelectAll: false,
          );
        },
      ),
    );
  }

  void _showTeamPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return _buildMultiPicker(
            title: 'tasks.select_team'.tr(context),
            selectedIds: _selectedTeamIds,
            selectedNames: _selectedTeamNames,
            setModalState: setModalState,
            showSelectAll: true,
          );
        },
      ),
    );
  }

  Widget _buildMultiPicker({
    required String title,
    required List<String> selectedIds,
    required List<String> selectedNames,
    required StateSetter setModalState,
    bool showSelectAll = false,
  }) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.titleLarge?.color),
                ),
                const Spacer(),
                if (showSelectAll)
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        if (selectedIds.length == _employees.length) {
                          selectedIds.clear();
                          selectedNames.clear();
                        } else {
                          selectedIds.clear();
                          selectedNames.clear();
                          for (var emp in _employees) {
                            selectedIds.add(emp['user_id'].toString());
                            selectedNames.add(emp['username'] ?? '${emp['first_name']} ${emp['last_name']}');
                          }
                        }
                      });
                      setState(() {});
                    },
                    child: Text(
                      selectedIds.length == _employees.length ? 'tasks.deselect_all'.tr(context) : 'tasks.select_all'.tr(context),
                      style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('tasks.done'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final emp = _employees[index];
                final id = emp['user_id'].toString();
                final name = emp['username'] ?? '${emp['first_name']} ${emp['last_name']}';
                final isSelected = selectedIds.contains(id);

                return CheckboxListTile(
                  value: isSelected,
                  title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(emp['role_name'] ?? '', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                  activeColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onChanged: (val) {
                    setModalState(() {
                      if (val == true) {
                        selectedIds.add(id);
                        selectedNames.add(name);
                      } else {
                        selectedIds.remove(id);
                        selectedNames.remove(name);
                      }
                    });
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedProjectId == null) {
      if (_selectedProjectId == null) {
        CustomSnackBar.showError(context, 'tasks.error_select_project'.tr(context));
      }
      return;
    }

    setState(() => _isSubmitting = true);
    
    final data = {
      'project_id': _selectedProjectId,
      'task_name': _nameController.text,
      'description': _descriptionController.text,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'summary': _summaryController.text,
      'task_hour': _taskHourController.text,
      'task_assignees': _selectedAssigneeIds.join(','),
      'assigned_to': _selectedTeamIds.join(','),
    };

    final result = await _service.addTask(data);
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['status'] == true) {
        CustomSnackBar.showSuccess(context, 'tasks.add_success'.tr(context));
        Navigator.pop(context, true);
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.add_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(title: 'tasks.add_task'.tr(context)),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(Icons.business_center_rounded, 'tasks.main_info'.tr(context)),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'tasks.task_name'.tr(context),
                      controller: _nameController,
                      hint: 'tasks.task_name_hint'.tr(context),
                      icon: Icons.title_rounded,
                      validator: (val) => val!.isEmpty ? 'tasks.validation_name'.tr(context) : null,
                    ),
                    const SizedBox(height: 20),
                    SearchableDropdown(
                      label: 'tasks.select_project'.tr(context),
                      value: _selectedProjectName,
                      icon: Icons.assignment_rounded,
                      options: _projects.map<Map<String, String>>((p) => {
                        'id': p['project_id'].toString(),
                        'name': p['title'] ?? '',
                      }).toList(),
                      onSelected: (id) {
                        final p = _projects.firstWhere((p) => p['project_id'].toString() == id);
                        setState(() {
                          _selectedProjectId = int.parse(id);
                          _selectedProjectName = p['title'] ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.group_add_rounded, 'tasks.team_members'.tr(context)),
                    const SizedBox(height: 16),
                    _buildAssigneeSelector(),
                    const SizedBox(height: 20),
                    _buildTeamSelector(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.calendar_month_rounded, 'tasks.scheduling'.tr(context)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'tasks.start_date'.tr(context),
                            controller: _startDateController,
                            hint: 'YYYY-MM-DD',
                            icon: Icons.today_rounded,
                            readOnly: true,
                            onTap: () => _selectDate(_startDateController),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            label: 'tasks.end_date'.tr(context),
                            controller: _endDateController,
                            hint: 'YYYY-MM-DD',
                            icon: Icons.event_rounded,
                            readOnly: true,
                            onTap: () => _selectDate(_endDateController),
                            validator: (val) => val!.isEmpty ? 'tasks.validation_deadline'.tr(context) : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'tasks.task_hour'.tr(context),
                      controller: _taskHourController,
                      hint: 'tasks.task_hour_hint'.tr(context),
                      icon: Icons.access_time_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.edit_note_rounded, 'tasks.details_desc'.tr(context)),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'tasks.summary'.tr(context),
                      controller: _summaryController,
                      hint: 'tasks.summary_hint'.tr(context),
                      icon: Icons.summarize_rounded,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'tasks.description'.tr(context),
                      controller: _descriptionController,
                      hint: 'tasks.desc_hint'.tr(context),
                      icon: Icons.description_rounded,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          shadowColor: _primaryColor.withValues(alpha: 0.3),
                        ),
                        child: _isSubmitting 
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'tasks.save_task'.tr(context),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: _primaryColor),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tasks.select_assignee'.tr(context),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showAssigneePicker,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add_rounded, size: 20, color: _primaryColor.withValues(alpha: 0.6)),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedAssigneeNames.isEmpty
                      ? Text(
                          'tasks.select_member_hint'.tr(context),
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        )
                      : Text(
                          _selectedAssigneeNames.join(', '),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: _primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tasks.team'.tr(context),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showTeamPicker,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.group_add_rounded, size: 20, color: _primaryColor.withValues(alpha: 0.6)),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedTeamNames.isEmpty
                      ? Text(
                          'tasks.select_team_hint'.tr(context),
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        )
                      : Text(
                          _selectedTeamNames.join(', '),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: _primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: _primaryColor.withValues(alpha: 0.6)),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
