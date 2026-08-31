class UserProfile {
  final String id;
  final String companyId;
  final String role;
  final String? warehouseId;
  final String email;

  UserProfile({
    required this.id,
    required this.companyId,
    required this.role,
    this.warehouseId,
    required this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j["id"] as String,
        companyId: j["companyId"] as String,
        role: j["role"] as String,
        warehouseId: j["warehouseId"] as String?,
        email: j["email"] as String? ?? "",
      );
}