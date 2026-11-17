enum UserRole {
  customer,
  business,
  admin;

  static UserRole parse(String? raw) {
    return UserRole.values.firstWhere(
      (role) => role.name == raw,
      orElse: () => UserRole.customer,
    );
  }

  String get label => switch (this) {
    UserRole.customer => 'Customer',
    UserRole.business => 'Business',
    UserRole.admin => 'Administrator',
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.email,
  });

  final String id;
  final String phone;
  final String displayName;
  final String? email;
  final UserRole role;
  final DateTime createdAt;

  bool get isBusiness => role == UserRole.business;
  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({String? displayName, String? email, UserRole? role}) {
    return AppUser(
      id: id,
      phone: phone,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json, String id) {
    final rawEmail = json['email'] as String?;
    return AppUser(
      id: id,
      phone: (json['phone'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? 'Nijaora user',
      email: rawEmail == null || rawEmail.trim().isEmpty ? null : rawEmail,
      role: UserRole.parse(json['role'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'displayName': displayName,
    if (email != null) 'email': email,
    'role': role.name,
    'createdAt': createdAt.toIso8601String(),
  };
}
