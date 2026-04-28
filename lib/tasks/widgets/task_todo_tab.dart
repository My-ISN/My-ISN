import 'package:flutter/material.dart';
import '../../services/project_task_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../localization/app_localizations.dart';

class TaskTodoTab extends StatefulWidget {
  final int taskId;
  final int currentUserId;
  final Function(int)? onProgressChanged;

  const TaskTodoTab({super.key, required this.taskId, required this.currentUserId, this.onProgressChanged});

  @override
  State<TaskTodoTab> createState() => TaskTodoTabState();
}

class TaskTodoTabState extends State<TaskTodoTab> {
  final ProjectTaskService _service = ProjectTaskService();
  final TextEditingController _todoController = TextEditingController();
  
  List<dynamic> _todos = [];
  bool _isLoading = true;
  bool _isSending = false;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSpeechInitialized = false;
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    _fetchTodos();
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

  Future<void> _toggleListening(TextEditingController controller, StateSetter setModalState) async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setModalState(() => _isListening = true);
        setState(() => _textBeforeListening = controller.text);
        _speech.listen(
          localeId: 'id_ID',
          onResult: (val) {
            setModalState(() {
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
      setModalState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _todoController.dispose();
    super.dispose();
  }

  void _sortTodos() {
    _todos.sort((a, b) {
      final aDone = a['is_completed'].toString() == '1';
      final bDone = b['is_completed'].toString() == '1';

      if (aDone && !bDone) return 1;
      if (!aDone && bDone) return -1;

      // Newest first if same status
      try {
        DateTime aDate = DateTime.parse(a['created_at']);
        DateTime bDate = DateTime.parse(b['created_at']);
        return bDate.compareTo(aDate);
      } catch (e) {
        return 0;
      }
    });
  }

  void _emitProgress() {
    if (widget.onProgressChanged != null && _todos.isNotEmpty) {
      final progress = ((_completedCount / _todos.length) * 100).toInt();
      widget.onProgressChanged!(progress);
    }
  }

  Future<void> _fetchTodos() async {
    setState(() => _isLoading = true);
    final result = await _service.getProjectTodos(widget.taskId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['status'] == true) {
          _todos = result['data'];
          _sortTodos();
          // Initial emit might be too early or cause loops if not careful
          // But here it's fine as it's triggered by user or initial load
        }
      });
    }
  }

  Future<void> addTodoItem(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() => _isSending = true);
    final result = await _service.addProjectTodo(widget.taskId, text.trim());
    
