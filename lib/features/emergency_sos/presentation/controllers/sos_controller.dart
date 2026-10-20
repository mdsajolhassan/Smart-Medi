import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/baust_constants.dart';

// UI State for the SOS workflow
enum SosStatus { idle, triggering, triggered, failed }

class SosState {
  final SosStatus status;
  final String? activeAlertId;
  final String? errorMessage;

  const SosState({
    required this.status,
    this.activeAlertId,
    this.errorMessage,
  });

  factory SosState.initial() => const SosState(status: SosStatus.idle);

  SosState copyWith({
    SosStatus? status,
    String? activeAlertId,
    String? errorMessage,
  }) {
    return SosState(
      status: status ?? this.status,
      activeAlertId: activeAlertId ?? this.activeAlertId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Modern Riverpod 3.x Notifier
class SosNotifier extends Notifier<SosState> {
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  @override
  SosState build() {
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    return SosState.initial();
  }

  Future<void> triggerEmergency({
    required String residentialHall,
    required String roomNumber,
    required String symptomCategory,
    String? optionalNote,
    String? studentName,
    String? studentRoll,
    String? department,
  }) async {
    state = state.copyWith(status: SosStatus.triggering, errorMessage: null);

    try {
      final user = _auth.currentUser;
      final studentUid = user?.uid ?? 'guest_student_${DateTime.now().millisecondsSinceEpoch}';
      final studentEmail = user?.email ?? 'unauthenticated_user@baust.edu.bd';

      // 1. Fetch denormalized student profile details if available
      String effectiveStudentName = (studentName != null && studentName.trim().isNotEmpty)
          ? studentName.trim()
          : (user?.displayName ?? 'Student (${user?.phoneNumber ?? "Emergency Caller"})');
      String effectiveStudentRoll = (studentRoll != null && studentRoll.trim().isNotEmpty)
          ? studentRoll.trim()
          : 'N/A';
      String advisorId = 'unassigned';
      String effectiveDepartment = (department != null && department.trim().isNotEmpty)
          ? department.trim()
          : 'General';
      List<String> criticalFlags = [];

      try {
        final studentDoc = await _firestore
            .collection(FirestoreCollections.students)
            .doc(studentUid)
            .get();

        if (studentDoc.exists && studentDoc.data() != null) {
          final data = studentDoc.data()!;
          if (effectiveStudentRoll == 'N/A' || effectiveStudentRoll.isEmpty) {
            effectiveStudentRoll = data['studentRoll'] ?? data['studentId'] ?? effectiveStudentRoll;
          }
          advisorId = data['advisorId'] ?? advisorId;
          if (effectiveDepartment == 'General' && data['department'] != null) {
            effectiveDepartment = data['department'];
          }
          criticalFlags = List<String>.from(data['criticalFlags'] ?? []);
        }

        final userDoc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(studentUid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          if (effectiveStudentName.startsWith('Student (') && uData['displayName'] != null) {
            effectiveStudentName = uData['displayName'];
          }
          if (effectiveStudentRoll == 'N/A' || effectiveStudentRoll.isEmpty) {
            effectiveStudentRoll = uData['studentRoll'] ?? uData['studentId'] ?? effectiveStudentRoll;
          }
          if (effectiveDepartment == 'General' && uData['department'] != null) {
            effectiveDepartment = uData['department'];
          }
        }
      } catch (_) {
        // Fallback to emergency trigger even if profile read fails
      }

      // Fetch emergency contact snapshot so doctors receive contact info without needing read access to emergency_contacts
      Map<String, dynamic>? emergencyContactSnapshot;
      try {
        final contactDoc = await _firestore
            .collection('emergency_contacts')
            .doc(studentUid)
            .get();
        if (contactDoc.exists && contactDoc.data() != null) {
          final cData = contactDoc.data()!;
          emergencyContactSnapshot = {
            'name': (cData['name'] ?? '').toString(),
            'phone': (cData['phone'] ?? cData['primaryContact'] ?? '').toString(),
            'relationship': (cData['relationship'] ?? '').toString(),
          };
        }
      } catch (_) {
        // Non-blocking fallback if contact doc is missing or unreadable
      }

      // 2. Create high-priority document in emergency_alerts
      final alertDocRef = _firestore.collection(FirestoreCollections.emergencyAlerts).doc();

      final payload = {
        'alertId': alertDocRef.id,
        'studentId': studentUid,
        'studentName': effectiveStudentName,
        'studentEmail': studentEmail,
        'studentRoll': effectiveStudentRoll,
        'department': effectiveDepartment,
        'advisorId': advisorId,
        'hall': residentialHall,
        'roomNumber': roomNumber.trim().isEmpty ? 'Not Provided' : roomNumber.trim(),
        'symptomCategory': symptomCategory,
        'optionalNote': optionalNote?.trim() ?? '',
        'criticalFlags': criticalFlags,
        'status': 'TRIGGERED', // TRIGGERED | ACKNOWLEDGED | RESOLVED
        'triggeredAt': FieldValue.serverTimestamp(),
        'acknowledgedAt': null,
        'acknowledgedByDoctorId': null,
        'emergencyContact': ?emergencyContactSnapshot,
      };

      await alertDocRef.set(payload);

      state = state.copyWith(
        status: SosStatus.triggered,
        activeAlertId: alertDocRef.id,
      );
    } catch (e) {
      state = state.copyWith(
        status: SosStatus.failed,
        errorMessage: 'Failed to dispatch SOS alert: $e',
      );
    }
  }

  void resetAlert() {
    state = SosState.initial();
  }
}

// Global Riverpod Notifier Provider
final sosControllerProvider = NotifierProvider<SosNotifier, SosState>(SosNotifier.new);
