import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medi/features/medical_onboarding_ai/data/services/gemini_ai_service.dart';

void main() {
  group('ExtractedMedicalData Response Parser Unit Tests', () {
    test('1. Non-medical response (CV) -> model reports not medical, all clinical fields empty', () {
      final cvJson = {
        'is_medical_document': false,
        'document_type': 'other_non_medical',
        'classification_reason': 'Curriculum Vitae / Resume containing bio and education details',
        'blood_group': 'O+',
        'blood_group_source': 'other_document',
        'blood_group_evidence': 'Blood Group: O+',
        'drug_allergies': ['Penicillin'],
        'food_allergies': ['Peanuts'],
        'environmental_allergies': ['Dust'],
        'chronic_conditions': ['Hypertension'],
        'current_medications': [
          {'name': 'Paracetamol', 'dose': '500mg', 'frequency': 'SOS'}
        ],
        'abnormal_labs': ['High Cholesterol'],
        'past_visits': [
          {'date': '2024-01-01', 'diagnosis': 'Routine checkup'}
        ],
        'doctor_advice': 'Drink plenty of water',
      };

      final data = ExtractedMedicalData.fromMap(cvJson);

      expect(data.isMedicalDocument, isFalse);
      expect(data.documentType, equals('other_non_medical'));
      expect(data.bloodGroup, isNull);
      expect(data.bloodGroupSource, equals('not_found'));
      expect(data.bloodGroupEvidence, isNull);
      expect(data.bloodGroupVerified, isFalse);
      expect(data.drugAllergies, isEmpty);
      expect(data.foodAllergies, isEmpty);
      expect(data.environmentalAllergies, isEmpty);
      expect(data.chronicConditions, isEmpty);
      expect(data.currentMedications, isEmpty);
      expect(data.abnormalLabs, isEmpty);
      expect(data.pastVisits, isEmpty);
      expect(data.doctorAdvice, isNull);
      expect(data.hasNoClinicalDetails, isTrue);
    });

    test('2. Missing or malformed is_medical_document -> treated defensively as not medical', () {
      // Missing is_medical_document key
      final missingFieldJson = {
        'document_type': 'prescription',
        'blood_group': 'B+',
        'drug_allergies': ['Aspirin'],
      };

      final data1 = ExtractedMedicalData.fromMap(missingFieldJson);
      expect(data1.isMedicalDocument, isFalse);
      expect(data1.bloodGroup, isNull);
      expect(data1.drugAllergies, isEmpty);

      // Malformed non-boolean is_medical_document (e.g. string "true" or int 1)
      final malformedJson = {
        'is_medical_document': 'true',
        'document_type': 'prescription',
        'blood_group': 'B+',
      };

      final data2 = ExtractedMedicalData.fromMap(malformedJson);
      expect(data2.isMedicalDocument, isFalse);
      expect(data2.bloodGroup, isNull);
    });

    test('3. Blood group normalization ("B positive" -> B+, "O ve" -> O+, "xyz" -> null)', () {
      expect(ExtractedMedicalData.normalizeBloodGroup('B positive'), equals('B+'));
      expect(ExtractedMedicalData.normalizeBloodGroup('O ve'), equals('O+'));
      expect(ExtractedMedicalData.normalizeBloodGroup('xyz'), isNull);
      expect(ExtractedMedicalData.normalizeBloodGroup('B+ve'), equals('B+'));
      expect(ExtractedMedicalData.normalizeBloodGroup('O -ve'), equals('O-'));
      expect(ExtractedMedicalData.normalizeBloodGroup('AB positive'), equals('AB+'));
      expect(ExtractedMedicalData.normalizeBloodGroup('বি পজিটিভ'), equals('B+'));
      expect(ExtractedMedicalData.normalizeBloodGroup('Bronchitis'), isNull);
      expect(ExtractedMedicalData.normalizeBloodGroup('B'), isNull); // Ambiguous: no Rh
      expect(ExtractedMedicalData.normalizeBloodGroup(null), isNull);
      expect(ExtractedMedicalData.normalizeBloodGroup(''), isNull);
    });

    test('4. blood_group_source lab_report vs clinical_record', () {
      // Genuine lab report with blood grouping
      final labJson = {
        'is_medical_document': true,
        'document_type': 'lab_report',
        'classification_reason': 'Blood grouping diagnostic test report',
        'blood_group': 'A positive',
        'blood_group_source': 'lab_report',
        'blood_group_evidence': 'ABO & Rh Type: A Positive',
      };
      final labData = ExtractedMedicalData.fromMap(labJson);
      expect(labData.isMedicalDocument, isTrue);
      expect(labData.bloodGroup, equals('A+'));
      expect(labData.bloodGroupSource, equals('lab_report'));
      expect(labData.bloodGroupVerified, isFalse); // AI extraction is never auto-verified

      // Clinical prescription citing a blood group
      final rxJson = {
        'is_medical_document': true,
        'document_type': 'prescription',
        'classification_reason': 'Outpatient prescription note',
        'blood_group': 'B ve',
        'blood_group_source': 'clinical_record',
        'blood_group_evidence': 'Patient B/G: B+ve',
      };
      final rxData = ExtractedMedicalData.fromMap(rxJson);
      expect(rxData.isMedicalDocument, isTrue);
      expect(rxData.bloodGroup, equals('B+'));
      expect(rxData.bloodGroupSource, equals('clinical_record'));

      // If document is a prescription but AI incorrectly tags blood_group_source as lab_report
      final fakeLabJson = {
        'is_medical_document': true,
        'document_type': 'prescription',
        'classification_reason': 'Prescription',
        'blood_group': 'O+',
        'blood_group_source': 'lab_report',
      };
      final fakeLabData = ExtractedMedicalData.fromMap(fakeLabJson);
      expect(fakeLabData.bloodGroupSource, equals('clinical_record'));

      // Medical document without blood group
      final noBgJson = {
        'is_medical_document': true,
        'document_type': 'prescription',
        'classification_reason': 'Prescription',
        'blood_group': null,
      };
      final noBgData = ExtractedMedicalData.fromMap(noBgJson);
      expect(noBgData.bloodGroupSource, equals('not_found'));
    });

    test('5. Task A: Surgeries, procedures, and hospital admissions extraction', () {
      final json = {
        'is_medical_document': true,
        'document_type': 'discharge_summary',
        'classification_reason': 'Hospital discharge summary',
        'procedures': [
          {'name': 'Laparoscopic appendectomy', 'date': '14 Aug 2026'},
          {'name': 'Wound dressing', 'date': null},
        ],
        'diagnoses': [
          {'name': 'Acute appendicitis', 'date': '12 Aug 2026'},
        ],
        'hospital_admissions': [
          {
            'admit_date': '12 Aug 2026',
            'discharge_date': '16 Aug 2026',
            'reason': 'acute appendicitis',
          }
        ],
        'chronic_conditions': ['Hypertension'],
      };

      final data = ExtractedMedicalData.fromMap(json);

      expect(data.isMedicalDocument, isTrue);
      expect(data.procedures.length, equals(2));
      expect(data.procedures[0].name, equals('Laparoscopic appendectomy'));
      expect(data.procedures[0].date, equals('14 Aug 2026'));
      expect(data.procedures[1].name, equals('Wound dressing'));
      expect(data.procedures[1].date, isNull);

      expect(data.diagnoses.length, equals(1));
      expect(data.diagnoses[0].name, equals('Acute appendicitis'));
      expect(data.diagnoses[0].date, equals('12 Aug 2026'));

      expect(data.hospitalAdmissions.length, equals(1));
      expect(data.hospitalAdmissions[0].admitDate, equals('12 Aug 2026'));
      expect(data.hospitalAdmissions[0].dischargeDate, equals('16 Aug 2026'));
      expect(data.hospitalAdmissions[0].reason, equals('acute appendicitis'));

      // Check historical problems aggregates procedures and admissions
      expect(
        data.historicalProblems,
        contains('Laparoscopic appendectomy (14 Aug 2026)'),
      );
      expect(
        data.historicalProblems,
        contains('Admission: acute appendicitis on 12 Aug 2026'),
      );
    });

    test('6. Task B: Medication timing, duration parsing, and status calculation', () {
      final refDate = DateTime(2026, 8, 20);

      // Past course ended (2026-08-01 + 5 days = 2026-08-06 < 2026-08-20)
      expect(
        GeminiAiService.calculateMedicationStatus(
          '2026-08-01',
          '5 days',
          referenceDate: refDate,
        ),
        equals('Course ended'),
      );

      // Bangla digits and duration ended ('1 Aug 2026' + ২ সপ্তাহ (14 days) = 15 Aug 2026 < 20 Aug 2026)
      expect(
        GeminiAiService.calculateMedicationStatus(
          '1 Aug 2026',
          '২ সপ্তাহ',
          referenceDate: refDate,
        ),
        equals('Course ended'),
      );

      // Active course (2026-08-15 + 14 days = 2026-08-29 >= 2026-08-20)
      expect(
        GeminiAiService.calculateMedicationStatus(
          '15 Aug 2026',
          '14 days',
          referenceDate: refDate,
        ),
        equals('Active'),
      );

      // Bangla 1 month active (2026-08-05 + ১ মাস (30 days) = 2026-09-04 >= 2026-08-20)
      expect(
        GeminiAiService.calculateMedicationStatus(
          '5 Aug 2026',
          '১ মাস',
          referenceDate: refDate,
        ),
        equals('Active'),
      );

      // Indefinite / Ongoing / As needed
      expect(
        GeminiAiService.calculateMedicationStatus(
          '1 Jan 2026',
          'ongoing',
          referenceDate: refDate,
        ),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus(
          '1 Jan 2026',
          'as needed',
          referenceDate: refDate,
        ),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus(
          null,
          'চলবে',
          referenceDate: refDate,
        ),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus(
          null,
          'প্রয়োজনমতো',
          referenceDate: refDate,
        ),
        equals('Ongoing / as needed'),
      );

      // Unparsable / missing duration
      expect(
        GeminiAiService.calculateMedicationStatus(
          '1 Aug 2026',
          null,
          referenceDate: refDate,
        ),
        equals('Duration not stated'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus(
          '1 Aug 2026',
          'some unknown note',
          referenceDate: refDate,
        ),
        equals('Duration not stated'),
      );

      // Via ExtractedMedicalData.fromMap
      final medJson = {
        'is_medical_document': true,
        'current_medications': [
          {
            'name': 'Amoxicillin',
            'dose': '500mg',
            'frequency': 'TDS',
            'prescribed_date': '2026-08-01',
            'duration_text': '5 days',
          },
          {
            'name': 'Montelukast',
            'dose': '10mg',
            'frequency': 'Daily',
            'prescribed_date': '2026-08-15',
            'duration_text': 'ongoing',
          },
        ]
      };

      final data = ExtractedMedicalData.fromMap(medJson, referenceDate: refDate);
      expect(data.currentMedications.length, equals(2));
      expect(data.currentMedications[0].status, equals('Course ended'));
      expect(data.currentMedications[0].prescribedDate, equals('2026-08-01'));
      expect(data.currentMedications[0].durationText, equals('5 days'));
      expect(data.currentMedications[1].status, equals('Ongoing / as needed'));
    });

    test('7. Task C: Condition de-duplication and bilingual synonym mapping', () {
      // 1. Both Asthma and হাঁপানি should merge into a single "Asthma (হাঁপানি)"
      final raw1 = ['Asthma', 'হাঁপানি'];
      final merged1 = GeminiAiService.normalizeAndDeduplicateConditions(raw1);
      expect(merged1, equals(['Asthma (হাঁপানি)']));

      // 2. Only Bangla "হাঁপানি" should normalize to "Asthma (হাঁপানি)"
      final raw2 = ['হাঁপানি'];
      final merged2 = GeminiAiService.normalizeAndDeduplicateConditions(raw2);
      expect(merged2, equals(['Asthma (হাঁপানি)']));

      // 3. Diabetes and ডায়াবেটিস merge
      final raw3 = ['Diabetes', 'ডায়াবেটিস'];
      final merged3 = GeminiAiService.normalizeAndDeduplicateConditions(raw3);
      expect(merged3, equals(['Diabetes (ডায়াবেটিস)']));

      // 4. Allergy and এলার্জি merge
      final raw4 = ['Allergy', 'এলার্জি'];
      final merged4 = GeminiAiService.normalizeAndDeduplicateConditions(raw4);
      expect(merged4, equals(['Allergy (এলার্জি)']));

      // 5. Preserves non-synonym items without duplicate
      final raw5 = ['Asthma', 'হাঁপানি', 'Migraine', 'Migraine'];
      final merged5 = GeminiAiService.normalizeAndDeduplicateConditions(raw5);
      expect(merged5, equals(['Asthma (হাঁপানি)', 'Migraine']));

      // Via ExtractedMedicalData.fromMap
      final data = ExtractedMedicalData.fromMap({
        'is_medical_document': true,
        'chronic_conditions': ['Asthma', 'হাঁপানি', 'ডায়াবেটিস'],
      });
      expect(data.chronicConditions, equals(['Asthma (হাঁপানি)', 'Diabetes (ডায়াবেটিস)']));
    });

    test('8. Task D: Allergy reactions structured parsing and display format', () {
      final json = {
        'is_medical_document': true,
        'drug_allergies': [
          {'substance': 'Penicillin', 'reaction': 'itching, skin rash'},
          {'substance': 'Aspirin', 'reaction': null},
        ],
        'food_allergies': [
          {'substance': 'Peanuts', 'reaction': 'facial swelling'},
        ],
        'environmental_allergies': [
          {'substance': 'Dust', 'reaction': null},
        ],
      };

      final data = ExtractedMedicalData.fromMap(json);

      // Display text formatted with reaction
      expect(data.drugAllergies, equals(['Penicillin - itching, skin rash', 'Aspirin']));
      expect(data.foodAllergies, equals(['Peanuts - facial swelling']));
      expect(data.environmentalAllergies, equals(['Dust']));

      // Structured item access
      expect(data.drugAllergyItems[0].substance, equals('Penicillin'));
      expect(data.drugAllergyItems[0].reaction, equals('itching, skin rash'));
      expect(data.drugAllergyItems[1].substance, equals('Aspirin'));
      expect(data.drugAllergyItems[1].reaction, isNull);

      // String backward compatibility fallback
      final itemFromString = AllergyItem.fromDynamic('Penicillin - itching, skin rash');
      expect(itemFromString.substance, equals('Penicillin'));
      expect(itemFromString.reaction, equals('itching, skin rash'));
      expect(itemFromString.displayText, equals('Penicillin - itching, skin rash'));
    });

    test('9. Task E: Privacy sanitization of non-medical classification reason', () {
      const reasonWithPii = 'Curriculum Vitae belonging to John Doe with email john@baust.edu.bd and phone +8801712345678';
      final sanitized = GeminiAiService.sanitizeClassificationReason(reasonWithPii);

      expect(sanitized, isNot(contains('John Doe')));
      expect(sanitized, isNot(contains('john@baust.edu.bd')));
      expect(sanitized, isNot(contains('+8801712345678')));
      expect(sanitized, contains('[redacted name]'));
      expect(sanitized, contains('[redacted email]'));
      expect(sanitized, contains('[redacted phone]'));

      // Clean generic reason left intact
      const safeReason = 'Curriculum Vitae / Resume containing bio and education details';
      expect(GeminiAiService.sanitizeClassificationReason(safeReason), equals(safeReason));
    });

    test('10. Task 9: Clinical safety medication status, Bangla digits, day-first dates, and discharge fallback', () {
      // Setup injectable clock at 2026-10-12
      GeminiAiService.clock = () => DateTime(2026, 10, 12);

      // Strict day-first parsing: 05/10/26 must be 5 Oct 2026, never 10 May
      final dateDmy = GeminiAiService.parseDateString('05/10/26');
      expect(dateDmy, equals(DateTime(2026, 10, 5)));

      // Bangla digits converted before parsing
      final dateBangla = GeminiAiService.parseDateString('০৫/১০/২৬');
      expect(dateBangla, equals(DateTime(2026, 10, 5)));

      // Bangla date (05 Oct 2026) + 3 days -> ends on 08 Oct 2026 < 12 Oct 2026 -> Course ended
      final statusParacetamolEnded = GeminiAiService.calculateMedicationStatus(
        '০৫/১০/২৬',
        '3 days',
      );
      expect(statusParacetamolEnded, equals('Course ended'));

      // Bangla date (05 Oct 2026) + 14 days -> ends on 19 Oct 2026 >= 12 Oct 2026 -> Active
      final statusActive = GeminiAiService.calculateMedicationStatus(
        '০৫/১০/২৬',
        '14 days',
      );
      expect(statusActive, equals('Active'));

      // Missing prescribed date -> Prescribed date not stated (never Active)
      final statusMissingDate = GeminiAiService.calculateMedicationStatus(
        null,
        '5 days',
      );
      expect(statusMissingDate, equals('Prescribed date not stated'));

      // Ongoing / as needed keywords
      expect(
        GeminiAiService.calculateMedicationStatus(null, 'শ্বাসকষ্ট হলে ২ পাফ'),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus('05/10/26', 'ব্যথা হলে'),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus('05/10/26', 'PRN'),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus('05/10/26', 'SOS'),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus(null, 'চলবে'),
        equals('Ongoing / as needed'),
      );
      expect(
        GeminiAiService.calculateMedicationStatus(null, 'প্রয়োজনে'),
        equals('Ongoing / as needed'),
      );

      // Discharge summary fallback: discharge date 16 Aug 2026, 5 days duration -> ended on 21 Aug 2026 < 12 Oct 2026
      final dischargeJson = {
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
          }
        ],
      };
      final dischargeData = ExtractedMedicalData.fromMap(dischargeJson);
      expect(dischargeData.currentMedications.length, equals(1));
      final med = dischargeData.currentMedications.first;
      expect(med.status, equals('Course ended'));
      expect(med.isDischargeFallback, isTrue);
      expect(med.prescribedDate, equals('16 Aug 2026'));
      expect(med.prescribedDisplay, equals('Prescribed (at discharge): 16 Aug 2026'));

      // Reset clock
      GeminiAiService.clock = () => DateTime.now();
    });

    test('11. Task 10: Condition normalizer exact whole-name deduplication and detail merger', () {
      // Whole-name matching, no substring dropping
      // ["হাঁপানি (২০১৫)", "Allergic Rhinitis", "Asthma (mild)"] must yield exactly two entries:
      // "Asthma (হাঁপানি) - mild, since 2015" and "Allergic Rhinitis"
      final raw1 = ['হাঁপানি (২০১৫)', 'Allergic Rhinitis', 'Asthma (mild)'];
      final result1 = GeminiAiService.normalizeAndDeduplicateConditions(raw1);
      expect(result1.length, equals(2));
      expect(result1[0], equals('Asthma (হাঁপানি) - mild, since 2015'));
      expect(result1[1], equals('Allergic Rhinitis'));

      // Unrelated conditions sharing words: "Allergy", "Allergic Rhinitis", "Food Allergy"
      // "Allergic Rhinitis" must not match "Allergy"
      final raw2 = ['Allergy', 'Allergic Rhinitis', 'Food Allergy'];
      final result2 = GeminiAiService.normalizeAndDeduplicateConditions(raw2);
      expect(result2, contains('Allergy (এলার্জি)'));
      expect(result2, contains('Allergic Rhinitis'));
      expect(result2, contains('Food Allergy'));
      expect(result2.length, equals(3));
    });

    test('12. Task 11: Structured follow_ups field parsing and display text', () {
      final jsonWithFollowUp = {
        'is_medical_document': true,
        'follow_ups': [
          {
            'date': '12 Nov 2026',
            'place': 'Outpatient Department',
            'purpose': 'CBC & Chest X-Ray review',
          }
        ],
        'doctor_advice': 'Take medications with food. Avoid cold drinks.',
      };

      final data = ExtractedMedicalData.fromMap(jsonWithFollowUp);
      expect(data.followUps.length, equals(1));
      final fu = data.followUps.first;
      expect(fu.date, equals('12 Nov 2026'));
      expect(fu.place, equals('Outpatient Department'));
      expect(fu.purpose, equals('CBC & Chest X-Ray review'));
      expect(fu.displayText, equals('12 Nov 2026 • Outpatient Department • CBC & Chest X-Ray review'));
      expect(data.doctorAdvice, equals('Take medications with food. Avoid cold drinks.'));

      // Empty follow_ups returns empty list
      final jsonEmpty = {
        'is_medical_document': true,
        'follow_ups': [],
      };
      final dataEmpty = ExtractedMedicalData.fromMap(jsonEmpty);
      expect(dataEmpty.followUps, isEmpty);
    });

    test('13. Task 12: Friendly API error mapper (429 retryDelay, 503, timeout, config, network)', () {
      // 429 with retryDelay in seconds (e.g. 54000s -> ~15 hours)
      const bodyWith54000s = '{"error": {"code": 429, "message": "Resource has been exhausted", "details": [{"retryDelay": "54000s"}]}}';
      final msg429Hours = GeminiAiService.mapHttpError(429, bodyWith54000s);
      expect(msg429Hours, equals('The AI service has reached its usage limit. Please try again in about 15 hours.'));

      // 429 with short retryDelay in minutes (e.g. 120s -> 2 minutes)
      const bodyWith120s = '{"error": {"code": 429, "details": [{"retryDelay": "120s"}]}}';
      final msg429Mins = GeminiAiService.mapHttpError(429, bodyWith120s);
      expect(msg429Mins, equals('The AI service has reached its usage limit. Please try again in about 2 minutes.'));

      // 429 without retryDelay
      const bodyNoDelay = '{"error": {"code": 429, "message": "Quota exceeded"}}';
      final msg429Default = GeminiAiService.mapHttpError(429, bodyNoDelay);
      expect(msg429Default, equals('The AI service has reached its usage limit. Please try again later.'));

      // 500 / 502 / 503 / 504
      expect(
        GeminiAiService.mapHttpError(500, ''),
        equals('The AI service is temporarily unavailable. Please try again.'),
      );
      expect(
        GeminiAiService.mapHttpError(503, ''),
        equals('The AI service is temporarily unavailable. Please try again.'),
      );

      // 400 / 401 / 403
      expect(
        GeminiAiService.mapHttpError(400, ''),
        equals('AI service configuration problem. Please contact support.'),
      );
      expect(
        GeminiAiService.mapHttpError(401, ''),
        equals('AI service configuration problem. Please contact support.'),
      );
      expect(
        GeminiAiService.mapHttpError(403, ''),
        equals('AI service configuration problem. Please contact support.'),
      );
      expect(
        GeminiAiService.mapHttpError(400, '{"error": {"code": 400, "message": "API key not valid"}}'),
        equals('AI service configuration problem (HTTP 400): API key not valid'),
      );

      // Exceptions via mapErrorToUserFriendlyMessage
      expect(
        GeminiAiService.mapErrorToUserFriendlyMessage(TimeoutException('Request timed out')),
        equals('The AI service is temporarily unavailable. Please try again.'),
      );
      expect(
        GeminiAiService.mapErrorToUserFriendlyMessage(const SocketException('Failed host lookup')),
        equals('No internet connection.'),
      );
      expect(
        GeminiAiService.mapErrorToUserFriendlyMessage(http.ClientException('Connection reset')),
        equals('No internet connection.'),
      );

      // GeminiApiException unwraps userMessage
      final customEx = GeminiApiException(userMessage: 'Custom safe message');
      expect(GeminiAiService.mapErrorToUserFriendlyMessage(customEx), equals('Custom safe message'));
    });

    test('14. Task 12: Client-side hourly analysis rate limiting (max 5/hour)', () {
      GeminiAiService.resetRateLimit();

      final baseTime = DateTime(2026, 10, 12, 10, 0, 0);

      // First 5 checks within the same hour succeed
      for (int i = 0; i < 5; i++) {
        expect(() => GeminiAiService.checkRateLimit(testTime: baseTime), returnsNormally);
      }

      // 6th check within the same hour throws GeminiApiException with status 429
      expect(
        () => GeminiAiService.checkRateLimit(testTime: baseTime),
        throwsA(
          isA<GeminiApiException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('Hourly analysis limit reached (max 5 per hour)'),
          ),
        ),
      );

      // 1 hour later, old timestamps are pruned and checks succeed again
      final oneHourLater = baseTime.add(const Duration(hours: 1, seconds: 1));
      expect(() => GeminiAiService.checkRateLimit(testTime: oneHourLater), returnsNormally);

      GeminiAiService.resetRateLimit();
    });

    group('15. Gemini Model Chain & Multi-Key Request Strategy (503, 429, 403, 404, all-fail)', () {
      const mockValidGeminiResponse = '''
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\\"is_medical_document\\": true, \\"document_type\\": \\"prescription\\", \\"classification_reason\\": \\"Prescription\\", \\"blood_group\\": null, \\"blood_group_source\\": \\"not_found\\", \\"blood_group_evidence\\": null, \\"drug_allergies\\": [], \\"food_allergies\\": [], \\"environmental_allergies\\": [], \\"chronic_conditions\\": [], \\"current_medications\\": [], \\"abnormal_labs\\": [], \\"past_visits\\": [], \\"doctor_advice\\": null}"
          }
        ]
      }
    }
  ]
}
''';

      final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);

      setUp(() {
        GeminiAiService.sleeper = (_) async {};
        GeminiAiService.geminiApiKeys = [
          'test_mock_api_key_1',
          'test_mock_api_key_2',
          'test_mock_api_key_3',
        ];
        GeminiAiService.resetSessionState();
      });

      tearDown(() {
        GeminiAiService.sleeper = Future.delayed;
        GeminiAiService.geminiApiKeys = [];
        GeminiAiService.resetSessionState();
      });

      // 15.1: 503 then success -> retries the same key and succeeds
      test('15.1: 503 server error retries the same key up to 2 times and succeeds on recovery', () async {
        final recordedCalls = <Map<String, String>>[];

        final client503 = _TestHttpClient((request) async {
          final key = request.url.queryParameters['key'] ?? '';
          final path = request.url.path;
          recordedCalls.add({'key': key, 'path': path});

          if (recordedCalls.length == 1) {
            return http.Response('Service Unavailable', 503);
          }
          return http.Response(mockValidGeminiResponse, 200);
        });

        final service = GeminiAiService(httpClient: client503);
        final result = await service.extractMedicalJson(
          fileName: 'prescription.pdf',
          fileSizeBytes: 1024,
          fileBytes: sampleBytes,
        );

        expect(result['is_medical_document'], isTrue);
        expect(recordedCalls.length, equals(2));
        // Both calls should be on the SAME key and primary model gemini-3.5-flash
        expect(recordedCalls[0]['key'], equals(GeminiAiService.geminiApiKeys[0]));
        expect(recordedCalls[1]['key'], equals(GeminiAiService.geminiApiKeys[0]));
        expect(recordedCalls[0]['path'], contains('gemini-3.5-flash'));
        expect(recordedCalls[1]['path'], contains('gemini-3.5-flash'));
      });

      // 15.2: 429 rotation -> marks key+model on cooldown, moves to next key
      test('15.2: 429 quota exhaustion marks key+model on cooldown and rotates to next key', () async {
        final recordedKeys = <String>[];

        final client429 = _TestHttpClient((request) async {
          final key = request.url.queryParameters['key'] ?? '';
          recordedKeys.add(key);

          if (recordedKeys.length == 1) {
            return http.Response('{"error": {"code": 429, "message": "Resource Exhausted"}}', 429);
          }
          return http.Response(mockValidGeminiResponse, 200);
        });

        final service = GeminiAiService(httpClient: client429);
        final result = await service.extractMedicalJson(
          fileName: 'prescription.pdf',
          fileSizeBytes: 1024,
          fileBytes: sampleBytes,
        );

        expect(result['is_medical_document'], isTrue);
        expect(recordedKeys.length, equals(2));
        expect(recordedKeys[0], equals(GeminiAiService.geminiApiKeys[0]));
        expect(recordedKeys[1], equals(GeminiAiService.geminiApiKeys[1]));
        expect(GeminiAiService.currentKeyIndex, equals(1)); // Points to working key
      });

      // 15.3: 403 dead key -> marks key as dead for session, moves on, and future calls skip it
      test('15.3: 403 Permission Denied marks key as dead for this session and moves to next key', () async {
        final key0 = GeminiAiService.geminiApiKeys[0];
        final key1 = GeminiAiService.geminiApiKeys[1];
        final recordedKeys = <String>[];

        final client403 = _TestHttpClient((request) async {
          final key = request.url.queryParameters['key'] ?? '';
          recordedKeys.add(key);

          if (key == key0) {
            return http.Response('{"error": {"code": 403, "message": "Permission denied", "status": "PERMISSION_DENIED"}}', 403);
          }
          return http.Response(mockValidGeminiResponse, 200);
        });

        final service = GeminiAiService(httpClient: client403);
        final result = await service.extractMedicalJson(
          fileName: 'prescription.pdf',
          fileSizeBytes: 1024,
          fileBytes: sampleBytes,
        );

        expect(result['is_medical_document'], isTrue);
        expect(recordedKeys, contains(key0));
        expect(recordedKeys, contains(key1));
        expect(GeminiAiService.isKeyDead(key0), isTrue);
        expect(GeminiAiService.isKeyDead(key1), isFalse);

        // A subsequent call should skip dead key0 entirely
        final nextCallKeys = <String>[];
        final clientNext = _TestHttpClient((request) async {
          final key = request.url.queryParameters['key'] ?? '';
          nextCallKeys.add(key);
          return http.Response(mockValidGeminiResponse, 200);
        });

        final serviceNext = GeminiAiService(httpClient: clientNext);
        await serviceNext.extractMedicalJson(
          fileName: 'prescription.pdf',
          fileSizeBytes: 1024,
          fileBytes: sampleBytes,
        );

        expect(nextCallKeys, isNot(contains(key0)));
        expect(nextCallKeys, contains(key1));
      });

      // 15.4: 404 model skip -> marks model as unavailable, never retries it, moves to next model
      test('15.4: 404 Not Found marks model as unavailable, skips remaining keys for it, and advances to next model', () async {
        final recordedModels = <String>[];

        final client404 = _TestHttpClient((request) async {
          final path = request.url.path;
          if (path.contains('gemini-3.5-flash')) {
            recordedModels.add('gemini-3.5-flash');
            return http.Response('{"error": {"code": 404, "message": "Model not found"}}', 404);
          } else if (path.contains('gemini-3.1-flash-lite')) {
            recordedModels.add('gemini-3.1-flash-lite');
            return http.Response(mockValidGeminiResponse, 200);
          }
          return http.Response(mockValidGeminiResponse, 200);
        });

        final service = GeminiAiService(httpClient: client404);
        final result = await service.extractMedicalJson(
          fileName: 'prescription.pdf',
          fileSizeBytes: 1024,
          fileBytes: sampleBytes,
        );

        expect(result['is_medical_document'], isTrue);
        expect(recordedModels, contains('gemini-3.5-flash'));
        expect(recordedModels, contains('gemini-3.1-flash-lite'));
        expect(GeminiAiService.isModelUnavailable('gemini-3.5-flash'), isTrue);
        expect(GeminiAiService.isModelUnavailable('gemini-3.1-flash-lite'), isFalse);

        // Subsequent call must NEVER retry gemini-3.5-flash
        final subsequentModels = <String>[];
        final clientSubsequent = _TestHttpClient((request) async {
          final path = request.url.path;
          if (path.contains('gemini-3.5-flash')) {
            subsequentModels.add('gemini-3.5-flash');
          } else if (path.contains('gemini-3.1-flash-lite')) {
            subsequentModels.add('gemini-3.1-flash-lite');
          }
          return http.Response(mockValidGeminiResponse, 200);
        });

        final serviceSubsequent = GeminiAiService(httpClient: clientSubsequent);
        await serviceSubsequent.extractMedicalJson(
          fileName: 'prescription.pdf',
          fileSizeBytes: 1024,
          fileBytes: sampleBytes,
        );

        expect(subsequentModels, isNot(contains('gemini-3.5-flash')));
        expect(subsequentModels, contains('gemini-3.1-flash-lite'));
      });

      // 15.5: all-fail friendly message -> shows friendly manual form message
      test('15.5: When all models and keys fail, throws friendly manual fallback message', () async {
        final clientAllFail = _TestHttpClient((request) async {
          return http.Response('Service Unavailable', 503);
        });

        final service = GeminiAiService(httpClient: clientAllFail);
        await expectLater(
          () => service.extractMedicalJson(
            fileName: 'prescription.pdf',
            fileSizeBytes: 1024,
            fileBytes: sampleBytes,
          ),
          throwsA(
            isA<GeminiApiException>().having(
              (e) => e.userMessage,
              'userMessage',
              equals('AI service is temporarily unavailable. You can continue by filling the form manually.'),
            ),
          ),
        );
      });
    });
  });
}

class _TestHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  _TestHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
