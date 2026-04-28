import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/project_task_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../localization/app_localizations.dart';

class TaskDiscussionTab extends StatefulWidget {
  final int taskId;
  final int currentUserId;

  const TaskDiscussionTab({super.key, required this.taskId, required this.currentUserId});

  @override
  State<TaskDiscussionTab> createState() => TaskDiscussionTabState();
}

class TaskDiscussionTabState extends State<TaskDiscussionTab> {
  final ProjectTaskService _service = ProjectTaskService();
  final TextEditingController commentController = TextEditingController();
  Timer? _pollingTimer;
  
  List<dynamic> _discussions = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchDiscussions();
    _startPolling();
  }

  @override
  void dispose() {
    commentController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchDiscussions(isSilent: true);
      }
    });
  }

  Future<void> _fetchDiscussions({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    final result = await _service.getTaskDiscussions(widget.taskId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['status'] == true) {
          _discussions = result['data'];
        }
      });
    }
  }

  Future<void> addDiscussion({String? text}) async {
    final comment = text ?? commentController.text;
    if (comment.trim().isEmpty) return;
    
    setState(() => _isSending = true);
    final result = await _service.addTaskDiscussion(widget.taskId, comment.trim());
    
    if (mounted) {
      setState(() => _isSending = false);
      if (result['status'] == true) {
        if (text == null) commentController.clear();
        _fetchDiscussions();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.add_discussion_failed'.tr(context));
      }
    }
  }

  Future<void> _deleteDiscussion(int id) async {
    final result = await _service.deleteTaskDiscussion(id);
    if (mounted) {
      if (result['status'] == true) {
        _fetchDiscussions();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.delete_discussion_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.forum_outlined, 'tasks.team_discussion_title'.tr(context)),
        _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF7E57C2)),
                ),
              )
            : _discussions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _discussions.length,
                    itemBuilder: (context, index) {
                      final d = _discussions[index];
                      final isMe = d['employee_id'].toString() == widget.currentUserId.toString();
                      DateTime? created = DateTime.tryParse(d['created_at']);
                      String timeText = created != null ? timeago.format(created) : d['created_at'];

                      return _buildDiscussionBubble(d, isMe, timeText);
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
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'tasks.no_discussions'.tr(context),
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionBubble(dynamic d, bool isMe, String timeText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7E57C2);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  backgroundImage: NetworkImage(d['profile_photo_url'] ?? ''),
                  onBackgroundImageError: (_, __) {},
                  child: Text(
                    d['first_name'][0],
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe
                        ? primaryColor
                        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isMe 
                        ? null 
                        : Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${d['first_name']} ${d['last_name']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      Html(
                        data: d['discussion_text'],
                        style: {
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(13),
                            color: isMe ? Colors.white : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                          ),
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey[500],
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  backgroundImage: NetworkImage(d['profile_photo_url'] ?? ''),
                  onBackgroundImageError: (_, __) {},
                  child: Text(
                    d['first_name'][0],
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          if (isMe) 
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 40),
              child: GestureDetector(
                onTap: () => _deleteDiscussion(int.parse(d['task_discussion_id'].toString())),
                child: Text(
                  'main.delete'.tr(context),
                  style: TextStyle(color: Colors.red.withValues(alpha: 0.6), fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

}
