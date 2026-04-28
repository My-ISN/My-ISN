class Task {
  final int id;
  final int projectId;
  final String projectName;
  final String name;
  final String status;
  final int progress;
  final String startDate;
  final String endDate;
  final String description;
  final String assignedTo; // Client users
  final String taskAssignees; // Staff users
  final String assignedToIds;
  final String taskAssigneesIds;
  final String taskHour;
  final String summary;
  final String associatedGoals;

  Task({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.name,
    required this.status,
    required this.progress,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.assignedTo,
    required this.taskAssignees,
    required this.assignedToIds,
    required this.taskAssigneesIds,
    required this.taskHour,
    required this.summary,
    required this.associatedGoals,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: int.parse(json['task_id'].toString()),
      projectId: int.parse(json['project_id']?.toString() ?? '0'),
      projectName: json['project_name'] ?? 'No Project',
      name: json['task_name'] ?? '',
      status: json['task_status']?.toString() ?? '0',
      progress: int.parse(json['task_progress']?.toString() ?? '0'),
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      description: json['description'] ?? '',
      assignedTo: json['assigned_to'] ?? '',
      taskAssignees: json['task_assignees'] ?? '',
      assignedToIds: json['assigned_to_ids'] ?? '',
      taskAssigneesIds: json['task_assignees_ids'] ?? '',
      taskHour: json['task_hour'] ?? '',
      summary: json['summary'] ?? '',
      associatedGoals: json['associated_goals'] ?? '',
    );
  }

  Task copyWith({
    int? id,
    int? projectId,
    String? projectName,
    String? name,
    String? status,
    int? progress,
    String? startDate,
    String? endDate,
    String? description,
    String? assignedTo,
    String? taskAssignees,
    String? assignedToIds,
    String? taskAssigneesIds,
    String? taskHour,
    String? summary,
    String? associatedGoals,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      name: name ?? this.name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      taskAssignees: taskAssignees ?? this.taskAssignees,
      assignedToIds: assignedToIds ?? this.assignedToIds,
      taskAssigneesIds: taskAssigneesIds ?? this.taskAssigneesIds,
      taskHour: taskHour ?? this.taskHour,
      summary: summary ?? this.summary,
      associatedGoals: associatedGoals ?? this.associatedGoals,
    );
  }
}
