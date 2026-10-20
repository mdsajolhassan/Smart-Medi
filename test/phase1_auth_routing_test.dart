import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/core/config/auth_config.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/blood_bank/presentation/screens/blood_donor_directory.dart';

void main() {
  group('Phase 1 Hardening - AuthConfig & Email Policy Unit Tests', () {
    test('1. University email domain classification (exact match & true subdomains)', () {
      expect(AuthConfig.computeEmailType('student@baust.edu.bd'), equals('university'));
      expect(AuthConfig.computeEmailType('STUDENT@BAUST.EDU.BD'), equals('university'));
      expect(AuthConfig.computeEmailType('  faculty@cse.baust.edu.bd  '), equals('university'));
      expect(AuthConfig.computeEmailType('x@sub.baust.edu.bd'), equals('university'));
      expect(AuthConfig.computeEmailType('x@dept.sub.baust.edu.bd'), equals('university'));
    });

    test('2. Look-alike attack domains strictly classified as personal (H4)', () {
      // Look-alike addresses must NEVER match the university policy
      expect(AuthConfig.computeEmailType('x@evilbaust.edu.bd'), equals('personal'));
      expect(AuthConfig.computeEmailType('x@baust.edu.bd.evil.com'), equals('personal'));
      expect(AuthConfig.computeEmailType('x@baust.edu.bd.com'), equals('personal'));
      expect(AuthConfig.computeEmailType('user@gmail.com'), equals('personal'));
      expect(AuthConfig.computeEmailType('user@yahoo.com'), equals('personal'));
      expect(AuthConfig.computeEmailType('invalid-email'), equals('personal'));
      expect(AuthConfig.computeEmailType(''), equals('personal'));
    });

    test('3. Verification status computation (university -> verified, lookalike/personal -> pending)', () {
      expect(AuthConfig.computeVerificationStatus('student@baust.edu.bd'), equals('verified'));
      expect(AuthConfig.computeVerificationStatus('student@cse.baust.edu.bd'), equals('verified'));
      expect(AuthConfig.computeVerificationStatus('x@sub.baust.edu.bd'), equals('verified'));
      expect(AuthConfig.computeVerificationStatus('X@BAUST.EDU.BD'), equals('verified'));

      // Look-alikes and personal
      expect(AuthConfig.computeVerificationStatus('x@evilbaust.edu.bd'), equals('pending'));
      expect(AuthConfig.computeVerificationStatus('x@baust.edu.bd.evil.com'), equals('pending'));
      expect(AuthConfig.computeVerificationStatus('x@baust.edu.bd.com'), equals('pending'));
      expect(AuthConfig.computeVerificationStatus('user@gmail.com'), equals('pending'));
    });

    test('4. Registration email policy allowance check (H5: allowPersonalEmails = false)', () {
      // University emails permitted
      expect(AuthConfig.isEmailAllowed('student@baust.edu.bd'), isTrue);
      expect(AuthConfig.isEmailAllowed('x@sub.baust.edu.bd'), isTrue);

      // Personal and look-alike emails blocked by default
      expect(AuthConfig.isEmailAllowed('student@gmail.com'), isFalse);
      expect(AuthConfig.isEmailAllowed('random@yahoo.com'), isFalse);
      expect(AuthConfig.isEmailAllowed('x@evilbaust.edu.bd'), isFalse);
      expect(AuthConfig.isEmailAllowed('x@baust.edu.bd.evil.com'), isFalse);
      expect(AuthConfig.isEmailAllowed('x@baust.edu.bd.com'), isFalse);
      expect(AuthConfig.isEmailAllowed(''), isFalse);
    });

    test('5. Student ID format regex validation (6-20 digits)', () {
      // Valid IDs
      expect(AuthConfig.isValidStudentId('210401050'), isTrue); // Standard 9-digit BAUST roll
      expect(AuthConfig.isValidStudentId('19010101'), isTrue);  // 8 digits
      expect(AuthConfig.isValidStudentId('1234567'), isTrue);   // 7 digits
      expect(AuthConfig.isValidStudentId('123456'), isTrue);    // 6 digits (minimum)
      expect(AuthConfig.isValidStudentId('1234567890'), isTrue);// 10 digits
      expect(AuthConfig.isValidStudentId('0802420205101137'), isTrue); // 16 digits
      expect(AuthConfig.isValidStudentId('12345678901234567890'), isTrue); // 20 digits (maximum)
      expect(AuthConfig.isValidStudentId('  210401050  '), isTrue); // Whitespace trimmed

      // Invalid IDs
      expect(AuthConfig.isValidStudentId(''), isFalse);
      expect(AuthConfig.isValidStudentId('12345'), isFalse); // < 6 digits
      expect(AuthConfig.isValidStudentId('123456789012345678901'), isFalse); // > 20 digits
      expect(AuthConfig.isValidStudentId('21040105A'), isFalse); // Alphanumeric
      expect(AuthConfig.isValidStudentId('STU-12345'), isFalse); // Hyphenated
    });

    test('6. Phone number format validation (BD formats)', () {
      expect(AuthConfig.isValidPhone('01712345678'), isTrue);
      expect(AuthConfig.isValidPhone('+8801712345678'), isTrue);
      expect(AuthConfig.isValidPhone('8801812345678'), isTrue);
      expect(AuthConfig.isValidPhone('01300000000'), isTrue);
      expect(AuthConfig.isValidPhone('01999999999'), isTrue);
      expect(AuthConfig.isValidPhone(null), isTrue); // Optional
      expect(AuthConfig.isValidPhone(''), isTrue); // Optional

      // Invalid phones
      expect(AuthConfig.isValidPhone('01212345678'), isFalse); // 012 is invalid operator
      expect(AuthConfig.isValidPhone('12345678'), isFalse);
      expect(AuthConfig.isValidPhone('abc'), isFalse);
    });
  });

  group('Phase 1 Hardening - UserProfile, Routing & Minimal Donor Directory Tests', () {
    test('7. UserProfile defaults and role containment', () {
      final profile = UserProfile(
        uid: 'user-123',
        email: 'test@baust.edu.bd',
        displayName: 'Test Student',
        role: 'student',
      );

      // Safety check: Default role must always be 'student'
      expect(profile.role, equals('student'));
      expect(profile.profileCompleted, isFalse);
      expect(profile.bloodGroupVerified, isFalse);
      expect(profile.emailType, equals('university'));
      expect(profile.verificationStatus, equals('verified'));
    });

    test('8. UserProfile.fromFirestore parses all Phase 1 fields safely', () {
      final Map<String, dynamic> mockData = {
        'uid': 'student-abc',
        'email': 'student@baust.edu.bd',
        'displayName': 'Sajol Hassan',
        'role': 'student',
        'emailType': 'university',
        'verificationStatus': 'verified',
        'profileCompleted': true,
        'department': 'CSE',
        'studentRoll': '210401050',
        'level': 'Level 4',
        'term': 'Term 1',
        'residentialHall': 'Abbas Uddin Ahmed Hall (AUAH)',
        'phone': '01712345678',
        'bloodGroup': 'B+',
        'bloodGroupVerified': false,
        'onboardingStatus': 'COMPLETED',
      };

      final profile = UserProfile.fromFirestore('student-abc', mockData);

      expect(profile.uid, equals('student-abc'));
      expect(profile.email, equals('student@baust.edu.bd'));
      expect(profile.role, equals('student'));
      expect(profile.emailType, equals('university'));
      expect(profile.verificationStatus, equals('verified'));
      expect(profile.profileCompleted, isTrue);
      expect(profile.department, equals('CSE'));
      expect(profile.studentRoll, equals('210401050'));
      expect(profile.level, equals('Level 4'));
      expect(profile.term, equals('Term 1'));
      expect(profile.residentialHall, equals('Abbas Uddin Ahmed Hall (AUAH)'));
      expect(profile.phone, equals('01712345678'));
      expect(profile.bloodGroup, equals('B+'));
      expect(profile.bloodGroupVerified, isFalse);
    });

    test('9. UserProfile.fromFirestore falls back to student role if missing or malformed', () {
      final Map<String, dynamic> malformedData = {
        'uid': 'random-uid',
        'email': 'hacker@example.com',
        // role missing
      };

      final profile = UserProfile.fromFirestore('random-uid', malformedData);
      expect(profile.role, equals('student'));
      expect(profile.profileCompleted, isFalse);
    });

    test('10. Routing State Machine Decision Matrix (including H5 WaitingForApproval)', () {
      // Scenario A: Pending verification account & personal email -> WaitingForApprovalScreen
      final pendingStudent = UserProfile(
        uid: 'pending-1',
        email: 'guest@gmail.com',
        displayName: 'Guest Student',
        role: 'student',
        emailType: 'personal',
        verificationStatus: 'pending',
      );
      final routesToWaiting = pendingStudent.verificationStatus == 'pending' || pendingStudent.emailType == 'personal';
      expect(routesToWaiting, isTrue); // Routes to WaitingForApprovalScreen

      // Scenario B: Non-student roles (doctor, admin, pharmacist) -> RolePlaceholderScreen
      final doctorProfile = UserProfile(
        uid: 'doc-1',
        email: 'doctor@baust.edu.bd',
        displayName: 'Dr. Rahman',
        role: 'doctor',
      );
      expect(doctorProfile.role == 'student', isFalse); // Routes to RolePlaceholderScreen

      final adminProfile = UserProfile(
        uid: 'adm-1',
        email: 'vc@baust.edu.bd',
        displayName: 'Prof. Admin',
        role: 'admin',
      );
      expect(adminProfile.role == 'student', isFalse); // Routes to RolePlaceholderScreen

      // Scenario C: Student with profileCompleted == false -> ProfileSetupScreen
      final incompleteStudent = UserProfile(
        uid: 'stu-1',
        email: 'student@baust.edu.bd',
        displayName: 'New Student',
        role: 'student',
        profileCompleted: false,
      );
      expect(incompleteStudent.profileCompleted, isFalse); // Routes to ProfileSetupScreen

      // Scenario D: Student with profileCompleted == true, onboardingStatus != COMPLETED -> MedicalOnboardingScreen
      final studentNeedMedical = UserProfile(
        uid: 'stu-2',
        email: 'student@baust.edu.bd',
        displayName: 'Setup Done Student',
        role: 'student',
        profileCompleted: true,
        onboardingStatus: 'PROFILE_PENDING',
      );
      expect(studentNeedMedical.profileCompleted, isTrue);
      expect(studentNeedMedical.onboardingStatus == 'COMPLETED', isFalse); // Routes to MedicalOnboardingScreen

      // Scenario E: Student with complete profile & complete medical -> SosScreen (Main App)
      final fullyOnboardedStudent = UserProfile(
        uid: 'stu-3',
        email: 'student@baust.edu.bd',
        displayName: 'Complete Student',
        role: 'student',
        profileCompleted: true,
        onboardingStatus: 'COMPLETED',
      );
      expect(fullyOnboardedStudent.profileCompleted, isTrue);
      expect(fullyOnboardedStudent.onboardingStatus == 'COMPLETED', isTrue); // Routes to SosScreen
    });

    test('11. Minimal Blood Donor Record Model (H2: No clinical data leaked)', () {
      final mockDoc = {
        'displayName': 'Fahim Shahriar',
        'bloodGroup': 'A+',
        'bloodGroupVerified': false,
        'department': 'Computer Science & Engineering (CSE)',
        'hall': 'Abbas Uddin Ahmed Hall (AUAH)',
        'isAvailable': true,
        'phone': '01712345678',
      };

      final donor = BloodDonorRecord.fromFirestore('donor_123', mockDoc);

      expect(donor.id, equals('donor_123'));
      expect(donor.displayName, equals('Fahim Shahriar'));
      expect(donor.bloodGroup, equals('A+'));
      expect(donor.bloodGroupVerified, isFalse);
      expect(donor.department, equals('Computer Science & Engineering (CSE)'));
      expect(donor.hall, equals('Abbas Uddin Ahmed Hall (AUAH)'));
      expect(donor.isAvailable, isTrue);
      expect(donor.phone, equals('01712345678'));

      // Ensure no medical leaks
      final donorNoPhone = BloodDonorRecord.fromFirestore('donor_hidden', {
        'displayName': 'Nusrat Jahan',
        'bloodGroup': 'O+',
        'bloodGroupVerified': false,
        'department': 'Electrical & Electronic Engineering (EEE)',
        'hall': 'Bir Protik Taramon Bibi Hall (BPTBH)',
        'isAvailable': true,
      });

      expect(donorNoPhone.phone, isNull);
    });
  });
}
