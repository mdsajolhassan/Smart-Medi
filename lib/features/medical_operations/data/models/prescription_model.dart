import 'package:cloud_firestore/cloud_firestore.dart';

class PrescriptionItem {
  final String name;
  final String dose;
  final String frequency;
  final String duration;
  final String? instructions;

  const PrescriptionItem({
    required this.name,
    required this.dose,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'dose': dose.trim(),
      'frequency': frequency.trim(),
      'duration': duration.trim(),
    };
    if (instructions != null && instructions!.trim().isNotEmpty) {
      map['instructions'] = instructions!.trim();
    }
    return map;
  }

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) {
    return PrescriptionItem(
      name: map['name']?.toString() ?? '',
      dose: map['dose']?.toString() ?? '',
      frequency: map['frequency']?.toString() ?? '',
      duration: map['duration']?.toString() ?? '',
      instructions: map['instructions']?.toString(),
    );
  }
}

class PrescriptionModel {
  final String id;
  final String studentUid;
  final String studentId;
  final String studentName;
  final String doctorUid;
  final String doctorName;
  final String doctorDesignation;
  final String diagnosis;
  final List<PrescriptionItem> items;
  final String? advice;
  final DateTime? followUpDate;
  final String source; // strictly 'digital'
  final DateTime? createdAt;

  // Optional display metadata (joined on client for PDF/viewing)
  final String? studentDepartment;
  final String? studentBloodGroup;

  const PrescriptionModel({
    required this.id,
    required this.studentUid,
    required this.studentId,
    required this.studentName,
    required this.doctorUid,
    required this.doctorName,
    required this.doctorDesignation,
    required this.diagnosis,
    required this.items,
    this.advice,
    this.followUpDate,
    this.source = 'digital',
    this.createdAt,
    this.studentDepartment,
    this.studentBloodGroup,
  });

  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{
      'studentUid': studentUid,
      'studentId': studentId,
      'studentName': studentName,
      'doctorUid': doctorUid,
      'doctorName': doctorName,
      'doctorDesignation': doctorDesignation,
      'diagnosis': diagnosis.trim(),
      'items': items.map((e) => e.toMap()).toList(),
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (advice != null && advice!.trim().isNotEmpty) {
      map['advice'] = advice!.trim();
    }
    if (followUpDate != null) {
      map['followUpDate'] = Timestamp.fromDate(followUpDate!);
    }
    return map;
  }

  factory PrescriptionModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PrescriptionModel.fromMap(doc.id, data);
  }

  factory PrescriptionModel.fromMap(String id, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final List<PrescriptionItem> itemsList = [];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemsList.add(PrescriptionItem.fromMap(item));
        } else if (item is Map) {
          itemsList.add(PrescriptionItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    DateTime? followUp;
    if (data['followUpDate'] is Timestamp) {
      followUp = (data['followUpDate'] as Timestamp).toDate();
    } else if (data['followUpDate'] is String) {
      followUp = DateTime.tryParse(data['followUpDate']);
    }

    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt']);
    }

    return PrescriptionModel(
      id: id,
      studentUid: data['studentUid']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      doctorUid: data['doctorUid']?.toString() ?? '',
      doctorName: data['doctorName']?.toString() ?? '',
      doctorDesignation: data['doctorDesignation']?.toString() ?? '',
      diagnosis: data['diagnosis']?.toString() ?? '',
      items: itemsList,
      advice: data['advice']?.toString(),
      followUpDate: followUp,
      source: data['source']?.toString() ?? 'digital',
      createdAt: created,
    );
  }
}
