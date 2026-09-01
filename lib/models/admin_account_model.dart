/// The signed-in admin, as GET /admin/me reports them.
///
/// Note the mount: /admin/me sits at the ROOT, like /admin/students - not
/// under /api/ where the course and test endpoints live.
class AdminAccount {
  final int id;
  final String email;
  final String? name;

  /// What the account may do. Not editable from the panel: a stolen token
  /// must not be able to promote itself.
  final String role;

  /// Whether the account may sign in at all. Read-only for the same reason.
  final String status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminAccount({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  String get displayName {
    final trimmed = name?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : email;
  }

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        id: (json['id'] as num?)?.toInt() ?? 0,
        email: (json['email'] ?? '') as String,
        name: json['name'] as String?,
        role: (json['role'] ?? '') as String,
        status: (json['status'] ?? '') as String,
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
        updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
      );
}
