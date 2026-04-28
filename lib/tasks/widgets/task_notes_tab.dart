import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/project_task_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../localization/app_localizations.dart';

class TaskNotesTab extends StatefulWidget {
  final int taskId;
  final int currentUserId;

  const TaskNotesTab({super.key, required this.taskId, required this.currentUserId});

  @override
  State<TaskNotesTab> createState() => TaskNotesTabState();
}

class TaskNotesTabState extends State<TaskNotesTab> {
  final ProjectTaskService _service = ProjectTaskService();
  final TextEditingController noteController = TextEditingController();
  Timer? _pollingTimer;
  
  List<dynamic> _notes = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
    _startPolling();
  }

  @override
  void dispose() {
    noteController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _fetchNotes(isSilent: true);
      }
    });
  }

  Future<void> _fetchNotes({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    final result = await _service.getTaskNotes(widget.taskId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['status'] == true) {
          _notes = result['data'];
        }
      });
    }
  }

  Future<void> addNote({String? text}) async {
    final note = text ?? noteController.text;
    if (note.trim().isEmpty) return;
    
    setState(() => _isSending = true);
    final result = await _service.addTaskNote(widget.taskId, note.trim());
    
    if (mounted) {
      setState(() => _isSending = false);
      if (result['status'] == true) {
        if (text == null) noteController.clear();
        _fetchNotes();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.add_note_failed'.tr(context));
      }
    }
  }

  Future<void> _deleteNote(int id) async {
    final result = await _service.deleteTaskNote(id);
    if (mounted) {
      if (result['status'] == true) {
        _fetchNotes();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.delete_note_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.note_alt_outlined, 'tasks.task_notes_title'.tr(context)),
        _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF7E57C2)),
                ),
              )
            : _notes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final n = _notes[index];
                      final isMe = n['employee_id'].toString() == widget.currentUserId.toString();
                      DateTime? created = DateTime.tryParse(n['created_at']);
                      String timeText = created != null ? timeago.format(created) : n['created_at'];

                      return _buildNoteCard(n, isMe, timeText);
                    },
                  ),
        // Input area removed from here, moved to fixed bottom in TaskDetailPage
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
          Icon(Icons.note_add_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'tasks.no_notes'.tr(context),
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(dynamic n, bool isMe, String timeText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7E57C2);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: NetworkImage(n['profile_photo_url'] ?? ''),
                      onBackgroundImageError: (_, __) {},
                      child: Text(
                        n['first_name'][0],
                        style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${n['first_name']} ${n['last_name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeText,
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  n['note_text'] ?? n['task_note'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => _deleteNote(int.parse(n['task_note_id'].toString())),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          'main.delete'.tr(context),
                          style: TextStyle(color: Colors.red.withValues(alpha: 0.6), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
