import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'localization/app_localizations.dart';
import 'widgets/connectivity_wrapper.dart';
import 'constants.dart';
import 'maintenance_page.dart';
import 'widgets/custom_snackbar.dart';



class AttendancePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AttendancePage({super.key, required this.userData});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  bool _isSummaryExpanded = false;
  Map<String, dynamic> _attendanceData = {};
  final Color _primaryColor = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final month = _selectedMonth.month;
      final year = _selectedMonth.year;

      final url =
          '${AppConstants.baseUrl}/get_attendance?user_id=$userId&month=$month&year=$year';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 503) {
        if (mounted) {
          final data = json.decode(response.body);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MaintenancePage(message: data['message']),
            ),
          );
        }
        return;
      }

      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _attendanceData = data['data'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
          data['message'] ?? 'attendance.fetch_error'.tr(context),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Don't show redundant snackbar if we are offline
        if (!ConnectivityStatus.of(context)) return;

        String errorMessage = e.toString();
        if (errorMessage.contains('SocketException') ||
            errorMessage.contains('ClientException') ||
            errorMessage.contains('HandshakeException')) {
          errorMessage = 'login.conn_error'.tr(context);
        }

        context.showErrorSnackBar(
          'main.error_with_msg'.tr(
            context,
            args: {'message': errorMessage},
          ),
        );
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    _fetchAttendance(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchAttendance,
                    color: _primaryColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(),
                          const SizedBox(height: 24),
                          _buildCalendarGrid(),
                          ValueListenableBuilder<double>(
                            valueListenable: ConnectivityStatus.bottomPadding,
                            builder: (context, padding, _) => SizedBox(
                              height: padding.clamp(0.0, double.infinity),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final firstDayOffset =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday % 7;

    final weekdayLabels = ['0', '1', '2', '3', '4', '5', '6'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: _primaryColor),
                onPressed: () => _changeMonth(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${'attendance.months.${_selectedMonth.month}'.tr(context)} ${_selectedMonth.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: _primaryColor),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdayLabels
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        'attendance.weekdays_short.$day'.tr(context),
                        style: TextStyle(
                          color: day == '0' || day == '6'
                              ? Colors.red
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          // Menggunakan Column & Row manual agar tinggi benar-benar pas (tidak ada sisa ruang)
          Column(
            children: List.generate(((daysInMonth + firstDayOffset) / 7).ceil(), (
              rowIndex,
            ) {
              return Row(
                children: List.generate(7, (colIndex) {
                  final index = rowIndex * 7 + colIndex;
                  if (index < firstDayOffset ||
                      index >= daysInMonth + firstDayOffset) {
                    return const Expanded(child: SizedBox());
                  }

                  final day = index - firstDayOffset + 1;
                  final dateStr =
                      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

                  final record = (_attendanceData['records'] as List?)
                      ?.firstWhere(
                        (r) => r['date'] == dateStr,
                        orElse: () => null,
                      );

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: AspectRatio(
                        aspectRatio: 1.05,
                        child: _buildDayCell(day, record),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(int day, Map<String, dynamic>? record) {
    final bool isPresent =
        record != null &&
        (record['status'] == 'Present' ||
            record['attendance_status'] == 'Present');
    final bool isLate = record != null && record['is_late'] == true;

    final DateTime now = DateTime.now();
    final bool isToday =
        now.year == _selectedMonth.year &&
        now.month == _selectedMonth.month &&
        now.day == day;

    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final bool isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final bool isHoliday =
        (_attendanceData['holidays'] as List?)?.any(
          (h) => h['date'] == dateStr,
        ) ??
        false;

    return GestureDetector(
      onTap: () => _showDayDetails(day, record),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? _primaryColor.withValues(alpha: 0.05) : Colors.transparent,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: _primaryColor, width: 2.2) : null,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: isToday
                      ? _primaryColor
                      : (isWeekend || isHoliday
                            ? Colors.red.shade400
                            : (isPresent
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.grey.shade400)),
                  fontSize: 15,
                ),
              ),
            ),
            if (isPresent)
              Align(
                alignment: const Alignment(0, 0.82),
                child: Container(
                  width: 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isLate ? Colors.orange : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayDetails(int day, Map<String, dynamic>? record) {
    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final dayLabel = 'attendance.weekdays.${date.weekday % 7}'.tr(context);
    final monthLabel = 'attendance.months.${date.month}'.tr(context);

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final holiday = (_attendanceData['holidays'] as List?)?.firstWhere(
      (h) => h['date'] == dateStr,
      orElse: () => null,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white24
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$dayLabel, $day $monthLabel ${_selectedMonth.year}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (holiday != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          holiday['name'],
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _buildDetailItem(
                  'attendance.details'.tr(context),
                  record?['status'] == 'Present'
                      ? 'attendance.present'.tr(context)
                      : (record?['status'] == 'Late'
                            ? 'attendance.late'.tr(context)
                            : (record?['status'] ??
                                  'attendance.no_data'.tr(context))),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      'attendance.check_in'.tr(context),
                      record?['clock_in'] ?? '-',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      'attendance.check_out'.tr(context),
                      record?['clock_out'] ?? '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (record?['is_late'] == true || record?['is_early'] == true)
                SizedBox(
                  width: double.infinity,
                  child: _buildDetailItem(
                    'attendance.notes'.tr(context),
                    "${record?['is_late'] == true ? 'attendance.late_with_time'.tr(context, args: {'time': record?['late_time']}) : ''}"
                    "${record?['is_late'] == true && record?['is_early'] == true ? ' & ' : ''}"
                    "${record?['is_early'] == true ? 'attendance.early_with_time'.tr(context, args: {'time': record?['early_time']}) : ''}",
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withAlpha(13)
            : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _attendanceData['summary'] ?? {};
    final present = summary['present'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isSummaryExpanded = !_isSummaryExpanded),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'attendance.summary'.tr(context),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Icon(
                          _isSummaryExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        _buildSummaryStat(
                          'attendance.present'.tr(context),
                          present,
                          const Color(0xFF2ECC71),
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryStat(
                          'attendance.late'.tr(context),
                          summary['late'] ?? 0,
                          Colors.orange,
                        ),
                        if (_isSummaryExpanded) ...[
                          const SizedBox(height: 8),
                          _buildSummaryStat(
                            'attendance.absent'.tr(context),
                            summary['absent'] ?? 0,
                            Colors.red.shade400,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryStat(
                            'attendance.early_leave'.tr(context),
                            summary['early_leave'] ?? 0,
                            Colors.blue.shade400,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryStat(
                            'attendance.total_rest'.tr(context),
                            summary['total_rest'] ?? '0 jam',
                            _primaryColor,
                            showAsText: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
    String label,
    dynamic value,
    Color color, {
    bool showAsText = false,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class DonutPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Brightness brightness;

  DonutPainter({
    required this.percent,
    required this.color,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = brightness == Brightness.dark
          ? Colors.white12
          : Colors.grey.withAlpha(13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
