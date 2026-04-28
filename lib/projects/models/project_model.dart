class Project {
  final int id;
  final String title;
  final String status;
  final int progress;
  final String startDate;
  final String endDate;
  final String priority;
  final String team;
  final int departmentId;
  final String departmentName;

  Project({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    required this.startDate,
    required this.endDate,
    required this.priority,
    required this.team,
    required this.departmentId,
    required this.departmentName,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: int.parse(json['project_id'].toString()),
      title: json['title'] ?? '',
      status: json['status']?.toString() ?? '0',
      progress: int.parse(json['project_progress']?.toString() ?? '0'),
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      priority: json['priority']?.toString() ?? '3',
      team: json['assigned_to'] ?? '',
      departmentId: int.parse(json['department_id']?.toString() ?? '0'),
      departmentName: json['department_name'] ?? '-', // This might need a separate join in API if not present
    );
  }
}
