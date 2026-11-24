import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/constants/baust_constants.dart';
import '../../../firebase_options.dart';
import '../../auth_rbac/presentation/controllers/auth_controller.dart';

/// Account administration for admins / super admins.
///
/// Privacy rules enforced here (and in firestore.rules):
/// * Admins never see or set a user's password. New accounts get a random
///   throwaway password and the user receives a reset email to choose their own.
/// * There is no "log in as" / impersonation; admins only edit role & status.
/// * Removal is a soft delete (`accountStatus: removed`) which blocks sign-in to
///   the app. Deleting the Firebase Auth record itself needs the Admin SDK.
class UserAdminService {
  final FirebaseFirestore firestore;
  UserAdminService({FirebaseFirestore? firestore}) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => firestore.collection(FirestoreCollections.users);

  /// Roles [actor] may assign or manage.
  static List<String> assignableRoles(UserProfile actor) => actor.isSuperAdmin
      ? const ['student', 'doctor', 'pharmacist', 'admin']
      : (actor.isAdmin ? const ['student', 'doctor', 'pharmacist'] : const []);

  /// Whether [actor] may change or remove [target].
  static bool canManage(UserProfile actor, Map<String, dynamic> target) {
    final role = (target['role'] ?? 'student').toString();
    if (target['uid'] == actor.uid) return false; // never yourself
    if (role == 'superadmin') return false;
    if (role == 'admin') return actor.isSuperAdmin;
    return actor.isAdmin;
  }

  Stream<List<Map<String, dynamic>>> watchUsers() => _users
      .limit(500)
      .snapshots()
      .map(
        (q) => q.docs.map((d) => {...d.data(), 'uid': d.id}).toList()
          ..sort(
            (a, b) => (a['displayName'] ?? '').toString().toLowerCase().compareTo(
              (b['displayName'] ?? '').toString().toLowerCase(),
            ),
          ),
      );

  /// Creates a Firebase Auth account + profile and emails the user a link to set their password.
  Future<String> createUser({
    required UserProfile actor,
    required String email,
    required String displayName,
    required String role,
    String? department,
    String? studentRoll,
    String? designation,
    String? bmdcRegistrationNumber,
    String? phone,
  }) async {
    if (!assignableRoles(actor).contains(role)) {
      throw Exception('You are not allowed to create $role accounts.');
    }
    final cleanEmail = email.trim().toLowerCase();

    // A secondary app keeps the admin signed in on the primary app.
    final app = await Firebase.initializeApp(
      name: 'provisioning-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(email: cleanEmail, password: _randomPassword());
      final uid = cred.user!.uid;
      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {}
      await auth.sendPasswordResetEmail(email: cleanEmail);
      await auth.signOut();

      await _users.doc(uid).set({
        'uid': uid,
        'email': cleanEmail,
        'displayName': displayName.trim(),
        'role': role,
        'emailType': cleanEmail.endsWith('baust.edu.bd') ? 'university' : 'personal',
        'verificationStatus': 'verified',
        'approved': true,
        'accountStatus': 'active',
        'bloodGroupVerified': false,
        // Added by an admin, so the ID check is already done for students.
        'idVerificationStatus': role == 'student' ? 'verified' : null,
        'profileCompleted': role != 'student' || (studentRoll ?? '').isNotEmpty,
        'onboardingStatus': role == 'student'
            ? ((studentRoll ?? '').isNotEmpty ? 'DOCS_PENDING' : 'PROFILE_PENDING')
            : 'COMPLETED',
        if ((department ?? '').isNotEmpty) 'department': department,
        if ((studentRoll ?? '').isNotEmpty) 'studentRoll': studentRoll,
        if ((designation ?? '').isNotEmpty) 'designation': designation,
        if ((bmdcRegistrationNumber ?? '').isNotEmpty) 'bmdcRegistrationNumber': bmdcRegistrationNumber,
        if ((phone ?? '').isNotEmpty) 'phone': phone,
        'createdBy': actor.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('An account with $cleanEmail already exists. Change its role from the user list instead.');
      }
      throw Exception(e.message ?? e.code);
    } finally {
      await app.delete();
    }
  }

  Future<void> setRole(UserProfile actor, Map<String, dynamic> target, String role) async {
    if (!canManage(actor, target) || !assignableRoles(actor).contains(role)) {
      throw Exception('Not permitted.');
    }
    await _users.doc(target['uid'] as String).update({
      'role': role,
      'approved': true,
      'roleChangedBy': actor.email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRemoved(UserProfile actor, Map<String, dynamic> target, bool removed) async {
    if (!canManage(actor, target)) throw Exception('Not permitted.');
    await _users.doc(target['uid'] as String).update({
      'accountStatus': removed ? 'removed' : 'active',
      'removedBy': removed ? actor.email : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _randomPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%^*';
    final r = Random.secure();
    return List.generate(28, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

/// Feedback & bug reports (any user can submit; super admins review).
class FeedbackService {
  final FirebaseFirestore firestore;
  FeedbackService({FirebaseFirestore? firestore}) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => firestore.collection('feedback');

  Future<void> submit({
    required UserProfile? user,
    required String type,
    required String message,
    String? screen,
    String? platform,
  }) => _col.add({
    'uid': user?.uid ?? '',
    'email': user?.email ?? '',
    'displayName': user?.displayName ?? '',
    'role': user?.appRole ?? 'unknown',
    'type': type,
    'message': message.trim(),
    'screen': screen ?? '',
    'platform': platform ?? '',
    'status': 'open',
    'createdAt': FieldValue.serverTimestamp(),
  });

  Stream<List<Map<String, dynamic>>> watch(String status) =>
      _col.where('status', isEqualTo: status).limit(200).snapshots().map((q) {
        final list = q.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        int ts(Map m) => m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).millisecondsSinceEpoch : 0;
        list.sort((a, b) => ts(b).compareTo(ts(a)));
        return list;
      });

  Future<void> setStatus(String id, String status, {String? note, String? by}) => _col.doc(id).update({
    'status': status,
    'adminNote': ?note,
    'resolvedBy': ?by,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(String id) => _col.doc(id).delete();
}
