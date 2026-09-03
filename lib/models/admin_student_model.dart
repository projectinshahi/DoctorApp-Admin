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

/// The only three values the API accepts on PATCH /admin/students/:id/status.
///
/// Anything else is a 400, so this is an enum rather than a free string:
/// "inactive" and "disabled" read like they would work and do not.
enum StudentStatus {
  verified('verified', 'Active'),
  unverified('unverified', 'Unverified'),
  blocked('blocked', 'Blocked');

  final String wire;
  final String label;

  const StudentStatus(this.wire, this.label);

  /// Unknown values keep their own text rather than being forced into one of
  /// the three - a status this panel has not heard of must not render as
  /// "Active".
  static StudentStatus? parse(String raw) {
    final value = raw.trim().toLowerCase();
    for (final status in StudentStatus.values) {
      if (status.wire == value) return status;
    }
    // The list endpoint has historically also returned "active" for a
    // verified student.
    if (value == 'active') return StudentStatus.verified;
    return null;
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

  StudentStatus? get statusValue => StudentStatus.parse(status);

  bool get isBlocked => statusValue == StudentStatus.blocked;

  /// What to show on a chip. Falls back to the server's own word so an
  /// unrecognised status is visible rather than silently normalised.
  String get statusLabel => statusValue?.label ?? (status.isEmpty ? 'Unknown' : status);

  /// Used to carry a status change back from PATCH .../status without
  /// refetching the list. The response returns only the account fields, so
  /// everything else is kept.
  AdminStudentModel copyWith({String? status}) => AdminStudentModel(
        id: id,
        name: name,
        email: email,
        phone: phone,
        status: status ?? this.status,
        createdAt: createdAt,
        course: course,
        courseType: courseType,
      );
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