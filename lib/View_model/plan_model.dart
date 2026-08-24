// lib/View_model/plan_model.dart
class PlanModel {
  final int id;
  final int courseId;
  final String title;
  final String? description;
  final double price;
  final int durationDays;
  final bool isActive;

  /// "What you get" bullets. Backend may send a `features` array; if it
  /// doesn't, we fall back to splitting the description on newlines/bullets.
  final List<String> features;

  PlanModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.price,
    required this.durationDays,
    required this.isActive,
    this.features = const [],
  });

  static List<String> _bullets(dynamic raw) {
    if (raw is! String) return const [];
    return raw
        .split(RegExp(r'[\n•;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'],
      courseId: json['courseId'],
      title: json['title'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      durationDays: json['durationDays'],
      isActive: json['isActive'] ?? true,
      features: (json['features'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          _bullets(json['description']),
    );
  }

  /// 30 days reads better as "month" on the card than "30 days".
  String get periodLabel {
    if (durationDays >= 28 && durationDays <= 31) return 'month';
    if (durationDays >= 360 && durationDays <= 366) return 'year';
    if (durationDays == 7) return 'week';
    return '$durationDays days';
  }
}