    if (mounted) {
      setState(() => _isSending = false);
      if (result['status'] == true) {
        _fetchTodos();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.add_todo_failed'.tr(context));
      }
    }
  }

  Future<void> _toggleTodo(int id) async {
    // Optimistic Update
    final index = _todos.indexWhere((t) => int.parse(t['project_todo_id'].toString()) == id);
    if (index == -1) return;

    final originalStatus = _todos[index]['is_completed'].toString();
    setState(() {
      _todos[index]['is_completed'] = (originalStatus == '1' ? '0' : '1');
      _sortTodos();
      _emitProgress();
    });

    final result = await _service.toggleProjectTodo(id);
    if (mounted) {
      if (result['status'] == true) {
        // Just fetch to be sure
        _fetchTodos();
      } else {
        // Revert
        setState(() {
          _todos[index]['is_completed'] = originalStatus;
          _sortTodos();
          _emitProgress();
        });
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.toggle_todo_failed'.tr(context));
      }
    }
  }

  Future<void> _deleteTodo(int id) async {
    // Optimistic Delete
    final index = _todos.indexWhere((t) => int.parse(t['project_todo_id'].toString()) == id);
    if (index == -1) return;
    
    final deletedItem = _todos[index];
    setState(() {
      _todos.removeAt(index);
      _emitProgress();
    });

    final result = await _service.deleteProjectTodo(id);
    if (mounted) {
      if (result['status'] == true) {
        // OK
      } else {
        // Revert
        setState(() {
          _todos.insert(index, deletedItem);
          _emitProgress();
        });
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.delete_todo_failed'.tr(context));
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> todo) {
    final TextEditingController editController = TextEditingController(text: todo['todo_text']);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('tasks.edit_todo'.tr(context)),
              content: TextField(
                controller: editController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'tasks.todo_text'.tr(context),
                  suffixIcon: _isSpeechInitialized
                      ? IconButton(
                          icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : const Color(0xFF7E57C2)),
                          onPressed: () => _toggleListening(editController, setModalState),
                        )
                      : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _speech.stop();
                    Navigator.pop(context);
                  },
                  child: Text('main.cancel'.tr(context)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _speech.stop();
                    Navigator.pop(context);
                    if (editController.text.trim().isNotEmpty) {
                      final result = await _service.editProjectTodo(int.parse(todo['project_todo_id'].toString()), editController.text.trim());
                      if (result['status'] == true) {
                        _fetchTodos();
                      } else {
                        if (mounted) CustomSnackBar.showError(context, result['message'] ?? 'tasks.edit_todo_failed'.tr(context));
                      }
                    }
                  },
                  child: Text('main.save'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int get _completedCount => _todos.where((t) => t['is_completed'].toString() == '1').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.checklist_rounded, 'tasks.todo_list'.tr(context)),
        if (_todos.isNotEmpty) _buildProgressCard(),
        _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF7E57C2)),
                ),
              )
            : _todos.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final t = _todos[index];
                      final isCompleted = t['is_completed'].toString() == '1';
                      return _buildTodoItem(t, isCompleted);
                    },
                  ),
        const SizedBox(height: 20),
        // _buildInputArea(), // Removed as it is now fixed at bottom in TaskDetailPage
      ],
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

  Widget _buildProgressCard() {
    final progress = _todos.isEmpty ? 0 : ((_completedCount / _todos.length) * 100).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7E57C2).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: progress / 100,
                  backgroundColor: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                  color: const Color(0xFF7E57C2),
                  strokeWidth: 4,
                ),
              ),
              Text(
                '$progress%',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7E57C2)),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tasks.todo_progress'.tr(context),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                'tasks.todo_stats'.tr(context, args: {
                  'completed': _completedCount.toString(),
                  'total': _todos.length.toString()
                }),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'tasks.todo_empty'.tr(context),
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(dynamic t, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF7E57C2).withValues(alpha: 0.1)
              : Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: null, // Card click disabled as per user request
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleTodo(int.parse(t['project_todo_id'].toString())),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? const Color(0xFF7E57C2) : Colors.transparent,
                      border: Border.all(
                        color: isCompleted ? const Color(0xFF7E57C2) : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['todo_text'] ?? '-',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted
                              ? Colors.grey[500]
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (t['created_at'] != null || (isCompleted && t['first_name'] != null))
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (t['created_at'] != null)
                              Text(
                                t['created_at'],
                                style: TextStyle(color: Colors.grey[400], fontSize: 10),
                              ),
                            if (isCompleted && t['first_name'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7E57C2).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "tasks.done_by".tr(context, args: {'name': "${t['first_name']} ${t['last_name'] ?? ''}"}),
                                  style: const TextStyle(
                                    color: Color(0xFF7E57C2),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                _buildTodoActions(t, isCompleted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoActions(dynamic t, bool isCompleted) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') _showEditDialog(t);
        if (value == 'delete') _deleteTodo(int.parse(t['project_todo_id'].toString()));
        if (value == 'toggle') _toggleTodo(int.parse(t['project_todo_id'].toString()));
      },
      icon: Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Text('main.edit'.tr(context)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.undo_rounded : Icons.check_circle_outline,
                size: 18,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 12),
              Text(isCompleted ? 'tasks.mark_as_undone'.tr(context) : 'tasks.mark_as_done'.tr(context)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              Text('main.delete'.tr(context), style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _buildInputArea() removed
}
