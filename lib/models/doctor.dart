class Doctor {
  const Doctor({
    required this.id,
    required this.doctorId,
    required this.name,
    this.specialty = '',
    this.phone = '',
    this.email = '',
    this.isActive = true,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: (json['id'] as num?)?.toInt(),
    doctorId: (json['doctor_id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    specialty: (json['specialty'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    isActive: json['is_active'] as bool? ?? true,
  );

  final int? id;
  final String doctorId;
  final String name;
  final String specialty;
  final String phone;
  final String email;
  final bool isActive;
}
