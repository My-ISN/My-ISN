import 'package:flutter/material.dart';
import '../models/task_model.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../localization/app_localizations.dart';

class TaskOverviewTab extends StatelessWidget {
  final Task task;

  const TaskOverviewTab({super.key, required this.task});

  String _calculateRemainingDays(BuildContext context, String endDateStr) {
    if (endDateStr.isEmpty) return 'N/A';
    try {
      final now = DateTime.now();
      final end = DateTime.parse(endDateStr);
      final diff = end.difference(now).inDays;
      if (diff < 0) return 'tasks.overdue'.tr(context, args: {'days': diff.abs().toString()});
      if (diff == 0) return 'tasks.today'.tr(context);
      return 'tasks.days_left'.tr(context, args: {'days': diff.toString()});
    } catch (e) {
      return endDateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingDays = _calculateRemainingDays(context, task.endDate);
    
    bool isOverdue = false;
    try {
      if (task.endDate.isNotEmpty) {
        final end = DateTime.parse(task.endDate);
        isOverdue = end.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      }
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, Icons.info_outline, 'tasks.main_info'.tr(context)),
        _buildSectionCard(
          context,
          [
            _buildInfoRow(context, 'tasks.task_name'.tr(context), task.name, icon: Icons.title_rounded),
            _buildInfoRow(context, 'main.project'.tr(context), task.projectName, icon: Icons.work_outline),
            _buildRowTwoFields(
              context,
              'tasks.start_date'.tr(context),
              task.startDate,
              'tasks.task_hour'.tr(context),
              task.taskHour.isNotEmpty ? task.taskHour : '-',
              icon1: Icons.calendar_today_rounded,
              icon2: Icons.access_time_rounded,
            ),
            _buildInfoRow(
              context,
              'tasks.period'.tr(context),
              remainingDays,
              icon: Icons.timer_outlined,
              valueColor: isOverdue ? Colors.red : const Color(0xFF7E57C2),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(context, Icons.people_outline, 'tasks.assignment'.tr(context)),
        _buildSectionCard(
          context,
          [
            _buildInfoRow(context, 'tasks.assignees'.tr(context), task.taskAssignees.isEmpty ? 'tasks.all_staff'.tr(context) : task.taskAssignees, icon: Icons.person_rounded),
            _buildInfoRow(context, 'tasks.team'.tr(context), task.assignedTo.isEmpty ? '-' : task.assignedTo, icon: Icons.groups_rounded),
            _buildInfoRow(context, 'tasks.goals'.tr(context), task.associatedGoals.isEmpty ? '-' : task.associatedGoals, icon: Icons.flag_rounded),
          ],
        ),
        const SizedBox(height: 20),
        if (task.summary.isNotEmpty) ...[
          _buildSectionTitle(context, Icons.summarize_outlined, 'tasks.summary'.tr(context)),
          _buildContentCard(context, task.summary, isHtml: false),
          const SizedBox(height: 20),
        ],
        if (task.description.isNotEmpty) ...[
          _buildSectionTitle(context, Icons.description_outlined, 'tasks.description'.tr(context)),
          _buildContentCard(context, task.description, isHtml: true),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, IconData icon, String title) {
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

  Widget _buildSectionCard(BuildContext context, List<Widget> children) {
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

  Widget _buildInfoRow(BuildContext context, String label, String value, {IconData? icon, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Theme.of(context).iconTheme.color?.withOpacity(0.4)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowTwoFields(
    BuildContext context,
    String label1,
    String val1,
    String label2,
    String val2, {
    IconData? icon1,
    IconData? icon2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _buildInfoRow(context, label1, val1, icon: icon1)),
          const SizedBox(width: 12),
          Expanded(child: _buildInfoRow(context, label2, val2, icon: icon2)),
        ],
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, String content, {required bool isHtml}) {
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
      child: isHtml
          ? Html(
              data: content,
              style: {
                "body": Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(13),
                  color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                ),
              },
            )
          : Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
              ),
            ),
    );
  }
}
