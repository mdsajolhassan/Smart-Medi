import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../data/models/patient_checkin_model.dart';

class PatientCheckInNotifier extends Notifier<List<PatientCheckIn>> {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  List<PatientCheckIn> build() {
    _loadFromFirestore();
    return const [];
  }

  void _loadFromFirestore() {
    try {
      _firestore
          ?.collection(FirestoreCollections.patientCheckins)
          .orderBy('arrivalTime', descending: true)
          .snapshots()
          .listen((snapshot) {
        state = snapshot.docs
            .map((doc) => PatientCheckIn.fromFirestore(doc.id, doc.data()))
            .toList();
      });
    } catch (_) {
      // Non-blocking in offline / test environments
    }
  }

  Future<void> addCheckIn({
    required String studentId,
    required String studentName,
    required String purpose,
    required String recordedBy,
    String? notes,
    String? status,
    String? department,
    DateTime? arrivalTime,
  }) async {
    final entryTime = arrivalTime ?? DateTime.now();
    final newId = 'chk_${entryTime.millisecondsSinceEpoch}';

    final checkIn = PatientCheckIn(
      id: newId,
      studentId: studentId.trim(),
      studentName: studentName.trim(),
      arrivalTime: entryTime,
      purpose: purpose.trim(),
      recordedBy: recordedBy.trim(),
      notes: notes?.trim(),
      status: status ?? 'Completed',
      department: department?.trim(),
    );

    // Update state immediately for instant responsive UI
    state = [checkIn, ...state];

    // Persist to Firestore if available
    try {
      await _firestore
          ?.collection(FirestoreCollections.patientCheckins)
          .doc(newId)
          .set(checkIn.toFirestore(), SetOptions(merge: true));
    } catch (_) {
      // Non-blocking in mock/offline test environments
    }
  }

  Future<void> logFromEmergencyAlert({
    required String studentId,
    required String studentName,
    required String symptom,
    required String recordedBy,
    String? hall,
    String? room,
  }) async {
    final locationInfo = (hall != null && room != null) ? 'Location: $hall, Room $room. ' : '';
    await addCheckIn(
      studentId: studentId,
      studentName: studentName,
      purpose: 'Emergency SOS: $symptom',
      recordedBy: recordedBy,
      status: 'Emergency Processed',
      notes: '${locationInfo}Emergency alert processed and documented at BAUST Medical Center.',
    );
  }
}

final patientCheckInProvider =
    NotifierProvider<PatientCheckInNotifier, List<PatientCheckIn>>(PatientCheckInNotifier.new);
