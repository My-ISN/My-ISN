import 'package:flutter/material.dart';
import '../services/project_task_service.dart';
import '../widgets/custom_snackbar.dart';
import 'package:intl/intl.dart';
import '../widgets/secondary_app_bar.dart';
import '../widgets/searchable_dropdown.dart';
import '../localization/app_localizations.dart';

class AddProjectPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AddProjectPage({super.key, required this.userData});

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final ProjectTaskService _service = ProjectTaskService();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _endDateController = TextEditingController();
  final _summaryController = TextEditingController();
  final _budgetHoursController = TextEditingController();
  
  List<dynamic> _departments = [];
  List<dynamic> _employees = [];
  
  int? _selectedDepartmentId;
  String _selectedDepartmentName = '';
  
  String _selectedPriority = '1'; // Default: Medium
  
  // Team (Assigned To)
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
      _fetchDepartments(),
      _fetchEmployees(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchDepartments() async {
    final result = await _service.getDepartments();
    if (result['status'] == true) {
      if (mounted) setState(() => _departments = result['data'] ?? []);
    } else {
      if (mounted) {
        CustomSnackBar.showError(context, 'projects.fetch_departments_error'.tr(context));
      }
    }
  }

  Future<void> _fetchEmployees() async {
    final result = await _service.getEmployees();
    if (result['status'] == true) {
      if (mounted) setState(() => _employees = result['data'] ?? []);
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

  void _showTeamPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Text('projects.select_team'.tr(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('projects.done'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      final name = '${emp['first_name']} ${emp['last_name'] ?? ''}';
                      final isSelected = _selectedTeamIds.contains(id);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text(emp['role_name'] ?? '', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                        activeColor: _primaryColor,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              _selectedTeamIds.add(id);
                              _selectedTeamNames.add(name);
                            } else {
                              _selectedTeamIds.remove(id);
                              _selectedTeamNames.remove(name);
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
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDepartmentId == null) {
      if (_selectedDepartmentId == null) CustomSnackBar.showError(context, 'projects.select_department_error'.tr(context));
      return;
    }

    setState(() => _isSubmitting = true);
    
    final data = {
      'title': _titleController.text,
      'department_id': _selectedDepartmentId,
      'priority': _selectedPriority,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'summary': _summaryController.text,
      'description': _descriptionController.text,
      'budget_hours': _budgetHoursController.text,
      'assigned_to': _selectedTeamIds.join(','),
    };

    final result = await _service.addProject(data);
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['status'] == true) {
        CustomSnackBar.showSuccess(context, 'projects.add_success'.tr(context));
        Navigator.pop(context, true);
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'projects.add_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(title: 'projects.add_project'.tr(context)),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(Icons.business_center_rounded, 'projects.main_info'.tr(context)),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'projects.project_name'.tr(context),
                      controller: _titleController,
                      hint: 'projects.project_name'.tr(context),
                      icon: Icons.title_rounded,
                      validator: (val) => val!.isEmpty ? 'projects.validation_name'.tr(context) : null,
                    ),
                    const SizedBox(height: 20),
                    _buildTeamSelector(),
                    const SizedBox(height: 20),
                    SearchableDropdown(
                      label: 'projects.department'.tr(context),
                      value: _selectedDepartmentName,
                      icon: Icons.lan_outlined,
                      options: _departments.map<Map<String, String>>((d) => {
                        'id': d['department_id'].toString(),
                        'name': d['department_name'] ?? '',
                      }).toList(),
                      onSelected: (id) {
                        final d = _departments.firstWhere((d) => d['department_id'].toString() == id);
                        setState(() {
                          _selectedDepartmentId = int.parse(id);
                          _selectedDepartmentName = d['department_name'] ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.calendar_month_rounded, 'projects.time_budget'.tr(context)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'projects.start_date'.tr(context),
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
                            label: 'projects.end_date'.tr(context),
                            controller: _endDateController,
                            hint: 'YYYY-MM-DD',
                            icon: Icons.event_rounded,
                            readOnly: true,
                            onTap: () => _selectDate(_endDateController),
                            validator: (val) => val!.isEmpty ? 'projects.validation_required'.tr(context) : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'projects.budget_hours'.tr(context),
                      controller: _budgetHoursController,
                      hint: 'projects.budget_hours_hint'.tr(context),
                      icon: Icons.access_time_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.edit_note_rounded, 'projects.detail_priority'.tr(context)),
                    const SizedBox(height: 16),
                    _buildPrioritySelector(),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'projects.summary'.tr(context),
                      controller: _summaryController,
                      hint: 'projects.summary_hint'.tr(context),
                      icon: Icons.summarize_rounded,
                      validator: (val) => val!.isEmpty ? 'projects.validation_summary'.tr(context) : null,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'projects.description'.tr(context),
                      controller: _descriptionController,
                      hint: 'projects.desc_hint'.tr(context),
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
                        ),
                        child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Text('projects.save_project'.tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: _primaryColor),
        ),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleMedium?.color)),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    final priorities = [
      {'id': '1', 'name': 'projects.priority_medium'.tr(context), 'color': Colors.blue},
      {'id': '2', 'name': 'projects.priority_high'.tr(context), 'color': Colors.orange},
      {'id': '3', 'name': 'projects.priority_critical'.tr(context), 'color': Colors.red},
      {'id': '4', 'name': 'projects.priority_low'.tr(context), 'color': Colors.grey},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('projects.priority'.tr(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6))),
        const SizedBox(height: 10),
        Row(
          children: priorities.map((p) {
            final isSelected = _selectedPriority == p['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPriority = p['id'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? p['color'] as Color : (p['color'] as Color).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? p['color'] as Color : (p['color'] as Color).withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      p['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : p['color'] as Color,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTeamSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('projects.team_members_label'.tr(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6))),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showTeamPicker,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.group_add_rounded, size: 20, color: _primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedTeamNames.isEmpty ? 'projects.select_team_hint'.tr(context) : _selectedTeamNames.join(', '),
                    style: TextStyle(fontSize: 14, color: _selectedTeamNames.isEmpty ? Colors.grey[500] : Theme.of(context).textTheme.bodyLarge?.color),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: _primaryColor.withValues(alpha: 0.6)),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
