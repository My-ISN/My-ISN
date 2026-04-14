class JobDesk {
  final int id;
  final String title;
  final String note;
  final String color;

  JobDesk({
    required this.id,
    required this.title,
    required this.note,
    required this.color,
  });

  factory JobDesk.fromJson(Map<String, dynamic> json) {
    return JobDesk(
      id: int.parse(json['event_id'].toString()),
      title: json['item_name'] ?? '',
      note: json['item_note'] ?? '',
      color: json['item_color'] ?? '#7267EF',
    );
  }
}
