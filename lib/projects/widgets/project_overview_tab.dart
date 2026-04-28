import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../localization/app_localizations.dart';

class ProjectOverviewTab extends StatelessWidget {
  final Map<String, dynamic> project;

  const ProjectOverviewTab({super.key, required this.project});

  String _calculateRemainingDays(BuildContext context, String endDateStr) {
    if (endDateStr.isEmpty) return 'N/A';
    try {
      final now = DateTime.now();
      final end = DateTime.parse(endDateStr);
      final diff = end.difference(now).inDays;
      if (diff < 0) return 'projects.overdue'.tr(context, args: {'days': diff.abs().toString()});
      if (diff == 0) return 'projects.today'.tr(context);
      return 'projects.days_left'.tr(context, args: {'days': diff.toString()});
    } catch (e) {
      return endDateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final endDateStr = project['end_date'] ?? '';
    final remainingDays = _calculateRemainingDays(context, endDateStr);
    
    bool isOverdue = false;
    try {
      if (endDateStr.isNotEmpty) {
        final end = DateTime.parse(endDateStr);
        isOverdue = end.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      }
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, Icons.info_outline, 'projects.main_info'.tr(context)),
        _buildSectionCard(
          context,
          [
            _buildInfoRow(context, 'projects.project_name'.tr(context), project['title'] ?? '-', icon: Icons.work_outline),
            _buildRowTwoFields(
              context,
              'projects.start_date'.tr(context),
              _formatDate(project['start_date']),
              'projects.end_date'.tr(context),
              _formatDate(project['end_date']),
              icon1: Icons.calendar_today_rounded,
              icon2: Icons.event_available_rounded,
            ),
            _buildRowTwoFields(
              context,
              'projects.budget_hours'.tr(context),
              project['estimated_hour']?.toString() ?? '0',
              'tasks.remaining_time'.tr(context),
              remainingDays,
              icon1: Icons.access_time_rounded,
              icon2: Icons.timer_outlined,
              valueColor2: isOverdue ? Colors.red : const Color(0xFF7E57C2),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(context, Icons.people_outline, 'projects.team_project'.tr(context)),
        _buildSectionCard(
          context,
          [
            _buildTeamRow(context),
            const SizedBox(height: 16),
            _buildInfoRow(context, 'projects.department'.tr(context), project['department_name'] ?? '-', icon: Icons.business_outlined),
          ],
        ),
        const SizedBox(height: 20),
        if (project['summary'] != null && project['summary'].toString().isNotEmpty) ...[
          _buildSectionTitle(context, Icons.summarize_outlined, 'projects.summary'.tr(context)),
          _buildContentCard(context, project['summary'], isHtml: false),
          const SizedBox(height: 20),
        ],
        if (project['description'] != null && project['description'].toString().isNotEmpty) ...[
          _buildSectionTitle(context, Icons.description_outlined, 'projects.description'.tr(context)),
          _buildContentCard(context, project['description'], isHtml: true),
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
            Icon(icon, size: 16, color: Colors.grey[400]),
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
                    color: Colors.grey[500],
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
    Color? valueColor1,
    Color? valueColor2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _buildInfoRow(context, label1, val1, icon: icon1, valueColor: valueColor1)),
          const SizedBox(width: 12),
          Expanded(child: _buildInfoRow(context, label2, val2, icon: icon2, valueColor: valueColor2)),
        ],
      ),
    );
  }

  Widget _buildTeamRow(BuildContext context) {
    final members = project['members'] as List? ?? [];
    final memberNames = members.map((m) => m['name'] ?? '').where((name) => name.isNotEmpty).join(', ');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 12),
            Text(
              'projects.team_members_label'.tr(context).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          memberNames.isEmpty ? '-' : memberNames,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
