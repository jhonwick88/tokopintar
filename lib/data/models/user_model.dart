class UserModel {
  final String uid;
  final String username;
  final String fullname;
  final String role; // admin, cashier
  final String pin;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.username,
    required this.fullname,
    required this.role,
    required this.pin,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['id'] as String? ?? json['uid'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullname: json['full_name'] as String? ?? json['fullname'] as String? ?? '',
      role: json['role'] as String? ?? 'cashier',
      pin: json['pin'] as String? ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'username': username,
      'full_name': fullname,
      'role': role,
      'pin': pin,
      'is_active': isActive ? 1 : 0,
    };
  }
}
