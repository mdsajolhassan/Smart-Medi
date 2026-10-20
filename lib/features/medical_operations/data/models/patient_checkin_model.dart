import 'package:cloud_firestore/cloud_firestore.dart';

/// Patient check-in and visit log model for BAUST Medical Center staff.
class PatientCheckIn {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime arrivalTime;
  final String purpose;
  final String recordedBy;
  final String? notes;
  final String status;
  final String? department;

  const PatientCheckIn({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.arrivalTime,
    required this.purpose,
    required this.recordedBy,
    this.notes,
    this.status = 'Completed',
    this.department,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'arrivalTime': Timestamp.fromDate(arrivalTime),
      'purpose': purpose,
      'recordedBy': recordedBy,
      if (notes != null) 'notes': notes,
      'status': status,
      if (department != null) 'department': department,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory PatientCheckIn.fromFirestore(String docId, Map<String, dynamic> data) {
    DateTime parsedArrival = DateTime.now();
    final arrivalRaw = data['arrivalTime'];
    if (arrivalRaw is Timestamp) {
      parsedArrival = arrivalRaw.toDate();
    } else if (arrivalRaw is String) {
      parsedArrival = DateTime.tryParse(arrivalRaw) ?? DateTime.now();
    }

    return PatientCheckIn(
      id: docId,
      studentId: (data['studentId'] ?? data['studentRoll'] ?? 'N/A').toString(),
      studentName: (data['studentName'] ?? 'Unknown Student').toString(),
      arrivalTime: parsedArrival,
      purpose: (data['purpose'] ?? 'General Consultation').toString(),
      recordedBy: (data['recordedBy'] ?? 'BAUST Medical Center').toString(),
      notes: data['notes']?.toString(),
      status: (data['status'] ?? 'Completed').toString(),
      department: data['department']?.toString(),
    );
  }

  PatientCheckIn copyWith({
    String? id,
    String? studentId,
    String? studentName,
    DateTime? arrivalTime,
    String? purpose,
    String? recordedBy,
    String? notes,
    String? status,
    String? department,
  }) {
    return PatientCheckIn(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      purpose: purpose ?? this.purpose,
      recordedBy: recordedBy ?? this.recordedBy,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      department: department ?? this.department,
    );
  }
}
