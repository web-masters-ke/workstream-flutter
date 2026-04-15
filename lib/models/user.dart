/// Authenticated WorkStream user (agent role).
class User {
  final String id;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String role;
  final bool kycVerified;
  final bool available;
  final double rating;
  final int tasksCompleted;
  final double lifetimeEarnings;
  final List<String> skills;
  final String? address;
  final String? idNumber;

  User({
    required this.id,
    required this.email,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.role,
    required this.kycVerified,
    this.available = false,
    this.rating = 0,
    this.tasksCompleted = 0,
    this.lifetimeEarnings = 0,
    this.skills = const [],
    this.address,
    this.idNumber,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isAdmin =>
      role == 'ADMIN' ||
      role == 'SUPER_ADMIN' ||
      role == 'MANAGER' ||
      role == 'SUPERVISOR';
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    return (a + b).toUpperCase();
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? phone,
    String? email,
    String? address,
    String? idNumber,
    bool? available,
    bool? kycVerified,
    List<String>? skills,
  }) => User(
    id: id,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    role: role,
    kycVerified: kycVerified ?? this.kycVerified,
    available: available ?? this.available,
    rating: rating,
    tasksCompleted: tasksCompleted,
    lifetimeEarnings: lifetimeEarnings,
    skills: skills ?? this.skills,
    address: address ?? this.address,
    idNumber: idNumber ?? this.idNumber,
  );

  factory User.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      role: json['role']?.toString() ?? 'AGENT',
      kycVerified: json['kycVerified'] == true,
      available: json['available'] == true,
      rating: d(json['rating']),
      tasksCompleted: i(json['tasksCompleted']),
      lifetimeEarnings: d(json['lifetimeEarnings']),
      skills: json['skills'] is List
          ? (json['skills'] as List).map((e) => e.toString()).toList()
          : const [],
      address: json['address']?.toString(),
      idNumber: json['idNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'firstName': firstName,
    'lastName': lastName,
    'avatarUrl': avatarUrl,
    'role': role,
    'kycVerified': kycVerified,
    'available': available,
    'rating': rating,
    'tasksCompleted': tasksCompleted,
    'lifetimeEarnings': lifetimeEarnings,
    'skills': skills,
    'address': address,
    'idNumber': idNumber,
  };
}
