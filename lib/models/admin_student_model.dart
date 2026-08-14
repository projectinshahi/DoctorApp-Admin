class CourseInfo {
  final int id;
  final String title;
  final bool isPremium;
  final String status;

  CourseInfo({
    required this.id,
    required this.title,
    required this.isPremium,
    required this.status,
  });

  factory CourseInfo.fromJson(Map<String, dynamic> json) {
    return CourseInfo(
      id: json['id'] as int,
      title: json['title'] ?? '',
      isPremium: json['isPremium'] as bool? ?? false,
      status: json['status'] ?? '',
    );
  }
}

class AdminStudentModel {
  final int id;
  final String? name;
  final String email;
  final String? phone;
  final String status;
  final DateTime createdAt;
  final CourseInfo? course;
  final CourseInfo? courseType;

  AdminStudentModel({
    required this.id,
    this.name,
    required this.email,
    this.phone,
    required this.status,
    required this.createdAt,
    this.course,
    this.courseType,
  });

  factory AdminStudentModel.fromJson(Map<String, dynamic> json) {
    return AdminStudentModel(
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] ?? '',
      phone: json['phone'] as String?,
      status: json['status'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      course: json['course'] != null
          ? CourseInfo.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      courseType: json['courseType'] != null
          ? CourseInfo.fromJson(json['courseType'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 10,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}

class AdminStudentResponse {
  final List<AdminStudentModel> data;
  final PaginationModel pagination;

  AdminStudentResponse({
    required this.data,
    required this.pagination,
  });

  factory AdminStudentResponse.fromJson(Map<String, dynamic> json) {
    return AdminStudentResponse(
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => AdminStudentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: PaginationModel.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}