import 'package:flutter/material.dart';

class BaustColors {
  // BAUST Official Military/Army Green & Accents
  static const Color primaryArmyGreen = Color(0xFF245122);
  static const Color armyGreenDark = Color(0xFF173516);
  static const Color armyGreenLight = Color(0xFF3F773C);
  static const Color armyOlive = Color(0xFF4B6B40);

  // Backward-compatible alias for existing views
  static const Color primaryNavy = primaryArmyGreen;
  static const Color navyDark = armyGreenDark;
  static const Color navyLight = armyGreenLight;

  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyRedGlow = Color(0xFFFCA5A5);
  static const Color surfaceBg = Color(0xFFF6F8F5);
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
  // TODO(add verified numbers from the university)
  static const String ambulancePhone = '';

  static String get hotlineDisplay =>
      medicalHotline.trim().isNotEmpty ? medicalHotline.trim() : 'Coming soon';
  static String get ambulanceDisplay =>
      ambulancePhone.trim().isNotEmpty ? ambulancePhone.trim() : 'Coming soon';
}

class BaustSeedData {
  // Real BAUST Medical Center Staff
  static final List<Map<String, String?>> medicalStaff = [
    {
      'name': 'Dr. Fowzia Jahan',
      'email': 'medicalcenter@baust.edu.bd',
      'phone': '01769-675576',
      'department': 'BAUST Medical Center',
      'designation': 'Senior Medical Officer',
      'accessLevel': 'Doctor',
      'role': 'doctor',
    },
    {
      'name': 'Md. Mozaffor Hossain',
      'email': null,
      'phone': '01712-645975',
      'department': 'BAUST Medical Center',
      'designation': 'Medical Assistant',
      'accessLevel': 'Pharmacist',
      'role': 'pharmacist',
    },
    {
      'name': 'Lamia Aktar Limu',
      'email': 'limuakhtar9@gmail.com',
      'phone': '01749-898473',
      'department': 'BAUST Medical Center',
      'designation': 'Staff Nurse',
      'accessLevel': 'Pharmacist',
      'role': 'pharmacist',
    },
  ];

  // Strictly authentic staff & department leadership only
  static final List<Map<String, String?>> initialFaculty = [
    // 1. BAUST Medical Center Staff
    {
      'name': 'Dr. Fowzia Jahan',
      'email': 'medicalcenter@baust.edu.bd',
      'phone': '01769-675576',
      'department': 'BAUST Medical Center',
      'designation': 'Senior Medical Officer',
      'accessLevel': 'Doctor',
      'role': 'doctor',
    },
    {
      'name': 'Md. Mozaffor Hossain',
      'email': null,
      'phone': '01712-645975',
      'department': 'BAUST Medical Center',
      'designation': 'Medical Assistant',
      'accessLevel': 'Pharmacist',
      'role': 'pharmacist',
    },
    {
      'name': 'Lamia Aktar Limu',
      'email': 'limuakhtar9@gmail.com',
      'phone': '01749-898473',
      'department': 'BAUST Medical Center',
      'designation': 'Staff Nurse',
      'accessLevel': 'Pharmacist',
      'role': 'pharmacist',
    },

    // 2. Academic Department Leadership
    {
      'name': 'Dr. Md Nakib Hayat Chowdhury',
      'email': null,
      'phone': '01769675560',
      'department': 'Computer Science & Engineering (CSE)',
      'designation': 'Head of Department (CSE) / Associate Professor',
      'accessLevel': 'Head of Department (Head)',
      'role': 'staff',
    },
  ];
}

class FirestoreCollections {
  static const String emergencyAlerts = 'emergency_alerts';
  static const String users = 'users';
  static const String students = 'students';
  static const String faculty = 'faculty';
  static const String inventory = 'inventory';
  static const String patientCheckins = 'patient_checkins';
}
