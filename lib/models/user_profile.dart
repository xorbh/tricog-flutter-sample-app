import 'dart:convert';

class UserProfile {
  final int? id;
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final List<String> medicalConditions;
  final String? medications;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    this.id,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.medicalConditions,
    this.medications,
    required this.createdAt,
    required this.updatedAt,
  });

  int get age {
    final now = DateTime.now();
    int years = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      years--;
    }
    return years;
  }

  static const List<String> commonConditions = [
    'Hypertension',
    'Diabetes',
    'Heart Disease',
    'High Cholesterol',
    'Arrhythmia',
    'Previous Heart Attack',
    'Heart Failure',
    'Thyroid Disease',
    'Asthma/COPD',
    'Kidney Disease',
  ];

  UserProfile copyWith({
    int? id,
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    List<String>? medicalConditions,
    String? medications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medications: medications ?? this.medications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'name': name,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'medical_conditions': jsonEncode(medicalConditions),
      'medications': medications,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      dateOfBirth: DateTime.parse(map['date_of_birth'] as String),
      gender: map['gender'] as String,
      medicalConditions: (jsonDecode(map['medical_conditions'] as String) as List)
          .map((e) => e as String)
          .toList(),
      medications: map['medications'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
