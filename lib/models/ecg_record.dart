import 'dart:convert';

enum Severity { normal, warning, critical }

class ECGRecord {
  final int? id;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final DateTime timestamp;
  final List<double> ecgData;
  final String interpretation;
  final Severity severity;
  final int heartRate;
  final List<String> findings;
  final String? doctorNotes;
  final List<String> symptoms;
  final String? symptomNote;

  ECGRecord({
    this.id,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.timestamp,
    required this.ecgData,
    required this.interpretation,
    required this.severity,
    required this.heartRate,
    required this.findings,
    this.doctorNotes,
    this.symptoms = const [],
    this.symptomNote,
  });

  ECGRecord copyWith({
    int? id,
    String? patientName,
    int? patientAge,
    String? patientGender,
    DateTime? timestamp,
    List<double>? ecgData,
    String? interpretation,
    Severity? severity,
    int? heartRate,
    List<String>? findings,
    String? doctorNotes,
    List<String>? symptoms,
    String? symptomNote,
  }) {
    return ECGRecord(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      timestamp: timestamp ?? this.timestamp,
      ecgData: ecgData ?? this.ecgData,
      interpretation: interpretation ?? this.interpretation,
      severity: severity ?? this.severity,
      heartRate: heartRate ?? this.heartRate,
      findings: findings ?? this.findings,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      symptoms: symptoms ?? this.symptoms,
      symptomNote: symptomNote ?? this.symptomNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_name': patientName,
      'patient_age': patientAge,
      'patient_gender': patientGender,
      'timestamp': timestamp.toIso8601String(),
      'ecg_data': jsonEncode(ecgData),
      'interpretation': interpretation,
      'severity': severity.name,
      'heart_rate': heartRate,
      'findings': jsonEncode(findings),
      'doctor_notes': doctorNotes,
      'symptoms': jsonEncode(symptoms),
      'symptom_note': symptomNote,
    };
  }

  factory ECGRecord.fromMap(Map<String, dynamic> map) {
    return ECGRecord(
      id: map['id'] as int?,
      patientName: map['patient_name'] as String,
      patientAge: map['patient_age'] as int,
      patientGender: map['patient_gender'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      ecgData: (jsonDecode(map['ecg_data'] as String) as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      interpretation: map['interpretation'] as String,
      severity: Severity.values.byName(map['severity'] as String),
      heartRate: map['heart_rate'] as int,
      findings: (jsonDecode(map['findings'] as String) as List)
          .map((e) => e as String)
          .toList(),
      doctorNotes: map['doctor_notes'] as String?,
      symptoms: map['symptoms'] != null
          ? (jsonDecode(map['symptoms'] as String) as List)
              .map((e) => e as String)
              .toList()
          : [],
      symptomNote: map['symptom_note'] as String?,
    );
  }
}
