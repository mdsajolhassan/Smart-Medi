import 'package:flutter/material.dart';

class BaustColors {
  // Smart Medi purple brand palette.
  // (Legacy "armyGreen"/"navy" names are kept as aliases so every screen picks up the new theme.)
  static const Color primaryPurple = Color(0xFF6D28D9); // violet 700
  static const Color purpleDark = Color(0xFF4C1D95); // violet 900
  static const Color purpleLight = Color(0xFF8B5CF6); // violet 500
  static const Color purpleAccent = Color(0xFFC026D3); // fuchsia 600
  static const Color purpleTint = Color(0xFFF3EEFF);

  static const Color primaryArmyGreen = primaryPurple;
  static const Color armyGreenDark = purpleDark;
  static const Color armyGreenLight = purpleLight;
  static const Color armyOlive = Color(0xFF7E22CE);

  // Backward-compatible alias for existing views
  static const Color primaryNavy = primaryArmyGreen;
  static const Color navyDark = armyGreenDark;
  static const Color navyLight = armyGreenLight;

  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyRedGlow = Color(0xFFFCA5A5);
  static const Color surfaceBg = Color(0xFFF8F6FC);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF16A34A);
}

class BaustHalls {
  static const List<String> residentialHalls = [
    'Shaheed Dr. Zikrul Haque Hall (SDZHH)',
    'Abbas Uddin Ahmed Hall (AUAH)',
    'Bir Protik Taramon Bibi Hall (BPTBH)',
    'Bir Protik Taramon Bibi Hall (BPTBH) Annex',
    'Non-Residential (Day Scholar)',
  ];
}

class BangladeshDistricts {
  static const List<String> districts = [
    'Nilphamari',
    'Rangpur',
    'Dinajpur',
    'Dhaka',
    'Bagerhat',
    'Bandarban',
    'Barguna',
    'Barishal',
    'Bhola',
    'Bogura',
    'Brahmanbaria',
    'Chandpur',
    'Chattogram',
    'Chapainawabganj',
    'Chuadanga',
    'Cox\'s Bazar',
    'Cumilla',
    'Faridpur',
    'Feni',
    'Gaibandha',
    'Gazipur',
    'Gopalganj',
    'Habiganj',
    'Jamalpur',
    'Jashore',
    'Jhalokathi',
    'Jhenaidah',
    'Joypurhat',
    'Khagrachhari',
    'Khulna',
    'Kishoreganj',
    'Kurigram',
    'Kushtia',
    'Lakshmipur',
    'Lalmonirhat',
    'Madaripur',
    'Magura',
    'Manikganj',
    'Meherpur',
    'Moulvibazar',
    'Munshiganj',
    'Mymensingh',
    'Naogaon',
    'Narail',
    'Narayanganj',
    'Narsingdi',
    'Natore',
    'Netrokona',
    'Noakhali',
    'Pabna',
    'Panchagarh',
    'Patuakhali',
    'Pirojpur',
    'Rajbari',
    'Rajshahi',
    'Rangamati',
    'Satkhira',
    'Shariatpur',
    'Sherpur',
    'Sirajganj',
    'Sunamganj',
    'Sylhet',
    'Tangail',
    'Thakurgaon',
  ];
}

class BaustDepartments {
  static const List<String> departments = [
    'Computer Science & Engineering (CSE)',
    'Electrical & Electronic Engineering (EEE)',
    'Mechanical Engineering (ME)',
    'Civil Engineering (CE)',
    'Information & Communication Technology (ICT)',
    'Industrial & Production Engineering (IPE)',
    'Accounting & Information Systems (AIS)',
    'Business Administration (DBA)',
    'English',
    'Arts & Sciences',
    'BAUST Medical Center',
    'Central Administration',
    'Examination Wing',
  ];
}

class FacultyDesignations {
  static const List<String> designations = [
    'Professor',
    'Associate Professor',
    'Assistant Professor',
    'Lecturer',
    'Chief Medical Officer',
    'Medical Officer',
    'Medical Assistant',
    'Nurse',
    'Pharmacist',
  ];
}

class FacultyAccessRoles {
  static const List<String> roles = [
    'Vice Chancellor (VC)',
    'Registrar',
    'Controller of Examinations',
    'Proctor',
    'Head of Department (Head)',
    'Batch Coordinator',
    'Advisor',
    'Medical Chief',
    'Doctor',
    'Pharmacist',
  ];
}

class BaustEmergencyContacts {
  // TODO(add verified numbers from the university)
  static const String medicalHotline = '';
  static const String ambulancePhone = '01945678934';

  static String get hotlineDisplay => medicalHotline.trim().isNotEmpty ? medicalHotline.trim() : 'Coming soon';
  static String get ambulanceDisplay => ambulancePhone.trim().isNotEmpty ? ambulancePhone.trim() : 'Coming soon';
}

class FirestoreCollections {
  static const String emergencyAlerts = 'emergency_alerts';
  static const String users = 'users';
  static const String students = 'students';
  static const String faculty = 'faculty';
  static const String inventory = 'inventory';
  static const String patientCheckins = 'patient_checkins';
  static const String customMedicineRequests = 'custom_medicine_requests';
  static const String pharmacyNotifications = 'pharmacy_notifications';
}

/// Medicines stocked at the BAUST Medical Center pharmacy, plus common
/// diagnostic tests a doctor can refer. Anything outside the pharmacy list is
/// a "custom" medicine and is sent to the admin account for review.
class PharmacyCatalogue {
  static const List<String> stockedMedicines = [
    'Napa 500mg',
    'Seclo 20mg',
    'Metronidazole 400mg',
    'Orsaline-N / SMC ORS',
    'Povidone Iodine 10%',
  ];

  static bool isStocked(String name) {
    final n = name.trim().toLowerCase();
    return stockedMedicines.any((m) => m.toLowerCase() == n);
  }

  static const List<String> commonTests = [
    'CBC',
    'Blood Sugar (RBS)',
    'Urine R/E',
    'Chest X-Ray',
    'ECG',
    'Lipid Profile',
    'LFT (SGPT)',
    'Serum Creatinine',
    'Dengue NS1',
    'Widal Test',
  ];
}
