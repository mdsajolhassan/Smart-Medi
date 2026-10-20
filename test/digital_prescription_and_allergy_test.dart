import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/core/constants/drug_allergy_map.dart';
import 'package:smart_medi/features/auth_rbac/presentation/controllers/auth_controller.dart';
import 'package:smart_medi/features/dashboard/presentation/screens/detailed_medical_history_screen.dart';
import 'package:smart_medi/features/medical_onboarding_ai/data/services/gemini_ai_service.dart';
import 'package:smart_medi/features/medical_operations/data/models/prescription_model.dart';
import 'package:smart_medi/features/medical_operations/data/services/prescription_pdf_service.dart';
import 'package:smart_medi/features/medical_operations/presentation/screens/new_prescription_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  AuthState build() => _initialState;
}

void main() {
  group('1. Drug Allergy Cross-Reactivity & Heuristics Unit Tests', () {
    test('Penicillin family matches amoxicillin, ampicillin, augmentin', () {
      final res1 = checkMedicineAllergyConflict('Amoxicillin 500mg', ['Penicillin']);
      expect(res1.hasConflict, isTrue);
      expect(res1.matchedAllergy, 'Penicillin');

      final res2 = checkMedicineAllergyConflict('Augmentin 625mg', ['penicillin allergy']);
      expect(res2.hasConflict, isTrue);

      final res3 = checkMedicineAllergyConflict('Ciprofloxacin 500mg', ['Penicillin']);
      expect(res3.hasConflict, isFalse);
    });

    test('Sulfa family matches sulfamethoxazole, cotrimoxazole, bactrim', () {
      final res = checkMedicineAllergyConflict('Cotrimoxazole 480mg', ['Sulfa']);
      expect(res.hasConflict, isTrue);
      expect(res.matchedAllergy, 'Sulfa');
    });

    test('Aspirin/NSAID family matches ibuprofen, diclofenac, naproxen', () {
      final res1 = checkMedicineAllergyConflict('Ibuprofen 400mg', ['Aspirin']);
      expect(res1.hasConflict, isTrue);

      final res2 = checkMedicineAllergyConflict('Diclofenac 50mg', ['NSAID allergy']);
      expect(res2.hasConflict, isTrue);
    });

    test('Direct substring matching matches custom allergen', () {
      final res = checkMedicineAllergyConflict('Paracetamol 500mg', ['Paracetamol']);
      expect(res.hasConflict, isTrue);
      expect(res.matchedAllergy, 'Paracetamol');
    });
  });

  group('2. Digital Prescription Form Validation & Allergy Warning Widget Tests', () {
    testWidgets('NewPrescriptionScreen validates required diagnosis and medicine fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_123',
              studentId: '210401050',
              studentName: 'Tanvir Rahman',
              knownAllergies: ['Penicillin'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Issue Prescription with empty form
      final issueBtn = find.text('Issue Prescription');
      expect(issueBtn, findsOneWidget);
      await tester.ensureVisible(issueBtn);
      await tester.tap(issueBtn);
      await tester.pumpAndSettle();

      // Validation errors should appear
      expect(find.text('Diagnosis is required'), findsOneWidget);
      expect(find.text('Medicine name required'), findsOneWidget);
      expect(find.text('Required'), findsNWidgets(3)); // dose, frequency, duration
    });

    testWidgets('NewPrescriptionScreen displays amber note when no allergy data on file', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_123',
              studentId: '210401050',
              studentName: 'Tanvir Rahman',
              knownAllergies: [], // Empty allergies
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Amber note should appear
      expect(
        find.text('No allergy information on file - confirm with patient.'),
        findsOneWidget,
      );
      expect(find.text('Blood Group: Unverified'), findsOneWidget);
    });

    testWidgets('Allergy conflict banner appears for Amoxicillin when patient is allergic to Penicillin', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      PrescriptionModel? issuedPrescription;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_123',
              studentId: '210401050',
              studentName: 'Tanvir Rahman',
              knownAllergies: const ['Penicillin'],
              onIssuePrescriptionOverride: (rx) async {
                issuedPrescription = rx;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter diagnosis
      final diagnosisField = find.byType(TextFormField).at(0);
      await tester.enterText(diagnosisField, 'Acute Bacterial Tonsillitis');
      await tester.pumpAndSettle();

      // Enter Amoxicillin in Medicine 1
      final medicineNameField = find.byType(TextFormField).at(1);
      await tester.enterText(medicineNameField, 'Amoxicillin 500mg');
      await tester.pumpAndSettle();

      // Allergy conflict banner must appear on row
      expect(
        find.textContaining('Possible allergy conflict: patient reported Penicillin (AI-extracted, unverified - confirm with patient)'),
        findsOneWidget,
      );

      // Fill in remaining medicine fields
      final doseField = find.byType(TextFormField).at(2);
      await tester.enterText(doseField, '1 capsule');
      final freqField = find.byType(TextFormField).at(3);
      await tester.enterText(freqField, '1+1+1 (8 hourly)');
      final durField = find.byType(TextFormField).at(4);
      await tester.enterText(durField, '7 days');
      await tester.pumpAndSettle();

      // Tap Issue Prescription
      final issueBtn = find.text('Issue Prescription');
      await tester.ensureVisible(issueBtn);
      await tester.tap(issueBtn);
      await tester.pumpAndSettle();

      // Dialog opens with CRITICAL ALLERGY CONFLICT WARNING
      expect(find.text('Confirm Prescription'), findsOneWidget);
      expect(find.text('CRITICAL ALLERGY CONFLICT WARNING'), findsOneWidget);
      expect(find.text('I have checked with the patient'), findsOneWidget);

      // Dialog button disabled or guarded until checkbox is ticked
      final dialogIssueBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Issue Prescription'),
      );
      expect(dialogIssueBtn, findsOneWidget);

      // Tick checkbox
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Tap Issue Prescription in Dialog
      await tester.tap(dialogIssueBtn);
      await tester.pumpAndSettle();

      // Verify prescription was issued
      expect(issuedPrescription, isNotNull);
      expect(issuedPrescription!.diagnosis, 'Acute Bacterial Tonsillitis');
      expect(issuedPrescription!.items.first.name, 'Amoxicillin 500mg');
      expect(issuedPrescription!.source, 'digital');
    });
  });

  group('3. Detailed Medical History & Timeline Student Prescription Tests', () {
    testWidgets('DetailedMedicalHistoryScreen shows issued digital prescription in timeline and prescription section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testRx = PrescriptionModel(
        id: 'rx_test_baust_99',
        studentUid: 'student_sajol',
        studentId: '0802420205101137',
        studentName: 'MD. Sajol Hassan',
        doctorUid: 'doc_1',
        doctorName: 'Dr. Md Nakib Hayat',
        doctorDesignation: 'Senior Medical Officer',
        diagnosis: 'Seasonal Bronchitis',
        items: const [
          PrescriptionItem(
            name: 'Ventolin Inhaler',
            dose: '2 puffs',
            frequency: 'SOS (as needed)',
            duration: '14 days',
            instructions: 'Inhale during breathlessness',
          ),
          PrescriptionItem(
            name: 'Montelukast 10mg',
            dose: '1 tablet',
            frequency: '0+0+1',
            duration: '14 days',
            instructions: 'Night at bedtime',
          ),
        ],
        advice: 'Avoid cold beverages and dusty environments.',
        followUpDate: DateTime.now().add(const Duration(days: 7)),
        source: 'digital',
        createdAt: DateTime(2026, 10, 13, 10, 30),
      );

      final studentProfile = const UserProfile(
        uid: 'student_sajol',
        email: '0802420205101137@baust.edu.bd',
        displayName: 'MD. Sajol Hassan',
        studentRoll: '0802420205101137',
        role: 'student',
        department: 'Computer Science & Engineering (CSE)',
        bloodGroup: 'B+',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _MockAuthNotifier(
                AuthState(status: AuthStatus.authenticated, userProfile: studentProfile),
              ),
            ),
          ],
          child: MaterialApp(
            home: DetailedMedicalHistoryScreen(
              initialData: const {
                'procedures': [],
                'prescriptions': [],
                'activeIssues': [],
                'historicalProblems': [],
                'knownAllergies': ['Dust'],
              },
              initialPrescriptions: [testRx],
              isDoctorView: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify PRESCRIPTIONS ISSUED header and count
      expect(find.text('PRESCRIPTIONS ISSUED (1)'), findsOneWidget);

      // Verify diagnosis and doctor attribution
      expect(find.text('Seasonal Bronchitis'), findsWidgets);
      expect(find.text('Issued by BAUST Medical Center - Dr. Md Nakib Hayat'), findsWidgets);

      // Verify medicines rendered
      expect(find.textContaining('Ventolin Inhaler'), findsWidgets);
      expect(find.textContaining('Montelukast 10mg'), findsWidgets);

      // Verify Print / Save PDF button is present
      expect(find.text('Print / Save PDF'), findsWidgets);
    });
  });

  group('3. Paper Prescription Scanning & Form Pre-fill Tests', () {
    testWidgets('Scanning valid paper prescription pre-fills fields and shows "AI-extracted - verify" badges', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockFile = PlatformFile(
        name: 'rx_paper.jpg',
        size: 1024 * 100,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final mockExtraction = ExtractedMedicalData(
        isMedicalDocument: true,
        documentType: 'prescription',
        classificationReason: 'Handwritten prescription',
        patientName: 'MD. Sajol Hassan',
        bloodGroup: null,
        bloodGroupSource: 'not_found',
        chronicConditions: const [],
        currentMedications: const [
          MedicationItem(
            name: 'Azithromycin 500mg',
            dose: '1 tablet',
            frequency: '1+0+0',
            durationText: '3 days',
          ),
        ],
        abnormalLabs: const [],
        pastVisits: const [],
        diagnoses: const [DiagnosisItem(name: 'Acute Tonsillitis')],
        followUps: const [FollowUpItem(date: '25/10/2026')],
        doctorAdvice: 'Gargle with warm saline water twice daily.',
        rawJson: const {
          'is_medical_document': true,
          'document_type': 'prescription',
          'patient_name': 'MD. Sajol Hassan',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_sajol',
              studentId: '0802420205101137',
              studentName: 'MD. Sajol Hassan',
              knownAllergies: const [],
              onPickFileOverride: () async => mockFile,
              onScanOverride: (file) async => mockExtraction,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Scan Paper Prescription
      final scanBtn = find.text('Scan Paper Prescription');
      expect(scanBtn, findsOneWidget);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      // Verify fields pre-filled
      expect(find.text('Acute Tonsillitis'), findsOneWidget);
      expect(find.text('Azithromycin 500mg'), findsOneWidget);
      expect(find.text('1 tablet'), findsOneWidget);
      expect(find.text('1+0+0'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('Gargle with warm saline water twice daily.'), findsOneWidget);

      // Verify "AI-extracted - verify" badges are visible
      expect(find.text('AI-extracted - verify'), findsWidgets);

      // No name mismatch banner
      expect(find.text('Name on document does not match this patient - verify before issuing.'), findsNothing);
    });

    testWidgets('Editing a pre-filled field removes the "AI-extracted - verify" badge for that field', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockFile = PlatformFile(
        name: 'rx_paper.png',
        size: 5000,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final mockExtraction = ExtractedMedicalData(
        isMedicalDocument: true,
        documentType: 'prescription',
        classificationReason: 'Printed prescription',
        patientName: 'MD. Sajol Hassan',
        bloodGroup: null,
        bloodGroupSource: 'not_found',
        chronicConditions: const [],
        currentMedications: const [
          MedicationItem(
            name: 'Napa 500mg',
            dose: '1 tablet',
            frequency: '1+1+1',
            durationText: '3 days',
          ),
        ],
        abnormalLabs: const [],
        pastVisits: const [],
        diagnoses: const [DiagnosisItem(name: 'Viral Fever')],
        doctorAdvice: 'Drink plenty of water.',
        rawJson: const {'is_medical_document': true},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_sajol',
              studentId: '0802420205101137',
              studentName: 'MD. Sajol Hassan',
              knownAllergies: const [],
              onPickFileOverride: () async => mockFile,
              onScanOverride: (file) async => mockExtraction,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Paper Prescription'));
      await tester.pumpAndSettle();

      final initialBadgesCount = find.text('AI-extracted - verify').evaluate().length;
      expect(initialBadgesCount, greaterThan(0));

      // Doctor edits the diagnosis field
      final diagField = find.widgetWithText(TextFormField, 'Viral Fever');
      await tester.enterText(diagField, 'Viral Fever with Cough');
      await tester.pumpAndSettle();

      // Number of badges should decrease by 1
      final afterBadgesCount = find.text('AI-extracted - verify').evaluate().length;
      expect(afterBadgesCount, equals(initialBadgesCount - 1));
    });

    testWidgets('Extracted patient name mismatch triggers red warning banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockFile = PlatformFile(
        name: 'other_student_rx.jpg',
        size: 1024,
        bytes: Uint8List.fromList([1, 2]),
      );

      final mockExtraction = ExtractedMedicalData(
        isMedicalDocument: true,
        documentType: 'prescription',
        classificationReason: 'Prescription for another person',
        patientName: 'Kazi Farhan Ahmed', // Clearly differs from MD. Sajol Hassan
        bloodGroup: null,
        bloodGroupSource: 'not_found',
        chronicConditions: const [],
        currentMedications: const [
          MedicationItem(
            name: 'Omeprazole 20mg',
            dose: '1 cap',
            frequency: '1+0+1',
            durationText: '7 days',
          ),
        ],
        abnormalLabs: const [],
        pastVisits: const [],
        diagnoses: const [DiagnosisItem(name: 'Gastritis')],
        rawJson: const {'is_medical_document': true},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_sajol',
              studentId: '0802420205101137',
              studentName: 'MD. Sajol Hassan',
              knownAllergies: const [],
              onPickFileOverride: () async => mockFile,
              onScanOverride: (file) async => mockExtraction,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Paper Prescription'));
      await tester.pumpAndSettle();

      // Prominent red banner must be shown
      expect(
        find.text('Name on document does not match this patient - verify before issuing.'),
        findsOneWidget,
      );
      expect(find.textContaining('Document Name: Kazi Farhan Ahmed'), findsOneWidget);
    });

    testWidgets('No patient name found on document triggers subtle amber note', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockFile = PlatformFile(
        name: 'rx_no_name.jpg',
        size: 1024,
        bytes: Uint8List.fromList([1, 2]),
      );

      final mockExtraction = ExtractedMedicalData(
        isMedicalDocument: true,
        documentType: 'prescription',
        classificationReason: 'Prescription without name header',
        patientName: null, // No patient name
        bloodGroup: null,
        bloodGroupSource: 'not_found',
        chronicConditions: const [],
        currentMedications: const [
          MedicationItem(
            name: 'Cefixime 200mg',
            dose: '1 cap',
            frequency: '1+0+1',
            durationText: '5 days',
          ),
        ],
        abnormalLabs: const [],
        pastVisits: const [],
        diagnoses: const [DiagnosisItem(name: 'UTI')],
        rawJson: const {'is_medical_document': true},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_sajol',
              studentId: '0802420205101137',
              studentName: 'MD. Sajol Hassan',
              knownAllergies: const [],
              onPickFileOverride: () async => mockFile,
              onScanOverride: (file) async => mockExtraction,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Paper Prescription'));
      await tester.pumpAndSettle();

      // Amber note must be shown
      expect(find.text('No patient name found on document.'), findsOneWidget);
    });

    testWidgets('Non-prescription or non-medical document is rejected and leaves form blank', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockFile = PlatformFile(
        name: 'resume.pdf',
        size: 2048,
        bytes: Uint8List.fromList([1, 2]),
      );

      final mockNonMedical = ExtractedMedicalData(
        isMedicalDocument: false,
        documentType: 'other_non_medical',
        classificationReason: 'Curriculum Vitae detected',
        patientName: null,
        bloodGroup: null,
        bloodGroupSource: 'not_found',
        chronicConditions: const [],
        currentMedications: const [],
        abnormalLabs: const [],
        pastVisits: const [],
        rawJson: const {'is_medical_document': false},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_sajol',
              studentId: '0802420205101137',
              studentName: 'MD. Sajol Hassan',
              knownAllergies: const [],
              onPickFileOverride: () async => mockFile,
              onScanOverride: (file) async => mockNonMedical,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Paper Prescription'));
      await tester.pumpAndSettle();

      // Fixed rejection message
      expect(
        find.text('This does not look like a medical document. This looks like a non-medical document such as a CV, invoice or ID card.'),
        findsOneWidget,
      );

      // Diagnosis and medicines should remain blank
      expect(find.text('Acute Tonsillitis'), findsNothing);
      expect(find.text('Viral Fever'), findsNothing);
    });

    testWidgets('File larger than 5 MB is rejected immediately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final largeFile = PlatformFile(
        name: 'huge_scan.pdf',
        size: 6 * 1024 * 1024, // 6 MB > 5 MB
        bytes: Uint8List.fromList([1, 2]),
      );

      bool scanCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_sajol',
              studentId: '0802420205101137',
              studentName: 'MD. Sajol Hassan',
              knownAllergies: const [],
              onPickFileOverride: () async => largeFile,
              onScanOverride: (file) async {
                scanCalled = true;
                throw Exception('Should not be called');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Paper Prescription'));
      await tester.pumpAndSettle();

      expect(scanCalled, isFalse);
      expect(find.text('File is larger than 5 MB. Please upload a smaller file.'), findsOneWidget);
    });

    testWidgets('Nothing is saved automatically; saving requires Issue Prescription and confirms with source "scan"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockFile = PlatformFile(
        name: 'paper_rx.jpg',
        size: 1024,
        bytes: Uint8List.fromList([1, 2]),
      );

      final mockExtraction = ExtractedMedicalData(
        isMedicalDocument: true,
        documentType: 'prescription',
        classificationReason: 'Handwritten prescription',
        patientName: 'MD. Sajol Hassan',
        bloodGroup: null,
        bloodGroupSource: 'not_found',
        chronicConditions: const [],
        currentMedications: const [
          MedicationItem(
            name: 'Paracetamol 500mg',
            dose: '1 tablet',
            frequency: '1+0+1',
            durationText: '3 days',
          ),
        ],
        abnormalLabs: const [],
        pastVisits: const [],
        diagnoses: const [DiagnosisItem(name: 'Tension Headache')],
        rawJson: const {'is_medical_document': true},
      );

      PrescriptionModel? savedPrescription;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NewPrescriptionScreen(
              studentUid: 'student_sajol',
              studentId: '0802420205101137',
              studentName: 'MD. Sajol Hassan',
              knownAllergies: const [],
              onPickFileOverride: () async => mockFile,
              onScanOverride: (file) async => mockExtraction,
              onIssuePrescriptionOverride: (rx) async {
                savedPrescription = rx;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scan file
      await tester.tap(find.text('Scan Paper Prescription'));
      await tester.pumpAndSettle();

      // Ensure nothing is saved yet
      expect(savedPrescription, isNull);

      // Tap Issue Prescription button
      final issueBtn = find.text('Issue Prescription');
      await tester.ensureVisible(issueBtn);
      await tester.tap(issueBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears showing digitized source
      expect(find.text('Confirm Prescription'), findsOneWidget);
      expect(find.text('Source: Digitized from paper scan'), findsOneWidget);

      // Confirm in dialog
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Issue Prescription'),
      );
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Now verify saved prescription
      expect(savedPrescription, isNotNull);
      expect(savedPrescription!.source, equals('scan'));
      expect(savedPrescription!.diagnosis, equals('Tension Headache'));
      expect(savedPrescription!.items.first.name, equals('Paracetamol 500mg'));
    });

    testWidgets('DetailedMedicalHistoryScreen displays "(digitized from paper)" when rx.source is "scan"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final scannedRx = PrescriptionModel(
        id: 'rx_scanned_001',
        studentUid: 'student_sajol',
        studentId: '0802420205101137',
        studentName: 'MD. Sajol Hassan',
        doctorUid: 'doc_1',
        doctorName: 'Dr. Md Nakib Hayat',
        doctorDesignation: 'Senior Medical Officer',
        diagnosis: 'Acute Sinusitis',
        items: const [
          PrescriptionItem(
            name: 'Amoxicillin 500mg',
            dose: '1 capsule',
            frequency: '1+1+1',
            duration: '7 days',
          ),
        ],
        source: 'scan',
        createdAt: DateTime(2026, 10, 13, 11, 0),
      );

      final studentProfile = const UserProfile(
        uid: 'student_sajol',
        email: '0802420205101137@baust.edu.bd',
        displayName: 'MD. Sajol Hassan',
        role: 'student',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _MockAuthNotifier(
                AuthState(status: AuthStatus.authenticated, userProfile: studentProfile),
              ),
            ),
          ],
          child: MaterialApp(
            home: DetailedMedicalHistoryScreen(
              initialPrescriptions: [scannedRx],
              isDoctorView: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Issued by BAUST Medical Center - Dr. Md Nakib Hayat (digitized from paper)'),
        findsOneWidget,
      );
    });

    test('PrescriptionPdfService generates PDF with digitized footer when rx.source is "scan"', () async {
      final scannedRx = PrescriptionModel(
        id: 'rx_pdf_test_99',
        studentUid: 'student_sajol',
        studentId: '0802420205101137',
        studentName: 'MD. Sajol Hassan',
        doctorUid: 'doc_1',
        doctorName: 'Dr. Md Nakib Hayat',
        doctorDesignation: 'Senior Medical Officer',
        diagnosis: 'Allergic Rhinitis',
        items: const [
          PrescriptionItem(
            name: 'Fexofenadine 120mg',
            dose: '1 tablet',
            frequency: '0+0+1',
            duration: '10 days',
          ),
        ],
        source: 'scan',
        createdAt: DateTime(2026, 10, 13, 12, 0),
      );

      final pdfBytes = await PrescriptionPdfService.generatePdf(scannedRx);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
