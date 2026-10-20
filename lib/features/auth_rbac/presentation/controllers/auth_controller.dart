import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/auth_config.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../medical_onboarding_ai/data/services/gemini_ai_service.dart';

class StudentIdAlreadyRegisteredException implements Exception {
  final String message;
  StudentIdAlreadyRegisteredException([this.message = 'This student ID is already registered. Contact the medical center.']);
  @override
  String toString() => message;
}

// User Profile model representing RBAC state
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'student' | 'superadmin' | 'staff' | 'doctor' | 'pharmacist'
  final String? designation; // 'Associate Professor & Head', 'Lecturer', etc.
  final String? accessLevel; // 'VC', 'Proctor', 'Dept Head', 'Batch Coordinator', 'Advisor'
  final String? department;
  final String? studentRoll;
  final String residencyStatus; // 'residential' | 'non_residential'
  final String? residentialHall;
  final String? roomNumber;
  final String? district;
  final String? upazila;
  final String? detailedAddress;
  final String onboardingStatus; // 'PROFILE_PENDING' | 'DOCS_PENDING' | 'COMPLETED'
  final bool profileCompleted;
  final String? level;
  final String? term;
  final String? phone;
  final String emailType; // 'university' | 'personal'
  final String verificationStatus; // 'verified' | 'pending'
  final bool isWillingToDonateBlood;
  final bool? isEligibleForBloodDonation;
  final String? bloodDonationIneligibilityReason;
  final String? bloodGroup;
  final String? bloodGroupSource;
  final bool bloodGroupVerified;
  final String? bmdcRegistrationNumber;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.designation,
    this.accessLevel,
    this.department,
    this.studentRoll,
    this.residencyStatus = 'residential',
    this.residentialHall,
    this.roomNumber,
    this.district,
    this.upazila,
    this.detailedAddress,
    this.onboardingStatus = 'PROFILE_PENDING',
    this.profileCompleted = false,
    this.level,
    this.term,
    this.phone,
    this.emailType = 'university',
    this.verificationStatus = 'verified',
    this.isWillingToDonateBlood = false,
    this.isEligibleForBloodDonation,
    this.bloodDonationIneligibilityReason,
    this.bloodGroup,
    this.bloodGroupSource,
    this.bloodGroupVerified = false,
    this.bmdcRegistrationNumber,
  });

  bool get isSuperAdmin =>
      role == 'superadmin' ||
      role == 'admin' ||
      accessLevel == 'SuperAdmin' ||
      AuthConfig.isSuperAdminEmail(email);

  bool get isResidential => residencyStatus != 'non_residential';

  String get effectiveResidentialHall {
    if (!isResidential) {
      return 'Non-Residential (Day Scholar)';
    }
    return (residentialHall != null &&
            residentialHall!.trim().isNotEmpty &&
            residentialHall != 'Non-Residential (Day Scholar)' &&
            residentialHall != 'Non-resident (Day Scholar)')
        ? residentialHall!
        : 'Shaheed Dr. Zikrul Haque Hall (SDZHH)';
  }

  String get effectiveRoomNumber {
    if (!isResidential) {
      return 'N/A';
    }
    return (roomNumber != null && roomNumber!.trim().isNotEmpty && roomNumber != 'N/A')
        ? roomNumber!
        : '402-B';
  }

  String get effectiveLocationSummary {
    if (isResidential) {
      return '$effectiveResidentialHall, Room: $effectiveRoomNumber';
    } else {
      final parts = [
        if (detailedAddress != null && detailedAddress!.trim().isNotEmpty) detailedAddress!.trim(),
        if (upazila != null && upazila!.trim().isNotEmpty) upazila!.trim(),
        if (district != null && district!.trim().isNotEmpty) district!.trim(),
      ];
      return parts.isNotEmpty ? parts.join(', ') : 'Non-Residential (Day Scholar)';
    }
  }

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    final roll = (data['studentRoll'] ?? data['studentId'])?.toString();
    final bool completed = data['profileCompleted'] as bool? ??
        (roll != null && roll.isNotEmpty && data['onboardingStatus'] != 'PROFILE_PENDING');
    String status = (data['onboardingStatus'] as String? ?? '').toUpperCase();
    if (status.isEmpty) {
      status = completed ? 'DOCS_PENDING' : 'PROFILE_PENDING';
    }

    final email = data['email'] ?? '';
    final emailType = data['emailType'] as String? ?? AuthConfig.computeEmailType(email);
    final verificationStatus = data['verificationStatus'] as String? ?? AuthConfig.computeVerificationStatus(email);

    final rawResidency = data['residencyStatus']?.toString().toLowerCase();
    final isNonResHall = data['residentialHall'] == 'Non-resident (Day Scholar)' ||
        data['residentialHall'] == 'Non-Residential (Day Scholar)';
    final residency = rawResidency ?? (isNonResHall ? 'non_residential' : 'residential');

    return UserProfile(
      uid: uid,
      email: email,
      displayName: data['displayName'] ?? 'BAUST Member',
      role: (data['role'] as String? ?? 'student').toLowerCase(),
      designation: data['designation'],
      accessLevel: data['accessLevel'],
      department: data['department'],
      studentRoll: roll,
      residencyStatus: residency,
      residentialHall: data['residentialHall'],
      roomNumber: (data['roomNumber'] ?? data['room'])?.toString(),
      district: data['district']?.toString(),
      upazila: data['upazila']?.toString(),
      detailedAddress: (data['detailedAddress'] ?? data['address'])?.toString(),
      onboardingStatus: status,
      profileCompleted: completed,
      level: data['level']?.toString(),
      term: data['term']?.toString(),
      phone: data['phone']?.toString(),
      emailType: emailType,
      verificationStatus: verificationStatus,
      isWillingToDonateBlood: data['isWillingToDonateBlood'] as bool? ?? false,
      isEligibleForBloodDonation: data['isEligibleForBloodDonation'] as bool?,
      bloodDonationIneligibilityReason: data['bloodDonationIneligibilityReason'] as String?,
      bloodGroup: data['bloodGroup'] as String?,
      bloodGroupSource: data['bloodGroupSource'] as String?,
      bloodGroupVerified: data['bloodGroupVerified'] as bool? ?? false,
      bmdcRegistrationNumber: (data['bmdcRegistrationNumber'] ??
              data['bmdcRegNumber'] ??
              data['registrationNumber'])
          ?.toString(),
    );
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    String? designation,
    String? accessLevel,
    String? department,
    String? studentRoll,
    String? residencyStatus,
    String? residentialHall,
    String? roomNumber,
    String? district,
    String? upazila,
    String? detailedAddress,
    String? onboardingStatus,
    bool? profileCompleted,
    String? level,
    String? term,
    String? phone,
    String? emailType,
    String? verificationStatus,
    bool? isWillingToDonateBlood,
    bool? isEligibleForBloodDonation,
    String? bloodDonationIneligibilityReason,
    String? bloodGroup,
    String? bloodGroupSource,
    bool? bloodGroupVerified,
    String? bmdcRegistrationNumber,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      accessLevel: accessLevel ?? this.accessLevel,
      department: department ?? this.department,
      studentRoll: studentRoll ?? this.studentRoll,
      residencyStatus: residencyStatus ?? this.residencyStatus,
      residentialHall: residentialHall ?? this.residentialHall,
      roomNumber: roomNumber ?? this.roomNumber,
      district: district ?? this.district,
      upazila: upazila ?? this.upazila,
      detailedAddress: detailedAddress ?? this.detailedAddress,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      level: level ?? this.level,
      term: term ?? this.term,
      phone: phone ?? this.phone,
      emailType: emailType ?? this.emailType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isWillingToDonateBlood: isWillingToDonateBlood ?? this.isWillingToDonateBlood,
      isEligibleForBloodDonation:
          isEligibleForBloodDonation ?? this.isEligibleForBloodDonation,
      bloodDonationIneligibilityReason:
          bloodDonationIneligibilityReason ?? this.bloodDonationIneligibilityReason,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      bloodGroupSource: bloodGroupSource ?? this.bloodGroupSource,
      bloodGroupVerified: bloodGroupVerified ?? this.bloodGroupVerified,
      bmdcRegistrationNumber:
          bmdcRegistrationNumber ?? this.bmdcRegistrationNumber,
    );
  }
}

