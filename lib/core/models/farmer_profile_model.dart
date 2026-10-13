import '../utils/rtdb_value_parser.dart';

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
      name: readRtdbString(map, 'name'),
      email: readRtdbString(map, 'email'),
      role: readRtdbString(map, 'role', fallback: 'Farmer'),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'email': email, 'role': role};
  }
}
