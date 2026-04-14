class DesignationStat {
  final int id;
  final String name;
  final int totalCount;

  DesignationStat({
    required this.id,
    required this.name,
    required this.totalCount,
  });

  factory DesignationStat.fromJson(Map<String, dynamic> json) {
    return DesignationStat(
      id: int.parse(json['designation_id'].toString()),
      name: json['designation_name'] ?? '',
      totalCount: int.parse(json['total_count'].toString()),
    );
  }
}
