import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_medi/features/medical_onboarding_ai/data/services/gemini_ai_service.dart';
import 'package:smart_medi/features/medical_onboarding_ai/presentation/screens/medical_onboarding_screen.dart';

void main() {
  group('MedicalOnboardingScreen Widget Tests', () {
    testWidgets('Non-medical document (CV) displays red error card and hides/disables Save button', (WidgetTester tester) async {
      final nonMedicalData = ExtractedMedicalData.fromMap({
        'is_medical_document': false,
        'document_type': 'other_non_medical',
        'classification_reason': 'Curriculum Vitae detected with bio and education',
        'blood_group': 'O+',
        'blood_group_source': 'other_document',
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: nonMedicalData,
            ),
          ),
        ),
      );

      // Verify Red Error Card is rendered with fixed privacy-safe message
      expect(find.text('This does not look like a medical document'), findsOneWidget);
      expect(find.text('This looks like a non-medical document such as a CV, invoice or ID card.'), findsOneWidget);
      expect(find.textContaining('AI Classification:'), findsNothing);

      // Verify Clinical Summary and Save button are NOT rendered
      expect(find.text('EXTRACTED CLINICAL SUMMARY'), findsNothing);
      expect(find.text('SAVE & CONTINUE TO SOS PORTAL'), findsNothing);

      // Verify Reset/Upload another file button is available
      final resetBtnFinder = find.text('Upload another file');
      expect(resetBtnFinder, findsOneWidget);

      await tester.tap(resetBtnFinder);
      await tester.pumpAndSettle();

      // Should return to select document step
      expect(find.text('Upload Past Prescriptions / Medical Records'), findsOneWidget);
    });

    testWidgets('Unreadable file displays specific unreadable error messaging', (WidgetTester tester) async {
      final unreadableData = ExtractedMedicalData.fromMap({
        'is_medical_document': false,
        'document_type': 'unreadable',
        'classification_reason': 'File is too blurry or low-resolution to decipher',
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: unreadableData,
            ),
          ),
        ),
      );

      expect(find.text('We could not read this file'), findsOneWidget);
      expect(find.text('Please upload a clearer photo or PDF.'), findsOneWidget);
      expect(find.text('SAVE & CONTINUE TO SOS PORTAL'), findsNothing);
    });

    testWidgets('Medical document with zero clinical details requires confirmation before enabling Save', (WidgetTester tester) async {
      final emptyMedicalData = ExtractedMedicalData.fromMap({
        'is_medical_document': true,
        'document_type': 'clinical_record',
        'classification_reason': 'Clinical record without entries',
        'blood_group': null,
        'drug_allergies': [],
        'food_allergies': [],
        'environmental_allergies': [],
        'chronic_conditions': [],
        'current_medications': [],
        'abnormal_labs': [],
        'past_visits': [],
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: emptyMedicalData,
            ),
          ),
        ),
      );

      // Verify Amber Warning Card is shown
      expect(find.text('No clinical details were found in this file'), findsOneWidget);

      // Save button exists
      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'SAVE & CONTINUE TO SOS PORTAL');
      expect(saveBtnFinder, findsOneWidget);

      // Save button is initially disabled (onPressed == null)
      ElevatedButton saveButton = tester.widget<ElevatedButton>(saveBtnFinder);
      expect(saveButton.onPressed, isNull);

      // Tap confirmation checkbox
      final checkboxFinder = find.byType(CheckboxListTile);
      expect(checkboxFinder, findsOneWidget);
      await tester.ensureVisible(checkboxFinder);
      await tester.pumpAndSettle();
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Save button should now be enabled
      saveButton = tester.widget<ElevatedButton>(saveBtnFinder);
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('Valid medical record shows source chip and does not show verified for clinical_record', (WidgetTester tester) async {
      final clinicalData = ExtractedMedicalData.fromMap({
        'is_medical_document': true,
        'document_type': 'clinical_record',
        'classification_reason': 'Outpatient visit',
        'blood_group': 'B positive',
        'blood_group_source': 'clinical_record',
        'drug_allergies': ['Penicillin'],
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: clinicalData,
            ),
          ),
        ),
      );

      // Verify label
      expect(find.text('Blood Group (as written in document)'), findsOneWidget);
      expect(find.text('Group: B+'), findsOneWidget);
      // Verify unverified chip
      expect(find.text('Unverified - confirm with a lab test'), findsOneWidget);
      expect(find.text('From lab report'), findsNothing);
      expect(find.text('Extracted from record'), findsNothing);
    });

    testWidgets('Medical record renders Surgeries and Hospital Admissions, Medications (from document) with chips, and Allergy reactions', (WidgetTester tester) async {
      final data = ExtractedMedicalData.fromMap({
        'is_medical_document': true,
        'document_type': 'discharge_summary',
        'classification_reason': 'Post-op discharge summary',
        'procedures': [
          {'name': 'Laparoscopic appendectomy', 'date': '14 Aug 2026'},
        ],
        'hospital_admissions': [
          {
            'admit_date': '12 Aug 2026',
            'discharge_date': '16 Aug 2026',
            'reason': 'acute appendicitis',
          }
        ],
        'current_medications': [
          {
            'name': 'Cefuroxime',
            'dose': '500mg',
            'frequency': 'BD',
            'prescribed_date': '2026-08-01',
            'duration_text': '5 days',
          },
        ],
        'drug_allergies': [
          {'substance': 'Penicillin', 'reaction': 'itching, skin rash'},
        ],
      }, referenceDate: DateTime(2026, 8, 20));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: data,
            ),
          ),
        ),
      );

      // Verify Surgeries and Admissions Section
      expect(find.text('Surgeries and Hospital Admissions'), findsOneWidget);
      expect(find.text('Laparoscopic appendectomy - 14 Aug 2026'), findsOneWidget);
      expect(find.text('Admitted 12 Aug 2026 - 16 Aug 2026, acute appendicitis'), findsOneWidget);

      // Verify Medications (from document) Section
      expect(find.text('Medications (from document)'), findsOneWidget);
      expect(find.text('Cefuroxime'), findsOneWidget);
      expect(find.text('Prescribed: 2026-08-01'), findsOneWidget);
      expect(find.text('Duration: 5 days'), findsOneWidget);
      expect(find.text('Course ended'), findsOneWidget);

      // Verify Allergy Reaction display
      expect(find.text('Penicillin - itching, skin rash'), findsOneWidget);
    });

    testWidgets('Medication renders grey "Prescribed date not stated" chip when date missing, and "Prescribed (at discharge): <date>" when discharge fallback exists', (WidgetTester tester) async {
      final dischargeData = ExtractedMedicalData.fromMap({
        'is_medical_document': true,
        'document_type': 'discharge_summary',
        'hospital_admissions': [
          {
            'admit_date': '12 Aug 2026',
            'discharge_date': '16 Aug 2026',
            'reason': 'acute appendicitis',
          }
        ],
        'current_medications': [
          {
            'name': 'Cefuroxime',
            'dose': '500mg',
            'frequency': 'BD',
            'prescribed_date': null,
            'duration_text': '5 days',
          },
          {
            'name': 'Paracetamol',
            'dose': '500mg',
            'frequency': 'TDS',
            'prescribed_date': null,
            'duration_text': null,
          },
        ],
      }, referenceDate: DateTime(2026, 8, 20));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: dischargeData,
            ),
          ),
        ),
      );

      // Verify discharge date fallback subtitle on both discharge medicines
      expect(find.text('Prescribed (at discharge): 16 Aug 2026'), findsNWidgets(2));

      // Verify Paracetamol without duration shows Duration not stated
      expect(find.text('Duration not stated'), findsOneWidget);

      // Now test a regular prescription with missing date
      final prescriptionMissingDate = ExtractedMedicalData.fromMap({
        'is_medical_document': true,
        'document_type': 'prescription',
        'current_medications': [
          {
            'name': 'Azithromycin',
            'dose': '500mg',
            'frequency': 'Daily',
            'prescribed_date': null,
            'duration_text': '5 days',
          },
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: prescriptionMissingDate,
            ),
          ),
        ),
      );

      expect(find.text('Prescribed date not stated'), findsOneWidget);
    });

    testWidgets('Doctor\'s Advice card renders Scheduled Follow-ups row with appointment icon and details', (WidgetTester tester) async {
      final followUpData = ExtractedMedicalData.fromMap({
        'is_medical_document': true,
        'document_type': 'prescription',
        'doctor_advice': 'Take medications with food. Avoid cold drinks.',
        'follow_ups': [
          {
            'date': '12 Nov 2026',
            'place': 'Outpatient Department',
            'purpose': 'CBC & Chest X-Ray review',
          }
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MedicalOnboardingScreen(
              initialStep: OnboardingStep.reviewSummary,
              initialData: followUpData,
            ),
          ),
        ),
      );

      // Verify Doctor's Advice text
      expect(find.text('Take medications with food. Avoid cold drinks.'), findsOneWidget);

      // Verify Scheduled Follow-ups section and row
      expect(find.text('Scheduled Follow-ups'), findsOneWidget);
      expect(find.text('12 Nov 2026 • Outpatient Department • CBC & Chest X-Ray review'), findsOneWidget);
    });
  });
}
