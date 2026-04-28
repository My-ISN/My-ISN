import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/project_task_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../localization/app_localizations.dart';

class TaskFilesTab extends StatefulWidget {
  final int taskId;
  final int currentUserId;

  const TaskFilesTab({super.key, required this.taskId, required this.currentUserId});

  @override
  State<TaskFilesTab> createState() => TaskFilesTabState();
}

class TaskFilesTabState extends State<TaskFilesTab> {
  final ProjectTaskService _service = ProjectTaskService();
  final ImagePicker _picker = ImagePicker();
  
  List<dynamic> _files = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    setState(() => _isLoading = true);
    final result = await _service.getTaskFiles(widget.taskId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['status'] == true) {
          _files = result['data'];
        }
      });
    }
  }

  Future<void> _uploadImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    setState(() => _isUploading = true);
    final result = await _service.uploadTaskFile(
      widget.taskId, 
      image.name, 
      image.path
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (result['status'] == true) {
        CustomSnackBar.showSuccess(context, 'tasks.photo_upload_success'.tr(context));
        _fetchFiles();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.photo_upload_failed'.tr(context));
      }
    }
  }

  void showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF7E57C2)),
                title: Text('tasks.camera'.tr(context)),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF7E57C2)),
                title: Text('tasks.gallery'.tr(context)),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _deleteFile(int id) async {
    final result = await _service.deleteTaskFile(id);
    if (mounted) {
      if (result['status'] == true) {
        _fetchFiles();
      } else {
        CustomSnackBar.showError(context, result['message'] ?? 'tasks.delete_file_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isUploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(color: Color(0xFF7E57C2), backgroundColor: Color(0xFFF3E5F5)),
            ),
          ),
        _buildSectionTitle(Icons.folder_shared_outlined, 'tasks.attachments_title'.tr(context)),
        _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF7E57C2)),
                ),
              )
            : _files.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final f = _files[index];
                      final isMe = f['employee_id'].toString() == widget.currentUserId.toString();
                      DateTime? created = DateTime.tryParse(f['created_at']);
                      String timeText = created != null ? timeago.format(created) : f['created_at'];

                      return _buildFileCard(f, isMe, timeText);
                    },
                  ),
        // Upload button removed from here, moved to fixed bottom in TaskDetailPage
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
          Icon(Icons.file_present_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'tasks.no_attachments'.tr(context),
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(dynamic f, bool isMe, String timeText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isImage = f['file_extension'] == 'jpg' || f['file_extension'] == 'jpeg' || f['file_extension'] == 'png';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.network(
                f['file_url'],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey[400]),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                    color: const Color(0xFF7E57C2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['file_title'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${f['first_name']} ${f['last_name']} • $timeText',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isMe)
                  GestureDetector(
                    onTap: () => _deleteFile(int.parse(f['task_file_id'].toString())),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
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
