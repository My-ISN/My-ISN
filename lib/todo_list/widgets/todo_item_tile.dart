import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class TodoItemTile extends StatelessWidget {
  final dynamic todo;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final bool hasPermissionDelete;
  final bool hasPermissionTeam;
  final Color primaryColor;
  final VoidCallback onPriorityChange;
  final VoidCallback onCopy;
  final bool isOffline;

  const TodoItemTile({
    super.key,
    required this.todo,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.hasPermissionDelete,
    required this.hasPermissionTeam,
    required this.primaryColor,
    required this.onPriorityChange,
    required this.onCopy,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final String description = todo['description'] ?? '-';
    final String date = todo['created_at'] ?? '-';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).primaryColor.withValues(alpha: 0.04)
          : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: hasPermissionDelete ? onDelete : null,
            onTap: null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? Colors.green : Colors.transparent,
                        border: Border.all(
                          color: isCompleted ? Colors.green : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: isCompleted ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? Colors.grey
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 10,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                date,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildAgeBadge(context, date, isCompleted),
                            if (!isCompleted)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(todo['priority']),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            if (isOffline)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.cloud_queue_rounded,
                                  size: 14,
                                  color: Colors.blue[300],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (isOffline) return;
                      if (value == 'edit') onEdit();
                      if (value == 'copy') onCopy();
                      if (value == 'priority') onPriorityChange();
                      if (value == 'delete') onDelete();
                      if (value == 'toggle') onToggle();
                      if (value == 'move') onMove();
                    },
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: isOffline ? Colors.grey[300] : Colors.grey[400],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text('todo_list.edit_task'.tr(context)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text('todo_list.copy_task'.tr(context)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'priority',
                        child: Row(
                          children: [
                            Icon(
                              Icons.priority_high_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text('todo_list.priority'.tr(context)),
                          ],
                        ),
                      ),
                      if (hasPermissionTeam)
                        PopupMenuItem(
                          value: 'move',
                          child: Row(
                            children: [
                              Icon(
                                Icons.unarchive_outlined,
                                size: 20,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Text('todo_list.move_task'.tr(context)),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.undo_rounded
                                  : Icons.check_circle_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isCompleted
                                  ? 'todo_list.pending'.tr(context)
                                  : 'todo_list.completed'.tr(context),
                            ),
                          ],
                        ),
                      ),
                      if (hasPermissionDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'main.delete'.tr(context),
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgeBadge(BuildContext context, String createdAt, bool isCompleted) {
    try {
      final createdDate = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(createdDate);

      final int minutes = difference.inMinutes;
      final int hours = difference.inHours;
      final int days = difference.inDays;

      Color badgeColor;
      String label;

      if (isCompleted) {
        badgeColor = Colors.grey;
      } else {
        if (days < 1) {
          badgeColor = Colors.green;
        } else if (days < 3) {
          badgeColor = Colors.orange;
        } else {
          badgeColor = Colors.red;
        }
      }

      if (difference.inSeconds < 60) {
        label = 'time.just_now'.tr(context);
      } else if (minutes < 60) {
        String unitKey = minutes == 1 ? 'time.minute' : 'time.minutes';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.minute'.tr(context);
        label = '$minutes $unit ${'time.ago'.tr(context)}';
      } else if (hours < 24) {
        String unitKey = hours == 1 ? 'time.hour' : 'time.hours';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.hour'.tr(context);
        label = '$hours $unit ${'time.ago'.tr(context)}';
      } else if (days < 30) {
        String unitKey = days == 1 ? 'time.day' : 'time.days';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.day'.tr(context);
        label = '$days $unit ${'time.ago'.tr(context)}';
      } else {
        final months = (days / 30).floor();
        String unitKey = months == 1 ? 'time.month' : 'time.months';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.month'.tr(context);
        label = '$months $unit ${'time.ago'.tr(context)}';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: badgeColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Color _getPriorityColor(dynamic priority) {
    // 1: Tinggi (Red), 2: Normal (Yellow), 3: Rendah (Grey)
    final p = int.tryParse(priority?.toString() ?? '2') ?? 2;
    if (p == 1) return Colors.red;
    if (p == 3) return Colors.grey;
    return Colors.orange; // Default/Normal: Kuning (Orange visual)
  }
}
