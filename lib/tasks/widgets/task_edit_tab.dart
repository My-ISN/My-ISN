import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../../services/project_task_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../localization/app_localizations.dart';

class TaskEditTab extends StatefulWidget {
  final Task task;
  final VoidCallback onUpdated;

  const TaskEditTab({super.key, required this.task, required this.onUpdated});

  @override
  State<TaskEditTab> createState() => TaskEditTabState();
}

class TaskEditTabState extends State<TaskEditTab> {
  final _formKey = GlobalKey<FormState>();
  final ProjectTaskService _service = ProjectTaskService();
  
  late TextEditingController _nameController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _hourController;
  late TextEditingController _summaryController;
  late TextEditingController _descriptionController;
  
  List<dynamic> _employees = [];
  // Assign Member
  List<String> _selectedAssigneeIds = [];
  List<String> _selectedAssigneeNames = [];
  
  // Team
  List<String> _selectedTeamIds = [];
  List<String> _selectedTeamNames = [];

  bool _isLoading = false;
  bool _isDataLoading = true;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSpeechInitialized = false;
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task.name);
    _startDateController = TextEditingController(text: widget.task.startDate);
    _endDateController = TextEditingController(text: widget.task.endDate);
    _hourController = TextEditingController(text: widget.task.taskHour);
    _summaryController = TextEditingController(text: widget.task.summary);
    String cleanDescription = widget.task.description.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
    _descriptionController = TextEditingController(text: cleanDescription);
    
    _selectedAssigneeIds = widget.task.taskAssigneesIds.split(',').where((id) => id.isNotEmpty).toList();
    _selectedTeamIds = widget.task.assignedToIds.split(',').where((id) => id.isNotEmpty).toList();
    
    _fetchEmployees();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
        },
      );
    } catch (e) {}
  }

  Future<void> _toggleListening(TextEditingController controller) async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _textBeforeListening = controller.text;
        });
        _speech.listen(
          localeId: 'id_ID',
          onResult: (val) {
            setState(() {
              String newText = val.recognizedWords;
              if (_textBeforeListening.isNotEmpty) {
                controller.text = '$_textBeforeListening $newText';
              } else {
                controller.text = newText;
              }
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _fetchEmployees() async {
    final result = await _service.getEmployees();
    if (result['status'] == true) {
      if (mounted) {
        setState(() {
          _employees = result['data'] ?? [];
          _isDataLoading = false;
          
          // Match names for current IDs
          _selectedAssigneeNames.clear();
          for (var id in _selectedAssigneeIds) {
            final emp = _employees.firstWhere((e) => e['user_id'].toString() == id, orElse: () => null);
            if (emp != null) {
              _selectedAssigneeNames.add(emp['username'] ?? '${emp['first_name']} ${emp['last_name']}');
            }
          }

          _selectedTeamNames.clear();
          for (var id in _selectedTeamIds) {
            final emp = _employees.firstWhere((e) => e['user_id'].toString() == id, orElse: () => null);
            if (emp != null) {
              _selectedTeamNames.add(emp['username'] ?? '${emp['first_name']} ${emp['last_name']}');
            }
          }
        });
      }
    } else {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _hourController.dispose();
    _summaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                  subtitle: Text(emp['role_name'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  activeColor: const Color(0xFF7E57C2),
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

  Future<void> saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final result = await _service.updateTaskDetails({
      'task_id': widget.task.id,
      'task_name': _nameController.text,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'task_hour': _hourController.text,
      'summary': _summaryController.text,
      'description': _descriptionController.text,
      'task_assignees': _selectedAssigneeIds.join(','),
      'assigned_to': _selectedTeamIds.join(','),
    });
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['status'] == true) {
        CustomSnackBar.showSuccess(context, 'tasks.update_success'.tr(context));
        widget.onUpdated();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.update_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(Icons.edit_note_rounded, 'tasks.basic_info'.tr(context)),
          _buildEditCard([
            _buildTextField('tasks.task_name'.tr(context), _nameController, required: true, icon: Icons.title_rounded),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildDateField('tasks.start_date'.tr(context), _startDateController, icon: Icons.calendar_today_rounded)),
                const SizedBox(width: 16),
                Expanded(child: _buildDateField('tasks.end_date'.tr(context), _endDateController, icon: Icons.event_available_rounded)),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField('tasks.task_hour'.tr(context), _hourController, icon: Icons.access_time_rounded),
            const SizedBox(height: 20),
            _buildAssigneeSelector(),
            const SizedBox(height: 20),
            _buildTeamSelector(),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle(Icons.description_outlined, 'tasks.details_desc'.tr(context)),
          _buildEditCard([
            _buildTextField('tasks.summary'.tr(context), _summaryController, maxLines: 3, icon: Icons.summarize_outlined, useSpeech: true),
            const SizedBox(height: 20),
            _buildTextField('tasks.description'.tr(context), _descriptionController, maxLines: 5, icon: Icons.description_outlined, useSpeech: true),
          ]),
          // Save button removed from here, moved to fixed bottom in TaskDetailPage
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

  Widget _buildAssigneeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tasks.assignees'.tr(context).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showAssigneePicker,
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
                  child: _selectedAssigneeNames.isEmpty
                      ? Text(
                          'tasks.select_member_hint'.tr(context),
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        )
                      : Text(
                          _selectedAssigneeNames.join(', '),
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

  Widget _buildTeamSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tasks.team'.tr(context).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showTeamPicker,
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
                Icon(Icons.group_add_rounded, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedTeamNames.isEmpty
                      ? Text(
                          'tasks.select_team_hint'.tr(context),
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        )
                      : Text(
                          _selectedTeamNames.join(', '),
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

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1, IconData? icon, bool useSpeech = false}) {
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          validator: required ? (val) => val == null || val.isEmpty ? 'tasks.validation_name'.tr(context) : null : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
            prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey[400]) : null,
            suffixIcon: useSpeech && _isSpeechInitialized
                ? IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : const Color(0xFF7E57C2)),
                    onPressed: () => _toggleListening(controller),
                  )
                : null,
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
          onTap: () => _selectDate(context, controller),
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
}