// Authentication State
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserProfile? userProfile;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.userProfile,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? userProfile,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      userProfile: userProfile ?? this.userProfile,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Riverpod Notifier for Dynamic Auth and RBAC
class AuthNotifier extends Notifier<AuthState> {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  StreamSubscription<User?>? _authSubscription;

  FirebaseAuth get auth => _auth ??= FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;

  String? _inFlightProfileUid;

  @override
  AuthState build() {
    try {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      _authSubscription?.cancel();
      _authSubscription = _auth!.authStateChanges().listen((firebaseUser) {
        if (firebaseUser == null) {
          // If we intentionally transitioned to an error state (e.g. personal email rejected), preserve the error
          if (state.status == AuthStatus.error) {
            return;
          }
          state = const AuthState(status: AuthStatus.unauthenticated);
        } else {
          // Optimization: Skip redundant background profile loading if already authenticated
          if (state.status == AuthStatus.authenticated &&
              state.userProfile?.uid == firebaseUser.uid) {
            debugPrint('[Auth] ℹ️ authStateChanges: User ${firebaseUser.uid} already authenticated, skipping redundant load.');
            return;
          }
          // Optimization: If a sign-in operation is actively in-flight, let that method complete
          if (state.status == AuthStatus.loading) {
            debugPrint('[Auth] ℹ️ authStateChanges: Auth operation actively in-flight, delegating profile load to caller.');
            return;
          }
          _loadUserProfile(firebaseUser);
        }
      });
    } catch (e) {
      debugPrint('Firebase Auth not yet initialized: $e');
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> _loadUserProfile(User firebaseUser) async {
    // Deduplicate concurrent profile loads for the same UID
    if (_inFlightProfileUid == firebaseUser.uid && state.status == AuthStatus.authenticated) {
      debugPrint('[Auth] ⚡ Skipping redundant _loadUserProfile for UID: ${firebaseUser.uid}');
      return;
    }
    _inFlightProfileUid = firebaseUser.uid;

    final profileSw = Stopwatch()..start();
    debugPrint('[Auth] 📄 Fetching Firestore user profile document for UID: ${firebaseUser.uid}...');

    try {
      final doc = await firestore
          .collection(FirestoreCollections.users)
          .doc(firebaseUser.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[Auth] ⚠️ Firestore user document fetch timed out (10s limit). Falling back to local profile.');
              throw TimeoutException('Firestore user fetch timed out after 10s');
            },
          );

      debugPrint('[Auth] ✅ Firestore user document fetched in ${profileSw.elapsedMilliseconds}ms (exists: ${doc.exists})');

      if (doc.exists && doc.data() != null) {
        var profile = UserProfile.fromFirestore(firebaseUser.uid, doc.data()!);
        final isSuperAdmin = AuthConfig.isSuperAdminEmail(firebaseUser.email ?? '');
        if (isSuperAdmin) {
          profile = profile.copyWith(
            role: 'superadmin',
            accessLevel: 'SuperAdmin',
            designation: profile.designation ?? 'Super Administrator',
            verificationStatus: 'verified',
            emailType: 'superadmin',
            profileCompleted: true,
            onboardingStatus: 'COMPLETED',
          );
        }
        state = AuthState(status: AuthStatus.authenticated, userProfile: profile);

        if (profile.role == 'student' && profile.verificationStatus == 'verified') {
          final resolvedName = profile.displayName.trim().isNotEmpty
              ? profile.displayName.trim()
              : (firebaseUser.displayName?.trim() ?? '');
          if (resolvedName.isNotEmpty) {
            try {
              final studentRef = firestore.collection(FirestoreCollections.students).doc(firebaseUser.uid);
              final studentSnap = await studentRef.get();
              if (studentSnap.exists) {
                final studentData = studentSnap.data();
                if (studentData != null &&
                    (studentData['displayName'] == null ||
                        studentData['displayName'].toString().trim().isEmpty)) {
                  // Merge without touching bloodGroupVerified
                  await studentRef.set({
                    'displayName': resolvedName,
                  }, SetOptions(merge: true));
                  debugPrint('[Auth] ✅ Backfilled displayName into students/${firebaseUser.uid}');
                }
              }
            } catch (e) {
              debugPrint('[Auth] Notice checking/backfilling student displayName: $e');
            }
          }
        }
      } else {
        final email = firebaseUser.email ?? '';
        final isSuperAdmin = AuthConfig.isSuperAdminEmail(email);

        if (isSuperAdmin) {
          try {
            await firestore.collection(FirestoreCollections.users).doc(firebaseUser.uid).set({
              'uid': firebaseUser.uid,
              'email': email,
              'displayName': firebaseUser.displayName ?? 'MD. Sajol Hasan',
              'role': 'superadmin',
              'emailType': 'superadmin',
              'isSuperAdmin': true,
              'accessLevel': 'SuperAdmin',
              'designation': 'Super Administrator',
              'verificationStatus': 'verified',
              'approved': true,
              'bloodGroupVerified': false,
              'profileCompleted': true,
              'onboardingStatus': 'COMPLETED',
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('[Auth] Notice setting initial superadmin user doc: $e');
          }

          final superAdminProfile = UserProfile(
            uid: firebaseUser.uid,
            email: email,
            displayName: firebaseUser.displayName ?? 'MD. Sajol Hasan',
            role: 'superadmin',
            emailType: 'superadmin',
            verificationStatus: 'verified',
            profileCompleted: true,
            onboardingStatus: 'COMPLETED',
            designation: 'Super Administrator',
            accessLevel: 'SuperAdmin',
          );
          state = AuthState(status: AuthStatus.authenticated, userProfile: superAdminProfile);
          return;
        }

        final emailType = AuthConfig.computeEmailType(email);
        final verificationStatus = AuthConfig.computeVerificationStatus(email);

        if (firebaseUser.emailVerified) {
          try {
            await firestore.collection(FirestoreCollections.users).doc(firebaseUser.uid).set({
              'uid': firebaseUser.uid,
              'email': email,
              'displayName': firebaseUser.displayName ?? 'Student',
              'role': 'student',
              'emailType': emailType,
              'verificationStatus': verificationStatus,
              'approved': false,
              'bloodGroupVerified': false,
              'profileCompleted': false,
              'onboardingStatus': 'PROFILE_PENDING',
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('[Auth] Notice setting initial user doc: $e');
          }
        }

        final fallbackProfile = UserProfile(
          uid: firebaseUser.uid,
          email: email,
          displayName: firebaseUser.displayName ?? 'BAUST Member',
          role: 'student',
          emailType: emailType,
          verificationStatus: verificationStatus,
          onboardingStatus: 'PROFILE_PENDING',
        );
        state = AuthState(status: AuthStatus.authenticated, userProfile: fallbackProfile);
      }
    } catch (e) {
      debugPrint('[Auth] ⚠️ Notice while loading user profile (${profileSw.elapsedMilliseconds}ms): $e. Applying fallback profile.');
      final email = firebaseUser.email ?? '';
      final isSuperAdmin = AuthConfig.isSuperAdminEmail(email);
      final defaultRole = isSuperAdmin ? 'superadmin' : _resolveRoleFromEmail(email);

      final fallbackProfile = UserProfile(
        uid: firebaseUser.uid,
        email: email,
        displayName: firebaseUser.displayName ?? (isSuperAdmin ? 'MD. Sajol Hasan' : 'BAUST Member'),
        role: defaultRole,
        emailType: isSuperAdmin ? 'superadmin' : AuthConfig.computeEmailType(email),
        verificationStatus: isSuperAdmin ? 'verified' : AuthConfig.computeVerificationStatus(email),
        onboardingStatus: isSuperAdmin ? 'COMPLETED' : (defaultRole == 'student' ? 'PROFILE_PENDING' : 'COMPLETED'),
        profileCompleted: isSuperAdmin,
        designation: isSuperAdmin ? 'Super Administrator' : null,
        accessLevel: isSuperAdmin ? 'SuperAdmin' : null,
      );
      state = AuthState(status: AuthStatus.authenticated, userProfile: fallbackProfile);
    } finally {
      if (_inFlightProfileUid == firebaseUser.uid) {
        _inFlightProfileUid = null;
      }
    }
  }

  String _resolveRoleFromEmail(String email) {
    if (AuthConfig.isSuperAdminEmail(email) || email.toLowerCase() == 'vc@baust.edu.bd') {
      return 'superadmin';
    }
    // Safety constraint: Every new account starts as role "student".
    // Non-student roles (doctor, admin, staff) must be set server-side or via Firebase Console.
    return 'student';
  }

  // Student Login (accepts Student Roll or Email)
  Future<void> signInStudent({
    required String studentIdentifier,
    required String password,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint('[Auth] ⏱ [signInStudent] Starting login for: $studentIdentifier');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final cleanIdentifier = studentIdentifier.trim();
      final email = cleanIdentifier.contains('@')
          ? cleanIdentifier
          : '$cleanIdentifier@baust.edu.bd';

      final authSw = Stopwatch()..start();
      debugPrint('[Auth] 🔑 [signInStudent] Calling signInWithEmailAndPassword for: $email...');
      final userCredential = await auth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[Auth] ⚠️ [signInStudent] signInWithEmailAndPassword timed out after 10s');
              throw TimeoutException('Authentication timed out after 10 seconds. Check network connection.');
            },
          );
      debugPrint('[Auth] ✅ [signInStudent] signInWithEmailAndPassword completed in ${authSw.elapsedMilliseconds}ms');
      final user = userCredential.user;
      if (user != null) {
        final userEmail = user.email ?? email;
        final isSuperAdmin = AuthConfig.isSuperAdminEmail(userEmail);

        // If personal email and not allowed by registration policy
        if (!isSuperAdmin && !AuthConfig.isEmailAllowed(userEmail)) {
          // Check if an existing profile is already in Firestore (e.g. pending applicant or approved)
          final userDocRef = firestore.collection(FirestoreCollections.users).doc(user.uid);
          DocumentSnapshot<Map<String, dynamic>>? existingDoc;
          try {
            existingDoc = await userDocRef.get().timeout(const Duration(seconds: 5));
          } catch (_) {}

          if (existingDoc != null && existingDoc.exists) {
            // Existing profile doc found in Firestore: load profile and route
            await _loadUserProfile(user);
            return;
          }

          // Personal email not permitted and no existing doc: clean signout and error message
          try {
            await auth.signOut();
          } catch (_) {}
          state = const AuthState(
            status: AuthStatus.error,
            errorMessage: 'Please sign in with your university email.',
          );
          return;
        }

        await _loadUserProfile(user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      debugPrint('[Auth] 🎉 [signInStudent] Total student login completed in ${sw.elapsedMilliseconds}ms');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] ❌ [signInStudent] FirebaseAuthException in ${sw.elapsedMilliseconds}ms: ${e.code} - ${e.message}');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _formatAuthError(e),
      );
    } catch (e) {
      debugPrint('[Auth] ❌ [signInStudent] Error in ${sw.elapsedMilliseconds}ms: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Login failed: $e',
      );
    }
  }

  // Google Sign-In for Students (Web via signInWithPopup, Android/Mobile via google_sign_in)
  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled
          state = state.copyWith(status: AuthStatus.unauthenticated);
          return;
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await auth.signInWithCredential(credential);
      }

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        final email = firebaseUser.email ?? '';
        final isSuperAdmin = AuthConfig.isSuperAdminEmail(email);

        final userDocRef = firestore.collection(FirestoreCollections.users).doc(firebaseUser.uid);
        final userDoc = await userDocRef.get().timeout(const Duration(seconds: 10));

        if (!userDoc.exists) {
          if (isSuperAdmin) {
            await userDocRef.set({
              'uid': firebaseUser.uid,
              'email': email,
              'displayName': firebaseUser.displayName ?? 'MD. Sajol Hasan',
              'role': 'superadmin',
              'emailType': 'superadmin',
              'isSuperAdmin': true,
              'accessLevel': 'SuperAdmin',
              'designation': 'Super Administrator',
              'verificationStatus': 'verified',
              'approved': true,
              'bloodGroupVerified': false,
              'profileCompleted': true,
              'onboardingStatus': 'COMPLETED',
              'createdAt': FieldValue.serverTimestamp(),
            }).timeout(const Duration(seconds: 10));
          } else {
            // New Google account creation: MUST start with role "student"
            final emailType = AuthConfig.computeEmailType(email);
            final verificationStatus = AuthConfig.computeVerificationStatus(email);

            await userDocRef.set({
              'uid': firebaseUser.uid,
              'email': email,
              'displayName': firebaseUser.displayName ?? 'Student',
              'role': 'student', // ALWAYS student
              'emailType': emailType,
              'verificationStatus': verificationStatus,
              'approved': false,
              'bloodGroupVerified': false,
              'profileCompleted': false,
              'onboardingStatus': 'PROFILE_PENDING',
              'createdAt': FieldValue.serverTimestamp(),
            }).timeout(const Duration(seconds: 10));
          }
        } else if (isSuperAdmin) {
          // If userDoc exists, make sure the doc has role: 'superadmin' and isSuperAdmin: true
          final data = userDoc.data() ?? {};
          if (data['role'] != 'superadmin' || data['isSuperAdmin'] != true) {
            await userDocRef.set({
              'role': 'superadmin',
              'emailType': 'superadmin',
              'isSuperAdmin': true,
              'accessLevel': 'SuperAdmin',
              'designation': data['designation'] ?? 'Super Administrator',
              'verificationStatus': 'verified',
              'approved': true,
              'profileCompleted': true,
              'onboardingStatus': 'COMPLETED',
            }, SetOptions(merge: true)).catchError((e) {
              debugPrint('[Auth] Notice updating superadmin flags: $e');
            });
          }
        }

        await _loadUserProfile(firebaseUser);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'popup-closed-by-user') {
        message = 'Google Sign-In was cancelled or popup was closed.';
      } else if (e.code == 'account-exists-with-different-credential') {
        message = 'An account already exists with this email using a different sign-in method.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error during Google Sign-In. Check your internet connection.';
      } else {
        message = _formatAuthError(e);
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Google Sign-In failed: $e',
      );
    }
  }

  // Staff/Admin Login (Official Institutional Email)
  Future<void> signInStaffOrAdmin({
    required String email,
    required String password,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint('[Auth] ⏱ [signInStaffOrAdmin] Starting login for: $email');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final cleanEmail = email.trim();
      final authSw = Stopwatch()..start();
      debugPrint('[Auth] 🔑 [signInStaffOrAdmin] Calling signInWithEmailAndPassword for: $cleanEmail...');
      final userCredential = await auth
          .signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[Auth] ⚠️ [signInStaffOrAdmin] signInWithEmailAndPassword timed out after 10s');
              throw TimeoutException('Authentication timed out after 10 seconds. Check network connection.');
            },
          );
      debugPrint('[Auth] ✅ [signInStaffOrAdmin] signInWithEmailAndPassword completed in ${authSw.elapsedMilliseconds}ms');

      if (userCredential.user != null) {
        await _loadUserProfile(userCredential.user!);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      debugPrint('[Auth] 🎉 [signInStaffOrAdmin] Total staff login completed in ${sw.elapsedMilliseconds}ms');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] ❌ [signInStaffOrAdmin] FirebaseAuthException in ${sw.elapsedMilliseconds}ms: ${e.code} - ${e.message}');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _formatAuthError(e),
      );
    } catch (e) {
      debugPrint('[Auth] ❌ [signInStaffOrAdmin] Error in ${sw.elapsedMilliseconds}ms: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Staff authentication failed: $e',
      );
    }
  }

  // Student Self-Registration (Sign Up)
  Future<void> signUpStudent({
    required String fullName,
    required String email,
    required String password,
    String? studentRoll,
    String? department,
    String? residentialHall,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final cleanEmail = email.trim();
      if (!AuthConfig.isEmailAllowed(cleanEmail)) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Please sign in with your university email.',
        );
        return;
      }

      final userCredential = await auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(fullName);

        // Send email verification link
        try {
          await firebaseUser.sendEmailVerification();
        } catch (e) {
          debugPrint('Verification email send notice: $e');
        }

        final emailType = AuthConfig.computeEmailType(cleanEmail);
        final verificationStatus = AuthConfig.computeVerificationStatus(cleanEmail);

        // New student account: MUST start with role "student", bloodGroupVerified: false
        try {
          await firestore.collection(FirestoreCollections.users).doc(firebaseUser.uid).set({
            'uid': firebaseUser.uid,
            'email': cleanEmail,
            'displayName': fullName,
            'role': 'student', // ALWAYS student
            'emailType': emailType,
            'verificationStatus': verificationStatus,
            'bloodGroupVerified': false,
            'profileCompleted': false,
            'onboardingStatus': 'PROFILE_PENDING',
            'department': ?department,
            'studentRoll': ?studentRoll,
            'residentialHall': ?residentialHall,
            'createdAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('[Auth] Deferred document creation until email verification: $e');
        }

        final newProfile = UserProfile(
          uid: firebaseUser.uid,
          email: cleanEmail,
          displayName: fullName,
          role: 'student',
          emailType: emailType,
          verificationStatus: verificationStatus,
          profileCompleted: false,
          onboardingStatus: 'PROFILE_PENDING',
          department: department,
          studentRoll: studentRoll,
          residentialHall: residentialHall,
        );

        state = AuthState(status: AuthStatus.authenticated, userProfile: newProfile);
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _formatAuthError(e),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Registration failed: $e',
      );
    }
  }

  // Student Profile Onboarding (Task 3): Transactional Student ID Claim & Profile Completion
  Future<void> saveStudentProfileSetup({
    required String studentId,
    required String department,
    required String level,
    required String term,
    String residencyStatus = 'residential',
    String? residentialHall,
    String? roomNumber,
    String? district,
    String? upazila,
    String? detailedAddress,
    String? phone,
    bool isWillingToDonateBlood = false,
    bool sharePhoneInDonorDirectory = false,
  }) async {
    final currentProfile = state.userProfile;
    if (currentProfile == null) return;

    final cleanStudentId = studentId.trim();
    final cleanPhone = phone?.trim();
    final isRes = residencyStatus != 'non_residential';
    final cleanHall = isRes
        ? (residentialHall != null && residentialHall.trim().isNotEmpty
            ? residentialHall.trim()
            : 'Shaheed Dr. Zikrul Haque Hall (SDZHH)')
        : 'Non-Residential (Day Scholar)';
    final cleanRoom = isRes
        ? (roomNumber != null && roomNumber.trim().isNotEmpty ? roomNumber.trim() : '402-B')
        : 'N/A';
    final cleanDistrict = district?.trim();
    final cleanUpazila = upazila?.trim();
    final cleanDetailedAddress = detailedAddress?.trim();

    // Enforce student ID format
    if (!AuthConfig.isValidStudentId(cleanStudentId)) {
      throw Exception('Invalid Student ID format. Please check your ID.');
    }

    if (!AuthConfig.isValidPhone(cleanPhone)) {
      throw Exception('Invalid phone number format.');
    }

    // 1. Transactionally claim student_ids/{studentId} and update users/{uid}
    await firestore.runTransaction((transaction) async {
      final studentIdRef = firestore.collection('student_ids').doc(cleanStudentId);
      final studentIdDoc = await transaction.get(studentIdRef);

      if (studentIdDoc.exists) {
        final existingUid = studentIdDoc.data()?['uid'] ?? studentIdDoc.data()?['value'];
        if (existingUid != currentProfile.uid) {
          throw StudentIdAlreadyRegisteredException(
            'This student ID is already registered. Contact the medical center.',
          );
        }
      } else {
        transaction.set(studentIdRef, {
          'uid': currentProfile.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final resolvedDisplayName = currentProfile.displayName.trim().isNotEmpty
          ? currentProfile.displayName.trim()
          : (auth.currentUser?.displayName?.trim() ?? 'Student');

      final Map<String, dynamic> profileData = {
        'displayName': resolvedDisplayName,
        'studentRoll': cleanStudentId,
        'studentId': cleanStudentId,
        'department': department,
        'level': level,
        'term': term,
        'residencyStatus': isRes ? 'residential' : 'non_residential',
        'residentialHall': cleanHall,
        'roomNumber': cleanRoom,
        'district': cleanDistrict,
        'upazila': cleanUpazila,
        'detailedAddress': cleanDetailedAddress,
        if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
        'isWillingToDonateBlood': isWillingToDonateBlood,
        'profileCompleted': true,
        'onboardingStatus': 'DOCS_PENDING',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final userRef = firestore.collection(FirestoreCollections.users).doc(currentProfile.uid);
      transaction.set(userRef, profileData, SetOptions(merge: true));

      final studentRef = firestore.collection(FirestoreCollections.students).doc(currentProfile.uid);
      transaction.set(studentRef, profileData, SetOptions(merge: true));

      // H2: Manage minimal blood_donors/{uid} collection
      final donorRef = firestore.collection('blood_donors').doc(currentProfile.uid);
      if (isWillingToDonateBlood) {
        transaction.set(donorRef, {
          'uid': currentProfile.uid,
          'displayName': currentProfile.displayName,
          'bloodGroup': currentProfile.bloodGroup ?? 'Pending Verification',
          'bloodGroupVerified': false,
          'department': department,
          'hall': cleanHall,
          'isAvailable': true,
          'updatedAt': FieldValue.serverTimestamp(),
          if (sharePhoneInDonorDirectory && cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
        }, SetOptions(merge: true));
      } else {
        transaction.delete(donorRef);
      }
    });

    final updatedProfile = currentProfile.copyWith(
      studentRoll: cleanStudentId,
      department: department,
      level: level,
      term: term,
      residencyStatus: isRes ? 'residential' : 'non_residential',
      residentialHall: cleanHall,
      roomNumber: cleanRoom,
      district: cleanDistrict,
      upazila: cleanUpazila,
      detailedAddress: cleanDetailedAddress,
      phone: cleanPhone,
      isWillingToDonateBlood: isWillingToDonateBlood,
      profileCompleted: true,
      onboardingStatus: 'DOCS_PENDING',
    );
    state = state.copyWith(userProfile: updatedProfile);
  }

  // Update persistent profile details (Task 2): Hall, Room, Phone, etc.
  Future<void> updateUserProfileDetails({
    String? residencyStatus,
    String? residentialHall,
    String? roomNumber,
    String? district,
    String? upazila,
    String? detailedAddress,
    String? phone,
    String? department,
    String? level,
    String? term,
    bool? isWillingToDonateBlood,
  }) async {
    final currentProfile = state.userProfile;
    if (currentProfile == null) return;

    final targetResidency = residencyStatus ?? currentProfile.residencyStatus;
    final isRes = targetResidency != 'non_residential';

    final cleanHall = isRes
        ? (residentialHall != null && residentialHall.trim().isNotEmpty
            ? residentialHall.trim()
            : currentProfile.effectiveResidentialHall)
        : 'Non-Residential (Day Scholar)';
    final cleanRoom = isRes
        ? (roomNumber != null && roomNumber.trim().isNotEmpty
            ? roomNumber.trim()
            : currentProfile.effectiveRoomNumber)
        : 'N/A';
    final cleanPhone = phone?.trim();
    final cleanDistrict = district?.trim();
    final cleanUpazila = upazila?.trim();
    final cleanDetailedAddress = detailedAddress?.trim();

    final Map<String, dynamic> updateData = {
      'residencyStatus': isRes ? 'residential' : 'non_residential',
      'residentialHall': cleanHall,
      'roomNumber': cleanRoom,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (cleanDistrict != null) updateData['district'] = cleanDistrict;
    if (cleanUpazila != null) updateData['upazila'] = cleanUpazila;
    if (cleanDetailedAddress != null) updateData['detailedAddress'] = cleanDetailedAddress;
    if (cleanPhone != null) updateData['phone'] = cleanPhone;
    if (department != null && department.isNotEmpty) updateData['department'] = department;
    if (level != null && level.isNotEmpty) updateData['level'] = level;
    if (term != null && term.isNotEmpty) updateData['term'] = term;
    if (isWillingToDonateBlood != null) updateData['isWillingToDonateBlood'] = isWillingToDonateBlood;
    if (currentProfile.displayName.trim().isNotEmpty) {
      updateData['displayName'] = currentProfile.displayName.trim();
    }

    try {
      await firestore
          .collection(FirestoreCollections.users)
          .doc(currentProfile.uid)
          .set(updateData, SetOptions(merge: true));

      await firestore
          .collection(FirestoreCollections.students)
          .doc(currentProfile.uid)
          .set(updateData, SetOptions(merge: true));

      final willDonate = isWillingToDonateBlood ?? currentProfile.isWillingToDonateBlood;
      final donorRef = firestore.collection('blood_donors').doc(currentProfile.uid);
      if (willDonate) {
        await donorRef.set({
          'uid': currentProfile.uid,
          'displayName': currentProfile.displayName,
          'bloodGroup': currentProfile.bloodGroup ?? 'Pending Verification',
          'bloodGroupVerified': false,
          'department': department ?? currentProfile.department ?? 'General',
          'hall': cleanHall,
          'isAvailable': true,
          'updatedAt': FieldValue.serverTimestamp(),
          if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
        }, SetOptions(merge: true));
      }

      final updated = currentProfile.copyWith(
        residencyStatus: isRes ? 'residential' : 'non_residential',
        residentialHall: cleanHall,
        roomNumber: cleanRoom,
        district: cleanDistrict ?? currentProfile.district,
        upazila: cleanUpazila ?? currentProfile.upazila,
        detailedAddress: cleanDetailedAddress ?? currentProfile.detailedAddress,
        phone: cleanPhone ?? currentProfile.phone,
        department: department ?? currentProfile.department,
        level: level ?? currentProfile.level,
        term: term ?? currentProfile.term,
        isWillingToDonateBlood: willDonate,
      );
      state = state.copyWith(userProfile: updated);
    } catch (e) {
      debugPrint('[Auth] Error updating profile details: $e');
      rethrow;
    }
  }

  // Reload current user state (for email verification check)
  Future<void> reloadUser() async {
    final user = auth.currentUser;
    if (user != null) {
      await user.reload();
      final refreshed = auth.currentUser;
      if (refreshed != null) {
        if (refreshed.emailVerified) {
          // Force refresh ID token so request.auth.token.email_verified updates in Firestore Security Rules
          try {
            await refreshed.getIdToken(true);
          } catch (e) {
            debugPrint('[Auth] ID token refresh error: $e');
          }
        }
        await _loadUserProfile(refreshed);
      }
    }
  }

  // Resend email verification link
  Future<void> resendVerificationEmail() async {
    final user = auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Send Password Reset Link to BAUST Institutional Email
  Future<bool> sendPasswordReset(String email) async {
    try {
      final cleanEmail = email.trim().contains('@')
          ? email.trim()
          : '${email.trim()}@baust.edu.bd';
      await auth.sendPasswordResetEmail(email: cleanEmail);
      return true;
    } catch (e) {
      debugPrint('Password reset email failed: $e');
      return false;
    }
  }

  // Stage 2 Onboarding: Complete Medical History Upload
  Future<void> completeOnboarding({ExtractedMedicalData? medicalData}) async {
    final currentProfile = state.userProfile;
    if (currentProfile == null) return;

    final updatedProfile = currentProfile.copyWith(
      onboardingStatus: 'COMPLETED',
      bloodGroup: medicalData?.bloodGroup,
      bloodGroupSource: medicalData?.bloodGroupSource,
      bloodGroupVerified: false,
      isEligibleForBloodDonation: medicalData?.isEligibleForBloodDonation,
      bloodDonationIneligibilityReason:
          medicalData?.bloodDonationIneligibilityReason,
    );
    state = state.copyWith(userProfile: updatedProfile);

    try {
      await Future.wait([
        // 1. Update Firestore Users collection
        firestore
            .collection(FirestoreCollections.users)
            .doc(currentProfile.uid)
            .set({
          'onboardingStatus': 'COMPLETED',
          if (medicalData != null) ...{
            'bloodGroup': medicalData.bloodGroup,
            'bloodGroupSource': medicalData.bloodGroupSource,
            'isEligibleForBloodDonation': medicalData.isEligibleForBloodDonation,
            'bloodDonationIneligibilityReason':
                medicalData.bloodDonationIneligibilityReason,
          }
        }, SetOptions(merge: true)),

        // 2 & 3. Persist AI medical history & student critical flags in parallel
        if (medicalData != null) ...[
          firestore
              .collection('medical_histories')
              .doc(currentProfile.uid)
              .set({
            'studentId': currentProfile.uid,
            'historicalProblems': medicalData.historicalProblems,
            'activeIssues': medicalData.activeIssues,
            'knownAllergies': medicalData.knownAllergies,
            'bloodGroup': medicalData.bloodGroup,
            'bloodGroupSource': medicalData.bloodGroupSource,
            'bloodGroupVerified': false,
            'confidenceScore': medicalData.confidenceScore,
            'clinicalSummary': medicalData.clinicalSummary,
            'procedures': medicalData.procedures.map((e) => e.toMap()).toList(),
            'prescriptions': medicalData.currentMedications.map((e) => e.toMap()).toList(),
            'isEligibleForBloodDonation': medicalData.isEligibleForBloodDonation,
            'bloodDonationIneligibilityReason':
                medicalData.bloodDonationIneligibilityReason,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
          firestore
              .collection(FirestoreCollections.students)
              .doc(currentProfile.uid)
              .set({
            'onboardingStatus': 'COMPLETED',
            if (currentProfile.displayName.trim().isNotEmpty)
              'displayName': currentProfile.displayName.trim(),
            'bloodGroup': medicalData.bloodGroup,
            'bloodGroupSource': medicalData.bloodGroupSource,
            'bloodGroupVerified': false,
            'criticalFlags': medicalData.knownAllergies,
            'isEligibleForBloodDonation': medicalData.isEligibleForBloodDonation,
            'bloodDonationIneligibilityReason':
                medicalData.bloodDonationIneligibilityReason,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
          if (currentProfile.isWillingToDonateBlood)
            firestore
                .collection('blood_donors')
                .doc(currentProfile.uid)
                .set({
              'bloodGroup': medicalData.bloodGroup ?? 'Pending Verification',
              'bloodGroupVerified': false,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
        ],
      ]).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Firestore update notice during onboarding completion: $e');
    }
  }

  /// Helper to test and demonstrate any RBAC role
  void switchDemoRoleForTesting(String role) {
    String name = 'BAUST Member';
    String? designation;
    String? accessLevel;
    String? dept;
    String email = '$role@baust.edu.bd';
    String? phone;
    String status = 'COMPLETED';

    switch (role) {
      case 'doctor':
        name = 'Dr. Fowzia Jahan';
        designation = 'Senior Medical Officer';
        accessLevel = 'Doctor';
        dept = 'BAUST Medical Center';
        email = 'medicalcenter@baust.edu.bd';
        phone = '01769-675576';
        break;
      case 'pharmacist':
        name = 'Md. Mozaffor Hossain';
        designation = 'Medical Assistant / Pharmacist';
        accessLevel = 'Pharmacist';
        dept = 'BAUST Medical Center';
        email = '';
        phone = '01712-645975';
        break;
      case 'staff':
        name = 'Dr. Md Nakib Hayat Chowdhury';
        designation = 'Head of Department (CSE) / Associate Professor';
        accessLevel = 'Head of Department (Head)';
        dept = 'Computer Science & Engineering (CSE)';
        email = '';
        phone = '01769675560';
        break;
      case 'nurse':
        name = 'Lamia Aktar Limu';
        designation = 'Staff Nurse';
        accessLevel = 'Pharmacist';
        dept = 'BAUST Medical Center';
        email = 'limuakhtar9@gmail.com';
        phone = '01749-898473';
        break;
      case 'superadmin':
        name = 'MD. Sajol Hasan';
        designation = 'Super Administrator';
        accessLevel = 'SuperAdmin';
        dept = 'Central Administration';
        email = AuthConfig.superAdminEmail;
        status = 'COMPLETED';
        break;
      case 'student':
      default:
        name = 'MD. Sajol Hassan';
        dept = 'Computer Science & Engineering (CSE)';
        email = '0802420205101137@baust.edu.bd';
        status = 'COMPLETED';
        break;
    }

    final profile = UserProfile(
      uid: 'demo_${role}_uid',
      email: email,
      displayName: name,
      role: role,
      designation: designation,
      accessLevel: accessLevel,
      department: dept,
      phone: phone,
      studentRoll: role == 'student' ? '0802420205101137' : null,
      residentialHall: 'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
      roomNumber: '402-B',
      profileCompleted: true,
      onboardingStatus: status,
    );
    state = AuthState(status: AuthStatus.authenticated, userProfile: profile);
  }

  // Sign Out
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await auth.signOut();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _formatAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No registered account found with these credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this institutional email.';
      case 'weak-password':
        return 'The password provided is too weak (minimum 6 characters required).';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid credentials. Please check your ID/Email and password.';
      case 'invalid-email':
        return 'Invalid email or institutional ID format.';
      case 'user-disabled':
        return 'This university account has been suspended.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again in a few moments.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}

// Global Provider
final authControllerProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
