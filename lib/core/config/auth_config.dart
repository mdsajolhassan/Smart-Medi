/// Central University Authentication, Domain Policy, Student ID, and Campus Metadata Configuration.
/// All lists and regex patterns are consolidated here with TODO comments for confirmation with university authorities.
class AuthConfig {
  // ===========================================================================
  // 1. INSTITUTIONAL EMAIL DOMAINS
  // ===========================================================================
  /// Allowed institutional email domains for automatic verification.
  /// Accounts matching these domains receive emailType = "university" and verificationStatus = "verified".
  /// Note: The strict regex [universityEmailRegex] enforces exact '@baust.edu.bd' or true subdomains '.[subdomain].baust.edu.bd'.
  static const List<String> allowedUniversityEmailDomains = [
    'baust.edu.bd',
    // TODO: Confirm with BAUST ICT Cell if additional subdomain roots exist (e.g., 'cse.baust.edu.bd', 'eee.baust.edu.bd', 'medical.baust.edu.bd')
  ];

  /// Strict regex matching:
  /// - Exact match: @baust.edu.bd
  /// - True subdomain match: @sub.baust.edu.bd or @dept.sub.baust.edu.bd
  /// - Rejects look-alikes like @evilbaust.edu.bd, @baust.edu.bd.evil.com, @baust.edu.bd.com
  static final RegExp universityEmailRegex = RegExp(
    r'^[^@]+@(?:[a-zA-Z0-9-]+\.)*baust\.edu\.bd$',
    caseSensitive: false,
  );

  /// Whether personal emails (e.g., gmail.com, yahoo.com) are permitted for student registration.
  /// Hardened Phase 1 constraint: FALSE by default. Only institutional university emails may register.
  /// Personal accounts will see: "Please sign in with your university email."
  /// TODO: Confirm with University Admin if alumni or temporary guest personal emails should ever be admitted.
  static const bool allowPersonalEmails = false;

  // ===========================================================================
  // 2. STUDENT ID / ROLL FORMAT VALIDATION
  // ===========================================================================
  /// Format regex for student IDs (allows 6 to 20 digits to support various department roll formats).
  /// BAUST format convention ranges from short serials to 16+ digits (e.g. "0802420205101137").
  /// TODO: Confirm exact roll length and batch prefix standards with BAUST Registrar Office.
  static final RegExp studentIdRegex = RegExp(r'^\d{6,20}$');

  // ===========================================================================
  // 3. PHONE NUMBER FORMAT VALIDATION
  // ===========================================================================
  /// Bangladesh mobile phone number regex (e.g. 01712345678, +8801712345678, or 8801712345678).
  /// Valid telco operators in BD: 013, 014, 015, 016, 017, 018, 019.
  static final RegExp phoneRegex = RegExp(r'^(?:\+?88)?01[3-9]\d{8}$');

  // ===========================================================================
  // 4. ACADEMIC DEPARTMENTS
  // ===========================================================================
  /// University Academic Departments for Student Registration & Medical Categorization.
  /// TODO: Confirm complete list of active faculties/departments with BAUST Academic Council.
  static const List<String> academicDepartments = [
    'Computer Science & Engineering (CSE)',
    'Electrical & Electronic Engineering (EEE)',
    'Mechanical Engineering (ME)',
    'Civil Engineering (CE)',
    'Information & Communication Technology (ICT)',
    'Industrial & Production Engineering (IPE)',
    'Accounting & Information Systems (AIS)',
    'Business Administration (DBA)',
    'English',
    // TODO: Add any newly inaugurated departments (e.g., 'Mathematics', 'Physics', 'Chemistry')
  ];

  // ===========================================================================
  // 5. RESIDENTIAL HALLS
  // ===========================================================================
  /// BAUST Residential Halls (including day-scholars / non-residents).
  /// TODO: Confirm exact hall titles and campus annex names with BAUST Hall Provost Committee.
  static const List<String> residentialHalls = [
    'Abbas Uddin Ahmed Hall (AUAH)',
    'Bir Protik Taramon Bibi Hall (BPTBH)',
    'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
    'Bir Protik Taramon Bibi Hall (BPTBH) Annex',
    'Non-resident (Day Scholar)',
    // TODO: Confirm if off-campus mess / hostel options should be added
  ];

  // ===========================================================================
  // 6. ACADEMIC LEVELS & TERMS
  // ===========================================================================
  /// Academic Levels (Undergraduate Years 1 to 4).
  /// TODO: Confirm if Postgraduate / M.Sc. / Ph.D. levels are needed.
  static const List<String> academicLevels = [
    'Level 1',
    'Level 2',
    'Level 3',
    'Level 4',
  ];

  /// Academic Terms (Bi-semester system: Term 1 & Term 2).
  static const List<String> academicTerms = [
    'Term 1',
    'Term 2',
  ];

  // ===========================================================================
  // 7. SUPER ADMIN CONFIGURATION
  // ===========================================================================
  /// Fixed Super Administrator email with absolute system management privileges.
  static const String superAdminEmail = 'mdsajolhasan5@gmail.com';

  /// Returns true if the email belongs to the fixed Super Administrator.
  static bool isSuperAdminEmail(String email) {
    return email.trim().toLowerCase() == superAdminEmail.toLowerCase();
  }

  // ===========================================================================
  // 8. POLICY LOGIC HELPERS
  // ===========================================================================
  /// Computes the email category: "superadmin" if super admin, "university" if domain matches university domain pattern, else "personal".
  static String computeEmailType(String email) {
    final clean = email.trim();
    if (clean.isEmpty) return 'personal';
    if (isSuperAdminEmail(clean)) return 'superadmin';
    return universityEmailRegex.hasMatch(clean) ? 'university' : 'personal';
  }

  /// Computes initial verificationStatus based on email type.
  /// Super Admin or University emails -> "verified"; personal emails -> "pending".
  static String computeVerificationStatus(String email) {
    if (isSuperAdminEmail(email)) return 'verified';
    return computeEmailType(email) == 'university' ? 'verified' : 'pending';
  }

  /// Validates whether an email is allowed under the current policy for registration.
  static bool isEmailAllowed(String email) {
    final clean = email.trim();
    if (clean.isEmpty) return false;
    if (isSuperAdminEmail(clean)) return true;
    final type = computeEmailType(clean);
    if (type == 'university') return true;
    return allowPersonalEmails;
  }

  /// Validates student ID format (trimmed, non-empty, matches format regex).
  static bool isValidStudentId(String studentId) {
    final clean = studentId.trim();
    if (clean.isEmpty) return false;
    return studentIdRegex.hasMatch(clean);
  }

  /// Validates optional phone number format.
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return true; // Optional
    final clean = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    return phoneRegex.hasMatch(clean);
  }
}
