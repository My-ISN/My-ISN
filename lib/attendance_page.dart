import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'localization/app_localizations.dart';
import 'widgets/connectivity_wrapper.dart';

class AttendancePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AttendancePage({super.key, required this.userData});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _attendanceData = {};
  final Color _primaryColor = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance({bool silent = false}) async {
    if (silent) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final month = _selectedMonth.month;
      final year = _selectedMonth.year;

      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_attendance?user_id=$userId&month=$month&year=$year';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _attendanceData = data['data'];
            _isLoading = false;
            _isRefreshing = false;
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
          _isRefreshing = false;
        });

        // Don't show redundant snackbar if we are offline
        if (!ConnectivityStatus.of(context)) return;

        String errorMessage = e.toString();
        if (errorMessage.contains('SocketException') ||
            errorMessage.contains('ClientException') ||
            errorMessage.contains('HandshakeException')) {
          errorMessage = 'login.conn_error'.tr(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'main.error_with_msg'.tr(
                context,
                args: {'message': errorMessage},
              ),
            ),
            backgroundColor: Colors.red,
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
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchAttendance,
                    color: _primaryColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMonthSelector(),
                          if (_isRefreshing)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  backgroundColor: _primaryColor.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          _buildCalendarGrid(),
                          const SizedBox(height: 32),
                          Text(
                            'attendance.summary'.tr(context),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryCard(),
                          const SizedBox(height: 100), // Space for bottom nav
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF7E57C2)),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            '${'attendance.months.${_selectedMonth.month}'.tr(context)} ${_selectedMonth.year}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF7E57C2)),
            onPressed: () => _changeMonth(1),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
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
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: daysInMonth + firstDayOffset,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox();

              final day = index - firstDayOffset + 1;
              final dateStr =
                  '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

              final record = (_attendanceData['records'] as List?)?.firstWhere(
                (r) => r['date'] == dateStr,
                orElse: () => null,
              );

              return _buildDayCell(day, record);
            },
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
          color: isToday ? _primaryColor.withOpacity(0.15) : Colors.transparent,
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
                          color: Theme.of(context).colorScheme.onErrorContainer,
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
                    : (record?['status'] == 'Late' ? 'attendance.late'.tr(context) : (record?['status'] ?? 'attendance.no_data'.tr(context))),
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
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.05)
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
    final total = summary['total_days'] ?? 1;
    final percent = (present / total) * 100;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: DonutPainter(
                percent: percent / 100,
                color: _primaryColor,
                brightness: Theme.of(context).brightness,
              ),
              child: Center(
                child: Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              children: [
                _buildSummaryStat(
                  'attendance.present'.tr(context),
                  present,
                  const Color(0xFF2ECC71),
                ),
                const SizedBox(height: 12),
                _buildSummaryStat(
                  'attendance.late'.tr(context),
                  summary['late'] ?? 0,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          : Colors.grey.withOpacity(0.1)
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
