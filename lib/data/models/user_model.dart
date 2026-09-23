class UserModel {
  final String uid;
  final String username;
  final String fullname;
  final String role; // admin, user
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
    final rawRole = (json['role'] as String? ?? 'user').toLowerCase();
    return UserModel(
      uid: json['uid'] as String? ?? json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullname: json['fullname'] as String? ?? json['full_name'] as String? ?? '',
      role: rawRole == 'admin' ? 'admin' : 'user',
      pin: json['pin'] as String? ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'id': uid,
      'username': username,
      'fullname': fullname,
      'full_name': fullname,
      'role': role.toLowerCase() == 'admin' ? 'admin' : 'user',
      'pin': pin,
      'is_active': isActive ? 1 : 0,
    };
  }
}
