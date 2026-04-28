import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/project_task_service.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/custom_snackbar.dart';
import '../../localization/app_localizations.dart';

class ProjectEditTab extends StatefulWidget {
  final Map<String, dynamic> project;
  final VoidCallback onUpdate;

  const ProjectEditTab({super.key, required this.project, required this.onUpdate});

  @override
  State<ProjectEditTab> createState() => ProjectEditTabState();
}

class ProjectEditTabState extends State<ProjectEditTab> {
  final _formKey = GlobalKey<FormState>();
  final ProjectTaskService _service = ProjectTaskService();

  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _descriptionController;
  late TextEditingController _estimatedHourController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _progressController;

  String? _selectedDepartment;
  String? _selectedPriority;
  String? _selectedStatus;
  
  List<String> _selectedMemberIds = [];
  List<String> _selectedMemberNames = [];

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoadingData = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.project['title']);
    _summaryController = TextEditingController(text: widget.project['summary']);
    _descriptionController = TextEditingController(text: widget.project['description']);
    _estimatedHourController = TextEditingController(text: widget.project['estimated_hour']?.toString());
    _startDateController = TextEditingController(text: widget.project['start_date']);
    _endDateController = TextEditingController(text: widget.project['end_date']);
    _progressController = TextEditingController(text: widget.project['project_progress']?.toString() ?? '0');

    _selectedDepartment = widget.project['department_id']?.toString();
    _selectedPriority = widget.project['priority']?.toString();
    _selectedStatus = widget.project['status']?.toString();
    
    _selectedMemberIds = (widget.project['assigned_to'] as String? ?? '')
        .split(',')
        .where((id) => id.trim().isNotEmpty)
        .toList();

    _loadData();
  }

  Future<void> _loadData() async {
    final depts = await _service.getDepartments();
    final emps = await _service.getEmployees();

    if (mounted) {
      setState(() {
        _departments = List<Map<String, dynamic>>.from(depts['data'] ?? []);
        _employees = List<Map<String, dynamic>>.from(emps['data'] ?? []);
        
        _selectedMemberNames.clear();
        for (var id in _selectedMemberIds) {
          final emp = _employees.firstWhere((e) => e['user_id'].toString() == id, orElse: () => {});
          if (emp.isNotEmpty) {
            _selectedMemberNames.add(emp['name'] ?? '${emp['first_name']} ${emp['last_name']}');
          }
        }
        
        _isLoadingData = false;
      });
    }
  }

  Future<void> saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final data = {
      'project_id': widget.project['project_id'],
      'title': _titleController.text,
      'department_id': _selectedDepartment,
      'priority': _selectedPriority,
      'status': _selectedStatus,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'summary': _summaryController.text,
      'description': _descriptionController.text,
      'estimated_hour': _estimatedHourController.text,
      'assigned_to': _selectedMemberIds.join(','),
      'project_progress': _progressController.text,
    };

    final result = await _service.updateProjectDetails(data);
    if (mounted) {
      setState(() => _isSaving = false);
      if (result['status'] == true) {
        CustomSnackBar.showSuccess(context, 'projects.update_success'.tr(context));
        widget.onUpdate();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'projects.update_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(Icons.edit_note_rounded, 'projects.main_info'.tr(context)),
          _buildEditCard([
            _buildTextField('projects.project_name'.tr(context), _titleController, required: true, icon: Icons.title_rounded),
            const SizedBox(height: 20),
            _buildDepartmentDropdown(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildPriorityDropdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusDropdown()),
              ],
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle(Icons.calendar_today_rounded, 'projects.time_progress'.tr(context)),
          _buildEditCard([
            Row(
              children: [
                Expanded(child: _buildDateField('projects.start_date'.tr(context), _startDateController, icon: Icons.calendar_today_rounded)),
                const SizedBox(width: 16),
                Expanded(child: _buildDateField('projects.end_date'.tr(context), _endDateController, icon: Icons.event_available_rounded)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildTextField('projects.budget_hours'.tr(context), _estimatedHourController, keyboardType: TextInputType.number, icon: Icons.access_time_rounded)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('tasks.progress'.tr(context), _progressController, keyboardType: TextInputType.number, icon: Icons.analytics_outlined)),
              ],
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle(Icons.people_outline, 'projects.team_project'.tr(context)),
          _buildEditCard([
            _buildMemberSelector(),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle(Icons.description_outlined, '${'projects.summary'.tr(context)} & ${'projects.description'.tr(context)}'),
          _buildEditCard([
            _buildTextField('projects.summary'.tr(context), _summaryController, maxLines: 3, icon: Icons.summarize_outlined),
            const SizedBox(height: 20),
            _buildTextField('projects.description'.tr(context), _descriptionController, maxLines: 5, icon: Icons.description_outlined),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF7E57C2)),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1, IconData? icon, TextInputType? keyboardType}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          validator: required ? (val) => val == null || val.isEmpty ? 'projects.validation_required'.tr(context) : null : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
            prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey[400]) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, {IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() => controller.text = DateFormat('yyyy-MM-dd').format(date));
            }
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
            prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey[400]) : null,
            suffixIcon: Icon(Icons.calendar_month_rounded, size: 18, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    final selectedDept = _departments.firstWhere(
      (d) => d['department_id'].toString() == _selectedDepartment,
      orElse: () => {},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'projects.department'.tr(context).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        SearchableDropdown(
          label: 'projects.select_dept_hint'.tr(context),
          value: selectedDept['department_name']?.toString() ?? '',
          options: _departments.map((d) => {
            'id': d['department_id'].toString(),
            'name': d['department_name'].toString(),
          }).toList(),
          onSelected: (id) => setState(() => _selectedDepartment = id),
          icon: Icons.business_outlined,
        ),
      ],
    );
  }

  Widget _buildPriorityDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'projects.priority'.tr(context).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedPriority,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          items: [
            DropdownMenuItem(value: '1', child: Text('projects.priority_highest'.tr(context))),
            DropdownMenuItem(value: '2', child: Text('projects.priority_high'.tr(context))),
            DropdownMenuItem(value: '3', child: Text('projects.priority_normal'.tr(context))),
            DropdownMenuItem(value: '4', child: Text('projects.priority_low'.tr(context))),
          ],
          onChanged: (val) => setState(() => _selectedPriority = val),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tasks.status'.tr(context).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          items: [
            DropdownMenuItem(value: '0', child: Text('projects.not_started'.tr(context))),
            DropdownMenuItem(value: '1', child: Text('projects.in_progress'.tr(context))),
            DropdownMenuItem(value: '2', child: Text('projects.completed'.tr(context))),
            DropdownMenuItem(value: '3', child: Text('projects.cancelled'.tr(context))),
            DropdownMenuItem(value: '4', child: Text('projects.on_hold'.tr(context))),
          ],
          onChanged: (val) => setState(() => _selectedStatus = val),
        ),
      ],
    );
  }

  Widget _buildMemberSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'projects.team_members_label'.tr(context).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showMemberPicker,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add_rounded, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedMemberNames.isEmpty
                      ? Text(
                          'projects.select_member_hint'.tr(context),
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        )
                      : Text(
                          _selectedMemberNames.join(', '),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMemberPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
                    child: Row(
                      children: [
                        Text('projects.select_team_member'.tr(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (_selectedMemberIds.length == _employees.length) {
                                _selectedMemberIds.clear();
                                _selectedMemberNames.clear();
                              } else {
                                _selectedMemberIds.clear();
                                _selectedMemberNames.clear();
                                for (var emp in _employees) {
                                  _selectedMemberIds.add(emp['user_id'].toString());
                                  _selectedMemberNames.add(emp['name'] ?? '${emp['first_name']} ${emp['last_name']}');
                                }
                              }
                            });
                            setState(() {});
                          },
                          child: Text(
                            _selectedMemberIds.length == _employees.length ? 'tasks.deselect_all'.tr(context) : 'tasks.select_all'.tr(context),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
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
                        final name = emp['name'] ?? '${emp['first_name']} ${emp['last_name']}';
                        final isSelected = _selectedMemberIds.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: Text(emp['role_name'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          activeColor: const Color(0xFF7E57C2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedMemberIds.add(id);
                                _selectedMemberNames.add(name);
                              } else {
                                _selectedMemberIds.remove(id);
                                _selectedMemberNames.remove(name);
                              }
                            });
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}
