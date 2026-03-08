import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'localization/app_localizations.dart';

class AttendancePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AttendancePage({super.key, required this.userData});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  Map<String, dynamic> _attendanceData = {};
  final Color _primaryColor = const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
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
          });
        }
      } else {
        throw Exception(
          data['message'] ?? 'attendance.fetch_error'.tr(context),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'attendance.error_with_msg'.tr(
                context,
                args: {'message': e.toString()},
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
    _fetchAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMonthSelector(),
                        const SizedBox(height: 20),
                        _buildCalendarGrid(),
                        const SizedBox(height: 32),
                        Text(
                          'attendance.summary'.tr(context),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1F36),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCard(),
                        const SizedBox(height: 100), // Space for bottom nav
                      ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F36),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
    bool isPresent = record != null && record['status'] == 'Present';
    bool isLate = record != null && record['is_late'] == true;

    // Check if it's weekend (Saturday or Sunday)
    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final bool isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    // Check if it's a holiday from JSON data
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
          color: isPresent
              ? (isLate
                    ? const Color(0xFF7E57C2).withOpacity(0.1)
                    : _primaryColor.withOpacity(0.1))
              : Colors.grey.withOpacity(0.05),
          shape: BoxShape.circle,
          border: isPresent
              ? Border.all(
                  color: isLate ? const Color(0xFF7E57C2) : _primaryColor,
                  width: 1.5,
                )
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (isWeekend || isHoliday)
                      ? Colors.red.shade400
                      : (isPresent ? _textColor : Colors.grey.shade400),
                  fontSize: 14,
                ),
              ),
              if (isPresent)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: isLate ? const Color(0xFF7E57C2) : _primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
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
                  color: Colors.grey.shade300,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1F36),
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
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        holiday['name'],
                        style: TextStyle(
                          color: Colors.red.shade700,
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
                    : (record?['status'] ?? 'attendance.no_data'.tr(context)),
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
            if (record?['is_late'] == true)
              SizedBox(
                width: double.infinity,
                child: _buildDetailItem(
                  'attendance.notes'.tr(context),
                  'attendance.late_with_time'.tr(
                    context,
                    args: {'time': record?['late_time']},
                  ),
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
        color: const Color(0xFFF8FAFF),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                  _primaryColor,
                ),
                const SizedBox(height: 12),
                _buildSummaryStat(
                  'attendance.late'.tr(context),
                  summary['late'] ?? 0,
                  const Color(0xFFF39C12),
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
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const Spacer(),
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  final Color _textColor = const Color(0xFF1A1F36);
}

class DonutPainter extends CustomPainter {
  final double percent;
  final Color color;

  DonutPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
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
