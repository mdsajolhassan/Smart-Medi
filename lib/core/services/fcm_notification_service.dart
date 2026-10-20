import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class EmergencyPushPayload {
  final String alertId;
  final String studentName;
  final String hall;
  final String room;
  final String symptom;
  final DateTime timestamp;

  const EmergencyPushPayload({
    required this.alertId,
    required this.studentName,
    required this.hall,
    required this.room,
    required this.symptom,
    required this.timestamp,
  });
}

class FcmNotificationService {
  FirebaseMessaging? _messaging;
  final _emergencyAlertController = StreamController<EmergencyPushPayload>.broadcast();

  Stream<EmergencyPushPayload> get onEmergencyAlertReceived => _emergencyAlertController.stream;

  Future<void> initialize() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Request push permissions for iOS / Web / Android 13+
      final settings = await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      debugPrint('FCM Notification Authorization Status: ${settings?.authorizationStatus}');

      // Listen for foreground FCM push messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('High-Priority FCM Message Received: ${message.notification?.title}');
        final data = message.data;

        if (data['type'] == 'EMERGENCY_SOS' || message.notification?.title?.contains('SOS') == true) {
          final payload = EmergencyPushPayload(
            alertId: data['alertId'] ?? 'sos_live_${DateTime.now().millisecondsSinceEpoch}',
            studentName: data['studentName'] ?? message.notification?.body?.split(' ').first ?? 'Student',
            hall: data['hall'] ?? 'Residential Hall',
            room: data['room'] ?? 'N/A',
            symptom: data['symptom'] ?? 'Critical Medical Event',
            timestamp: DateTime.now(),
          );
          _emergencyAlertController.add(payload);
        }
      });
    } catch (e) {
      debugPrint('FCM Service running in local simulated mode: $e');
    }
  }

  /// Manually dispatch a simulated high-priority push alert for testing and demonstrations
  void triggerSimulatedIncomingAlert({
    required String studentName,
    required String hall,
    required String room,
    required String symptom,
  }) {
    final payload = EmergencyPushPayload(
      alertId: 'sos_sim_${DateTime.now().millisecondsSinceEpoch}',
      studentName: studentName,
      hall: hall,
      room: room,
      symptom: symptom,
      timestamp: DateTime.now(),
    );
    _emergencyAlertController.add(payload);
  }

  void dispose() {
    _emergencyAlertController.close();
  }
}

final fcmNotificationServiceProvider = Provider<FcmNotificationService>((ref) {
  final service = FcmNotificationService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final emergencyAlertStreamProvider = StreamProvider<EmergencyPushPayload>((ref) {
  final service = ref.watch(fcmNotificationServiceProvider);
  return service.onEmergencyAlertReceived;
});
