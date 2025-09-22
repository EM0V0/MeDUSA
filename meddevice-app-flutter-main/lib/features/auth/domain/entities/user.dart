class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime? lastLogin;
  final bool isActive;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.lastLogin,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'lastLogin': lastLogin?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle backend response format with first_name/last_name
    String fullName;
    if (json.containsKey('first_name') && json.containsKey('last_name')) {
      final firstName = json['first_name'] ?? '';
      final lastName = json['last_name'] ?? '';
      fullName = '$firstName $lastName'.trim();
    } else {
      fullName = json['name'] ?? '';
    }
    
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: fullName,
      role: json['role'] ?? 'user',
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : null,
      isActive: json['is_active'] ?? true,
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}
