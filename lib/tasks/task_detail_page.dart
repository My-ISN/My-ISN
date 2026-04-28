import 'package:flutter/material.dart';
import '../services/project_task_service.dart';
import '../widgets/custom_snackbar.dart';
import 'models/task_model.dart';
import 'widgets/task_overview_tab.dart';
import 'widgets/task_edit_tab.dart';
import 'widgets/task_discussion_tab.dart';
import 'widgets/task_notes_tab.dart';
import 'widgets/task_files_tab.dart';
import 'widgets/task_todo_tab.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../widgets/secondary_app_bar.dart';
import '../localization/app_localizations.dart';

class TaskDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Task task;
  const TaskDetailPage({super.key, required this.userData, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final ProjectTaskService _service = ProjectTaskService();
  late Task _task;
  bool _isLoading = false;
  bool _isUpdating = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSpeechInitialized = false;

  final GlobalKey<TaskEditTabState> _editTabKey = GlobalKey<TaskEditTabState>();
  final GlobalKey<TaskDiscussionTabState> _discussionTabKey = GlobalKey<TaskDiscussionTabState>();
   final GlobalKey<TaskNotesTabState> _notesTabKey = GlobalKey<TaskNotesTabState>();
  final GlobalKey<TaskFilesTabState> _filesTabKey = GlobalKey<TaskFilesTabState>();
  final GlobalKey<TaskTodoTabState> _todoTabKey = GlobalKey<TaskTodoTabState>();

  final TextEditingController _discussionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _todoController = TextEditingController();

  @override
  void dispose() {
    _speech.stop();
    _discussionController.dispose();
    _noteController.dispose();
    _todoController.dispose();
    super.dispose();
  }

  int get currentUserId {
    return int.tryParse(widget.userData['id']?.toString() ?? widget.userData['user_id']?.toString() ?? '0') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _fetchTaskDetails();
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
          debugPrint('Speech Error: $val');
        },
      );
    } catch (e) {
      debugPrint('Speech Init Error: $e');
    }
  }

  String _textBeforeListening = '';

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
      } else {
        CustomSnackBar.showError(context, 'tasks.speech_not_available'.tr(context));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _fetchTaskDetails() async {
    final result = await _service.getTaskDetails(_task.id);
    if (result['status'] == true) {
      if (mounted) {
        setState(() {
          _task = Task.fromJson(result['data']);
        });
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    final result = await _service.updateTaskStatus(_task.id, status: int.parse(status));
    if (mounted) {
      setState(() => _isUpdating = false);
      if (result['status'] == true) {
        CustomSnackBar.showSuccess(context, 'tasks.update_status_success'.tr(context));
        _fetchTaskDetails();
      } else {
        CustomSnackBar.showError(context, 'tasks.update_status_failed'.tr(context));
      }
    }
  }

  Future<void> _updateProgress(double value) async {
    final result = await _service.updateTaskStatus(_task.id, progress: value.toInt());
    if (result['status'] == true) {
      _fetchTaskDetails();
    }
  }

  String _activeTab = 'OVERVIEW';
  bool _isExpanded = false;

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1' ||
        widget.userData['role_resources'] == 'all') {
      return true;
    }
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  void _showDeleteConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'tasks.delete_title'.tr(context),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'tasks.delete_confirm_permanent'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteTask();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.delete'.tr(context),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTask() async {
    setState(() => _isUpdating = true);
    final result = await _service.deleteTask(_task.id);
    setState(() => _isUpdating = false);

    if (result['status'] == true) {
      CustomSnackBar.showSuccess(context, 'tasks.delete_success'.tr(context));
      Navigator.pop(context, true);
    } else {
      CustomSnackBar.showError(context, 'tasks.delete_failed'.tr(context) + ': ${result['message']}');
    }
  }

  List<String> get _menuTabs {
    final tabs = ['OVERVIEW'];
    if (_hasPermission('mobile_tasks_edit')) {
      tabs.add('EDIT');
    }
    tabs.addAll(['DISCUSSION', 'NOTE', 'FILES', 'TODO']);
    return tabs;
  }

  Color get _primaryColor => const Color(0xFF7E57C2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: SecondaryAppBar(
        title: 'My ISN',
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_hasPermission('mobile_tasks_delete'))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTaskDetails,
        color: _primaryColor,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 20),
                    _buildHorizontalMenu(),
                    const SizedBox(height: 24),
                    _buildActiveTabContent(),
                  ],
                ),
              ),
            ),
            if (_buildBottomAction() != null) _buildBottomAction()!,
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomAction() {
    if (_activeTab == 'OVERVIEW') return null;
    if (_activeTab == 'EDIT' && !_hasPermission('mobile_tasks_edit')) return null;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: _buildBottomActionContent(),
        ),
      ),
    );
  }

  Widget _buildBottomActionContent() {
    switch (_activeTab) {
      case 'EDIT':
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              if (_editTabKey.currentState == null) {
                CustomSnackBar.showError(context, 'tasks.loading_tab'.tr(context));
                return;
              }
              _editTabKey.currentState?.saveChanges();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('tasks.save_changes'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      case 'DISCUSSION':
        return _buildInputBar(
          hint: 'tasks.type_message'.tr(context),
          onSend: () async {
            _speech.stop();
            if (_discussionTabKey.currentState == null) {
              CustomSnackBar.showError(context, 'tasks.loading_tab'.tr(context));
              return;
            }
            final text = _discussionController.text;
            if (text.trim().isNotEmpty) {
              await _discussionTabKey.currentState?.addDiscussion(text: text);
              _discussionController.clear();
              FocusScope.of(context).unfocus();
            }
          },
          controller: _discussionController,
        );
      case 'NOTE':
        return _buildInputBar(
          hint: 'tasks.add_note_hint'.tr(context),
          onSend: () async {
            _speech.stop();
            if (_notesTabKey.currentState == null) {
              CustomSnackBar.showError(context, 'tasks.loading_tab'.tr(context));
              return;
            }
            final text = _noteController.text;
            if (text.trim().isNotEmpty) {
              await _notesTabKey.currentState?.addNote(text: text);
              _noteController.clear();
              FocusScope.of(context).unfocus();
            }
          },
          controller: _noteController,
        );
      case 'FILES':
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_filesTabKey.currentState == null) {
                CustomSnackBar.showError(context, 'tasks.loading_tab'.tr(context));
                return;
              }
              _filesTabKey.currentState?.showUploadOptions();
            },
            icon: const Icon(Icons.cloud_upload_rounded),
            label: Text('tasks.upload_file'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        );
      case 'TODO':
        return _buildInputBar(
          hint: 'tasks.add_task'.tr(context),
          onSend: () async {
            _speech.stop();
            if (_todoTabKey.currentState == null) {
              CustomSnackBar.showError(context, 'tasks.loading_tab'.tr(context));
              return;
            }
            final text = _todoController.text;
            if (text.trim().isNotEmpty) {
              await _todoTabKey.currentState?.addTodoItem(text);
              _todoController.clear();
              FocusScope.of(context).unfocus();
            }
          },
          controller: _todoController,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInputBar({required String hint, required VoidCallback onSend, required TextEditingController controller}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                border: InputBorder.none,
                suffixIcon: _isSpeechInitialized
                    ? IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : _primaryColor,
                          size: 20,
                        ),
                        onPressed: () => _toggleListening(controller),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSend,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: Radius.circular(_isExpanded ? 0 : 24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _task.progress.toDouble()),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _task.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStatusChip(_task.status),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  Text(
                                    '${value.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: value / 100,
                              minHeight: 12,
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(Icons.info_outline, 'tasks.status_settings'.tr(context)),
                      const SizedBox(height: 12),
                      _buildStatusDropdown(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDateInfo(
                            'tasks.start_date'.tr(context),
                            _task.startDate ?? '-',
                            Icons.calendar_today_rounded,
                          ),
                          _buildDateInfo(
                            'tasks.end_date'.tr(context),
                            _task.endDate ?? '-',
                            Icons.event_available_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String date, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHorizontalMenu() {
    final List<String> filteredTabs = List.from(_menuTabs);
    if (!_hasPermission('mobile_tasks_edit')) {
      filteredTabs.remove('EDIT');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filteredTabs.map((tab) {
          final bool isActive = _activeTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive ? _primaryColor : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? _primaryColor.withValues(alpha: 0.2) : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  'tasks.${tab.toLowerCase()}'.tr(context),
                  style: TextStyle(
                    color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'OVERVIEW':
        return TaskOverviewTab(task: _task);
      case 'EDIT':
        return TaskEditTab(key: _editTabKey, task: _task, onUpdated: _fetchTaskDetails);
      case 'DISCUSSION':
        return TaskDiscussionTab(key: _discussionTabKey, taskId: _task.id, currentUserId: currentUserId);
      case 'NOTE':
        return TaskNotesTab(key: _notesTabKey, taskId: _task.id, currentUserId: currentUserId);
      case 'FILES':
        return TaskFilesTab(key: _filesTabKey, taskId: _task.id, currentUserId: currentUserId);
      case 'TODO':
        return TaskTodoTab(
          key: _todoTabKey,
          taskId: _task.id,
          currentUserId: currentUserId,
          onProgressChanged: (progress) {
            if (_task.progress != progress) {
              setState(() {
                _task = _task.copyWith(progress: progress);
              });
              _updateProgress(progress.toDouble());
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _primaryColor),
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

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case '0': color = Colors.grey; text = 'tasks.not_started'.tr(context); break;
      case '1': color = Colors.blue; text = 'tasks.in_progress'.tr(context); break;
      case '2': color = Colors.green; text = 'tasks.completed'.tr(context); break;
      case '3': color = Colors.red; text = 'tasks.cancelled'.tr(context); break;
      case '4': color = Colors.orange; text = 'tasks.on_hold'.tr(context); break;
      default: color = Colors.grey; text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _task.status,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          items: [
            _buildDropdownItem('0', 'tasks.not_started'.tr(context), Colors.grey),
            _buildDropdownItem('1', 'tasks.in_progress'.tr(context), Colors.blue),
            _buildDropdownItem('2', 'tasks.completed'.tr(context), Colors.green),
            _buildDropdownItem('3', 'tasks.cancelled'.tr(context), Colors.red),
            _buildDropdownItem('4', 'tasks.on_hold'.tr(context), Colors.orange),
          ],
          onChanged: _hasPermission('mobile_tasks_edit') ? (val) {
            if (val != null) _updateStatus(val);
          } : null,
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, String text, Color color) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
