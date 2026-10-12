class HistorySummaryModel {
  final int total;
  final int completed;
  final double totalRevenue;

  const HistorySummaryModel({
    this.total = 0,
    this.completed = 0,
    this.totalRevenue = 0.0,
  });

  factory HistorySummaryModel.fromJson(Map<String, dynamic> json) {
    return HistorySummaryModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'completed': completed,
    'total_revenue': totalRevenue,
  };
}

class PaginatedResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PaginatedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}
