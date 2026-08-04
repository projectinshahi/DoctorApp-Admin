class AdminModel {
  final int id;
  final String email;
  final String? name;
  final String role;

  AdminModel({
    required this.id,
    required this.email,
    this.name,
    required this.role,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
    };
  }
}

class AdminAuthResultModel {
  final String token;
  final AdminModel admin;

  AdminAuthResultModel({
    required this.token,
    required this.admin,
  });

  factory AdminAuthResultModel.fromJson(Map<String, dynamic> json) {
    return AdminAuthResultModel(
      token: json['token'],
      admin: AdminModel.fromJson(json['admin']),
    );
  }
}