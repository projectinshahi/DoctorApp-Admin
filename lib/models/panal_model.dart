// lib/models/admin_plan_model.dart
class AdminPlanModel {
  final int id;
  final int courseId;
  final String title;
  final String? description;
  final double price;
  final int durationDays;
  final bool isActive;

  AdminPlanModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.price,
    required this.durationDays,
    required this.isActive,
  });

  factory AdminPlanModel.fromJson(Map<String, dynamic> json) {
    return AdminPlanModel(
      id: json['id'],
      courseId: json['courseId'],
      title: json['title'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      durationDays: json['durationDays'],
      isActive: json['isActive'] ?? true,
    );
  }
}