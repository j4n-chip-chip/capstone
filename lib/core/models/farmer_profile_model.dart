class FarmerProfileModel {
  final String name;
  final String email;
  final String role;

  FarmerProfileModel({
    required this.name,
    required this.email,
    required this.role,
  });

  factory FarmerProfileModel.fromMap(Map<String, dynamic> map) {
    return FarmerProfileModel(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Farmer',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'email': email, 'role': role};
  }
}
