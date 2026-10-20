import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiApiException implements Exception {
  final int? statusCode;
  final String userMessage;
  final String? technicalDetails;

  GeminiApiException({
    this.statusCode,
    required this.userMessage,
    this.technicalDetails,
  });

  @override
  String toString() => userMessage;
}

class FollowUpItem {
  final String? date;
  final String? place;
  final String? purpose;

  const FollowUpItem({
    this.date,
    this.place,
    this.purpose,
  });

  factory FollowUpItem.fromMap(Map<String, dynamic> map) {
    return FollowUpItem(
      date: map['date']?.toString(),
      place: map['place']?.toString(),
      purpose: map['purpose']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (date != null) 'date': date,
    if (place != null) 'place': place,
    if (purpose != null) 'purpose': purpose,
  };

  String get displayText {
    final parts = <String>[];
    if (date != null && date!.trim().isNotEmpty) parts.add(date!.trim());
    if (place != null && place!.trim().isNotEmpty) parts.add(place!.trim());
    if (purpose != null && purpose!.trim().isNotEmpty) parts.add(purpose!.trim());
    return parts.join(' • ');
  }
}

class MedicationItem {
  final String name;
  final String dose;
  final String frequency;
  final String? prescribedDate;
  final String? durationText;
  final String status;
  final bool isDischargeFallback;

  const MedicationItem({
    required this.name,
    required this.dose,
    required this.frequency,
    this.prescribedDate,
    this.durationText,
    this.status = 'Prescribed date not stated',
    this.isDischargeFallback = false,
  });

  factory MedicationItem.fromMap(
    Map<String, dynamic> map, {
    DateTime? referenceDate,
    String? dischargeDateFallback,
    bool isDischargeSummary = false,
  }) {
    final rawPrescribed = map['prescribed_date']?.toString();
    final durationText = map['duration_text']?.toString();
    final frequency = map['frequency']?.toString();
    final dose = map['dose']?.toString();

    final bool useDischarge = (rawPrescribed == null ||
            rawPrescribed.trim().isEmpty ||
            GeminiAiService.parseDateString(rawPrescribed) == null) &&
        dischargeDateFallback != null &&
        dischargeDateFallback.trim().isNotEmpty &&
        isDischargeSummary;

    final effectiveDate = useDischarge ? dischargeDateFallback : rawPrescribed;

    final status = GeminiAiService.calculateMedicationStatus(
      effectiveDate,
      durationText,
      frequency: frequency,
      dose: dose,
      dischargeDateFallback: dischargeDateFallback,
      isDischargeSummary: isDischargeSummary,
      referenceDate: referenceDate,
    );

    return MedicationItem(
      name: map['name']?.toString() ?? '',
      dose: dose ?? '',
      frequency: frequency ?? '',
      prescribedDate: effectiveDate,
      durationText: durationText,
      status: status,
      isDischargeFallback: useDischarge,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'dose': dose,
    'frequency': frequency,
    if (prescribedDate != null) 'prescribed_date': prescribedDate,
    if (durationText != null) 'duration_text': durationText,
    'status': status,
    'is_discharge_fallback': isDischargeFallback,
  };

  String? get prescribedDisplay {
    if (prescribedDate == null || prescribedDate!.trim().isEmpty) return null;
    if (isDischargeFallback) {
      return 'Prescribed (at discharge): $prescribedDate';
    }
    return 'Prescribed: $prescribedDate';
  }
}

class ProcedureItem {
  final String name;
  final String? date;

  const ProcedureItem({
    required this.name,
    this.date,
  });

  factory ProcedureItem.fromMap(Map<String, dynamic> map) {
    return ProcedureItem(
      name: map['name']?.toString() ?? '',
      date: map['date']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (date != null) 'date': date,
  };
}

class DiagnosisItem {
  final String name;
  final String? date;

  const DiagnosisItem({
    required this.name,
    this.date,
  });

  factory DiagnosisItem.fromMap(Map<String, dynamic> map) {
    return DiagnosisItem(
      name: map['name']?.toString() ?? '',
      date: map['date']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (date != null) 'date': date,
  };
}

class HospitalAdmissionItem {
  final String? admitDate;
  final String? dischargeDate;
  final String? reason;

  const HospitalAdmissionItem({
    this.admitDate,
    this.dischargeDate,
    this.reason,
  });

  factory HospitalAdmissionItem.fromMap(Map<String, dynamic> map) {
    return HospitalAdmissionItem(
      admitDate: map['admit_date']?.toString(),
      dischargeDate: map['discharge_date']?.toString(),
      reason: map['reason']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (admitDate != null) 'admit_date': admitDate,
    if (dischargeDate != null) 'discharge_date': dischargeDate,
    if (reason != null) 'reason': reason,
  };
}

class AllergyItem {
  final String substance;
  final String? reaction;

  const AllergyItem({
    required this.substance,
    this.reaction,
  });

  factory AllergyItem.fromDynamic(dynamic item) {
    if (item == null) return const AllergyItem(substance: '');
    if (item is Map) {
      final substance = (item['substance'] ?? item['name'] ?? item['allergen'])?.toString().trim() ?? '';
      final reaction = item['reaction']?.toString().trim();
      return AllergyItem(
        substance: substance,
        reaction: (reaction != null && reaction.isNotEmpty && reaction.toLowerCase() != 'null')
            ? reaction
            : null,
      );
    }
    final text = item.toString().trim();
    if (text.contains(' - ')) {
      final idx = text.indexOf(' - ');
      final sub = text.substring(0, idx).trim();
      final rx = text.substring(idx + 3).trim();
      return AllergyItem(
        substance: sub,
        reaction: rx.isNotEmpty ? rx : null,
      );
    }
    return AllergyItem(substance: text);
  }

  String get displayText {
    if (reaction != null && reaction!.isNotEmpty) {
      return '$substance - $reaction';
    }
    return substance;
  }

  Map<String, dynamic> toMap() => {
    'substance': substance,
    if (reaction != null) 'reaction': reaction,
  };
}

class PastVisitItem {
  final String date;
  final String diagnosis;

  const PastVisitItem({
    required this.date,
    required this.diagnosis,
  });

  factory PastVisitItem.fromMap(Map<String, dynamic> map) {
    return PastVisitItem(
      date: map['date']?.toString() ?? '',
      diagnosis: map['diagnosis']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date,
    'diagnosis': diagnosis,
  };
}

class ExtractedMedicalData {
  final bool isMedicalDocument;
  final String documentType; // prescription | lab_report | discharge_summary | clinical_record | other_non_medical | unreadable
  final String classificationReason;
  final String? bloodGroup;
  final String bloodGroupSource; // lab_report | clinical_record | other_document | not_found
  final String? bloodGroupEvidence;
  final bool bloodGroupVerified; // Always false for AI-extracted values
  final List<AllergyItem> drugAllergyItems;
  final List<AllergyItem> foodAllergyItems;
  final List<AllergyItem> environmentalAllergyItems;
  final List<String> chronicConditions;
  final List<MedicationItem> currentMedications;
  final List<String> abnormalLabs;
  final List<PastVisitItem> pastVisits;
  final List<ProcedureItem> procedures;
  final List<DiagnosisItem> diagnoses;
  final List<HospitalAdmissionItem> hospitalAdmissions;
  final List<FollowUpItem> followUps;
  final String? doctorAdvice;
  final String? patientName;
  final Map<String, dynamic> rawJson;

  ExtractedMedicalData({
    required this.isMedicalDocument,
    required this.documentType,
    required this.classificationReason,
    this.patientName,
    required this.bloodGroup,
    required this.bloodGroupSource,
    this.bloodGroupEvidence,
    this.bloodGroupVerified = false,
    List<AllergyItem>? drugAllergyItems,
    List<AllergyItem>? foodAllergyItems,
    List<AllergyItem>? environmentalAllergyItems,
    List<String>? drugAllergies,
    List<String>? foodAllergies,
    List<String>? environmentalAllergies,
    required this.chronicConditions,
    required this.currentMedications,
    required this.abnormalLabs,
    required this.pastVisits,
    this.procedures = const [],
    this.diagnoses = const [],
    this.hospitalAdmissions = const [],
    this.followUps = const [],
    this.doctorAdvice,
    required this.rawJson,
  })  : drugAllergyItems = drugAllergyItems ??
            (drugAllergies?.map((e) => AllergyItem.fromDynamic(e)).toList() ?? const []),
        foodAllergyItems = foodAllergyItems ??
            (foodAllergies?.map((e) => AllergyItem.fromDynamic(e)).toList() ?? const []),
        environmentalAllergyItems = environmentalAllergyItems ??
            (environmentalAllergyItems?.map((e) => AllergyItem.fromDynamic(e)).toList() ?? const []);

  /// Normalizes blood group strings (e.g. "B positive", "O ve", "বি পজিটিভ")
  /// to standard 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'.
  /// Returns null if missing, invalid, or ambiguous (e.g. Rh missing).
  static String? normalizeBloodGroup(dynamic raw) {
    if (raw == null) return null;
    final String text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final upper = text.toUpperCase();
    const standard = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'};
    if (standard.contains(upper)) {
      return upper;
    }

    final clean = text.replaceAll(RegExp(r'[\(\)]'), ' ').trim();

    final RegExp bgRegex = RegExp(
      r'^(AB|A|B|O|এবি|এ|বি|ও)\s*([+\-]|(\+?\s*ve)|(-\s*ve)|positive|negative|pos|neg|পজিটিভ|নেগেটিভ)$',
      caseSensitive: false,
    );

    final match = bgRegex.firstMatch(clean);
    if (match == null) {
      return null;
    }

    final groupRaw = match.group(1)!.toUpperCase();
    final rhRaw = (match.group(2) ?? '').toLowerCase();

    String group;
    if (groupRaw == 'AB' || groupRaw == 'এবি') {
      group = 'AB';
    } else if (groupRaw == 'A' || groupRaw == 'এ') {
      group = 'A';
    } else if (groupRaw == 'B' || groupRaw == 'বি') {
      group = 'B';
    } else if (groupRaw == 'O' || groupRaw == 'ও') {
      group = 'O';
    } else {
      return null;
    }

    final bool isNegative = rhRaw.contains('-') ||
        rhRaw.contains('neg') ||
        rhRaw.contains('নেগেটিভ');

    return '$group${isNegative ? '-' : '+'}';
  }

  factory ExtractedMedicalData.fromMap(Map<String, dynamic> map, {DateTime? referenceDate}) {
    final dynamic rawIsMedical = map['is_medical_document'];
    // Defensive parsing: missing or non-boolean is treated as NOT medical (fail-safe)
    final bool isMedical = (rawIsMedical is bool) ? rawIsMedical : false;

    final String docType = (map['document_type'] as String?)?.toLowerCase().trim() ??
        (isMedical ? 'clinical_record' : 'other_non_medical');
    final bool isDischargeSummary = docType == 'discharge_summary';
    final String rawReason = (map['classification_reason'] as String?)?.trim() ??
        (isMedical
            ? 'Clinical medical record'
            : (rawIsMedical == null
                ? 'Document verification failed: missing medical classification'
                : 'Document identified as non-medical or unreadable'));
    final String sanitizedReason = GeminiAiService.sanitizeClassificationReason(rawReason);

    // When is_medical_document is false, return every other clinical field empty/null. Do not extract anything.
    if (!isMedical) {
      return ExtractedMedicalData(
        isMedicalDocument: false,
        documentType: docType,
        classificationReason: sanitizedReason,
        bloodGroup: null,
        bloodGroupSource: 'not_found',
        bloodGroupEvidence: null,
        bloodGroupVerified: false,
        drugAllergyItems: const [],
        foodAllergyItems: const [],
        environmentalAllergyItems: const [],
        chronicConditions: const [],
        currentMedications: const [],
        abnormalLabs: const [],
        pastVisits: const [],
        procedures: const [],
        diagnoses: const [],
        hospitalAdmissions: const [],
        followUps: const [],
        doctorAdvice: null,
        patientName: null,
        rawJson: map,
      );
    }

    // Normalized blood group
    final String? normalizedBlood = normalizeBloodGroup(map['blood_group']);

    // blood_group_source rules:
    // lab_report ONLY if the document is a blood grouping or lab test report.
    // clinical_record for a prescription or clinical record.
    // other_document for any other file.
    // not_found if no blood group.
    String bgSource;
    if (normalizedBlood == null) {
      bgSource = 'not_found';
    } else {
      final rawSource = (map['blood_group_source'] as String?)?.toLowerCase().trim();
      if (rawSource == 'lab_report' && docType == 'lab_report') {
        bgSource = 'lab_report';
      } else if (rawSource == 'clinical_record') {
        bgSource = 'clinical_record';
      } else if (rawSource == 'other_document') {
        bgSource = 'other_document';
      } else {
        bgSource = (docType == 'lab_report') ? 'lab_report' : 'clinical_record';
      }
    }

    final String? bloodEvidence = map['blood_group_evidence'] as String?;

    final rawConditions = (map['chronic_conditions'] as List<dynamic>?) ?? [];
    final normalizedConditions = GeminiAiService.normalizeAndDeduplicateConditions(rawConditions);

    final procedures = (map['procedures'] as List<dynamic>?)
            ?.map((e) => ProcedureItem.fromMap(
                Map<String, dynamic>.from(e is Map ? e : {'name': e.toString()})))
            .toList() ??
        [];

    final diagnoses = (map['diagnoses'] as List<dynamic>?)
            ?.map((e) => DiagnosisItem.fromMap(
                Map<String, dynamic>.from(e is Map ? e : {'name': e.toString()})))
            .toList() ??
        [];

    final hospitalAdmissions = (map['hospital_admissions'] as List<dynamic>?)
            ?.map((e) => HospitalAdmissionItem.fromMap(
                Map<String, dynamic>.from(e is Map ? e : {})))
            .toList() ??
        [];

    // If discharge summary, extract discharge date fallback from admissions
    String? dischargeDateFallback;
    if (isDischargeSummary && hospitalAdmissions.isNotEmpty) {
      for (final adm in hospitalAdmissions) {
        if (adm.dischargeDate != null && adm.dischargeDate!.trim().isNotEmpty) {
          dischargeDateFallback = adm.dischargeDate!.trim();
          break;
        }
      }
    }

    final currentMeds = (map['current_medications'] as List<dynamic>?)
            ?.map((e) => MedicationItem.fromMap(
                  Map<String, dynamic>.from(e is Map ? e : {}),
                  referenceDate: referenceDate,
                  dischargeDateFallback: dischargeDateFallback,
                  isDischargeSummary: isDischargeSummary,
                ))
            .toList() ??
        [];

    final followUps = (map['follow_ups'] as List<dynamic>?)
            ?.map((e) => FollowUpItem.fromMap(
                Map<String, dynamic>.from(e is Map ? e : {})))
            .toList() ??
        [];

    return ExtractedMedicalData(
      isMedicalDocument: true,
      documentType: docType,
      classificationReason: sanitizedReason,
      bloodGroup: normalizedBlood,
      bloodGroupSource: bgSource,
      bloodGroupEvidence: bloodEvidence,
      bloodGroupVerified: false,
      drugAllergyItems: (map['drug_allergies'] as List<dynamic>?)
              ?.map((e) => AllergyItem.fromDynamic(e))
              .toList() ??
          [],
      foodAllergyItems: (map['food_allergies'] as List<dynamic>?)
              ?.map((e) => AllergyItem.fromDynamic(e))
              .toList() ??
          [],
      environmentalAllergyItems: (map['environmental_allergies'] as List<dynamic>?)
              ?.map((e) => AllergyItem.fromDynamic(e))
              .toList() ??
          [],
      chronicConditions: normalizedConditions,
      currentMedications: currentMeds,
      abnormalLabs: (map['abnormal_labs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      pastVisits: (map['past_visits'] as List<dynamic>?)
              ?.map((e) => PastVisitItem.fromMap(
                  Map<String, dynamic>.from(e is Map ? e : {})))
              .toList() ??
          [],
      procedures: procedures,
      diagnoses: diagnoses,
      hospitalAdmissions: hospitalAdmissions,
      followUps: followUps,
      doctorAdvice: map['doctor_advice'] as String?,
      patientName: (map['patient_name'] as String?)?.trim().isNotEmpty == true
          ? (map['patient_name'] as String).trim()
          : null,
      rawJson: map,
    );
  }

  /// True when a valid medical document contains zero clinical details
  bool get hasNoClinicalDetails =>
      (bloodGroup == null || bloodGroup!.isEmpty) &&
      drugAllergyItems.isEmpty &&
      foodAllergyItems.isEmpty &&
      environmentalAllergyItems.isEmpty &&
      chronicConditions.isEmpty &&
      currentMedications.isEmpty &&
      abnormalLabs.isEmpty &&
      pastVisits.isEmpty &&
      procedures.isEmpty &&
      diagnoses.isEmpty &&
      hospitalAdmissions.isEmpty &&
      followUps.isEmpty;

  Map<String, dynamic> toMap() => {
        ...rawJson,
        'is_medical_document': isMedicalDocument,
        'document_type': documentType,
        'classification_reason': classificationReason,
        'blood_group': bloodGroup,
        'blood_group_source': bloodGroupSource,
        'blood_group_evidence': bloodGroupEvidence,
        'blood_group_verified': false,
        'drug_allergies': drugAllergyItems.map((e) => e.toMap()).toList(),
        'food_allergies': foodAllergyItems.map((e) => e.toMap()).toList(),
        'environmental_allergies': environmentalAllergyItems.map((e) => e.toMap()).toList(),
        'chronic_conditions': chronicConditions,
        'procedures': procedures.map((e) => e.toMap()).toList(),
        'diagnoses': diagnoses.map((e) => e.toMap()).toList(),
        'hospital_admissions': hospitalAdmissions.map((e) => e.toMap()).toList(),
        'follow_ups': followUps.map((e) => e.toMap()).toList(),
        if (patientName != null) 'patient_name': patientName,
      };

  // Backward compatibility getters for auth_controller, tests & UI
  List<String> get drugAllergies =>
      drugAllergyItems.map((a) => a.displayText).toList();

  List<String> get foodAllergies =>
      foodAllergyItems.map((a) => a.displayText).toList();

  List<String> get environmentalAllergies =>
      environmentalAllergyItems.map((a) => a.displayText).toList();

  List<String> get knownAllergies => [
        ...drugAllergyItems.map((a) => 'Drug: ${a.displayText}'),
        ...foodAllergyItems.map((a) => 'Food: ${a.displayText}'),
        ...environmentalAllergyItems.map((a) => 'Environmental: ${a.displayText}'),
      ];

  List<String> get historicalProblems => [
        ...chronicConditions,
        ...procedures.map((p) => p.date != null ? '${p.name} (${p.date})' : p.name),
        ...hospitalAdmissions.map((a) =>
            'Admission: ${a.reason ?? "Hospital stay"}${a.admitDate != null ? " on ${a.admitDate}" : ""}'),
      ];

  List<String> get activeIssues => currentMedications
      .map((m) =>
          '${m.name}${m.dose.isNotEmpty ? " ${m.dose}" : ""}${m.frequency.isNotEmpty ? " (${m.frequency})" : ""}')
      .toList();

  double get confidenceScore => 1.0;

  String get clinicalSummary =>
      'Document Data: ${chronicConditions.isNotEmpty ? chronicConditions.join(", ") : "Not found - confirm with patient"}. '
      'Medications: ${currentMedications.isNotEmpty ? currentMedications.map((m) => m.name).join(", ") : "Not found - confirm with patient"}. '
      'Drug Allergies: ${drugAllergies.isNotEmpty ? drugAllergies.join(", ") : "Not found - confirm with patient"}.';

  // Strict clinical rule: AI never decides blood donation eligibility
  bool? get isEligibleForBloodDonation => null;
  String get bloodDonationIneligibilityReason =>
      'Pending Clinical Screening (Requires Manual Staff Review)';
}

/// Gemini API Keys for multimodal medical document parsing with fallback rotation
List<String> get geminiApiKeys => GeminiAiService.geminiApiKeys;

/// Backwards compatibility getter
String get geminiApiKey =>
    GeminiAiService.geminiApiKeys.isNotEmpty
        ? GeminiAiService.geminiApiKeys[GeminiAiService.currentKeyIndex]
        : '';

class GeminiAiService {
  final http.Client? httpClient;

  GeminiAiService({this.httpClient});

  /// Default fallback API keys loaded from environment variables using flutter_dotenv
  static List<String> get _defaultFallbackKeys {
    try {
      if (!dotenv.isInitialized) {
        return const [];
      }
      return [
        dotenv.env['GEMINI_API_KEY_1'] ?? '',
        dotenv.env['GEMINI_API_KEY_2'] ?? '',
        dotenv.env['GEMINI_API_KEY_3'] ?? '',
      ].where((k) => k.trim().isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  static List<String>? _customApiKeys;

  /// Resolves active Gemini API keys from .env, compile-time flags, or fallback constants
  static List<String> get geminiApiKeys {
    if (_customApiKeys != null && _customApiKeys!.isNotEmpty) {
      return _customApiKeys!;
    }

    final envKeys = _resolveKeysFromEnvironment();
    if (envKeys.isNotEmpty) {
      return envKeys;
    }

    debugPrint('[GeminiAiService] No custom or environment keys found; falling back to ${_defaultFallbackKeys.length} bootstrap fallback keys.');
    for (int i = 0; i < _defaultFallbackKeys.length; i++) {
      debugPrint('[GeminiAiService] Bootstrap fallback key #${i + 1} registered.');
    }

    return _defaultFallbackKeys;
  }

  static set geminiApiKeys(List<String> keys) {
    _customApiKeys = List.from(keys);
  }

  static List<String> _resolveKeysFromEnvironment() {
    final List<String> keys = [];

    // 1. Try reading from flutter_dotenv (.env file in root directory)
    try {
      if (dotenv.isInitialized) {
        // Read GEMINI_API_KEY_1, GEMINI_API_KEY_2, GEMINI_API_KEY_3 in order
        for (int i = 1; i <= 5; i++) {
          final indexedKey = dotenv.maybeGet('GEMINI_API_KEY_$i') ?? dotenv.env['GEMINI_API_KEY_$i'];
          if (indexedKey != null && indexedKey.trim().isNotEmpty && !keys.contains(indexedKey.trim())) {
            keys.add(indexedKey.trim());
          }
        }

        final singleKey = dotenv.maybeGet('GEMINI_API_KEY') ?? dotenv.env['GEMINI_API_KEY'];
        if (singleKey != null && singleKey.trim().isNotEmpty && !keys.contains(singleKey.trim())) {
          keys.add(singleKey.trim());
        }

        final multiKey = dotenv.maybeGet('GEMINI_API_KEYS') ?? dotenv.env['GEMINI_API_KEYS'];
        if (multiKey != null && multiKey.trim().isNotEmpty) {
          for (final k in multiKey.split(',')) {
            final trimmed = k.trim();
            if (trimmed.isNotEmpty && !keys.contains(trimmed)) {
              keys.add(trimmed);
            }
          }
        }
      } else {
        debugPrint('[GeminiAiService] dotenv is NOT initialized yet.');
      }
    } catch (e) {
      debugPrint('[GeminiAiService] Exception reading dotenv: $e');
    }

    // 2. Try compile-time environment variable (--dart-define=GEMINI_API_KEY=...)
    const dartDefineKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (dartDefineKey.isNotEmpty && !keys.contains(dartDefineKey.trim())) {
      keys.add(dartDefineKey.trim());
    }

    debugPrint('[GeminiAiService] _resolveKeysFromEnvironment: Resolved ${keys.length} key(s) from .env / compile environment.');
    for (int i = 0; i < keys.length; i++) {
      debugPrint('[GeminiAiService] Loaded key #${i + 1} registered.');
    }

    return keys;
  }

  /// Current active API key index for rotation
  static int _currentKeyIndex = 0;

  /// Gets the current active key index
  static int get currentKeyIndex => _currentKeyIndex;

  /// Sets the current active key index
  static set currentKeyIndex(int index) {
    if (geminiApiKeys.isEmpty) {
      _currentKeyIndex = 0;
    } else {
      _currentKeyIndex = index % geminiApiKeys.length;
    }
  }

  /// Ordered model fallback chain (easy to edit in one place)
  static const List<String> modelChain = [
    'gemini-3.5-flash',          // primary
    'gemini-3.1-flash-lite',     // fallback 1
    'gemini-flash-lite-latest',  // fallback 2
    'gemini-flash-latest',       // fallback 3
  ];

  /// Backward-compatibility getter for primary model
  static String get modelName => modelChain.first;

  /// Friendly error message when all models and keys fail
  static const String allFailFriendlyMessage =
      'AI service is temporarily unavailable. You can continue by filling the form manually.';

  /// Session state: keys marked dead for the current session (on 400, 401, 403)
  static final Set<String> _deadKeys = {};

  /// Session state: models marked unavailable for the current session (on 404)
  static final Set<String> _unavailableModels = {};

  /// Session state: key+model cooldown timestamps (on 429)
  static final Map<String, DateTime> _keyModelCooldowns = {};

  /// Injectable delay function to allow instantaneous tests
  static Future<void> Function(Duration duration) sleeper = Future.delayed;

  /// Clear session state (dead keys, unavailable models, cooldowns, key index, rate limits)
  static void resetSessionState() {
    _deadKeys.clear();
    _unavailableModels.clear();
    _keyModelCooldowns.clear();
    _currentKeyIndex = 0;
    resetRateLimit();
  }

  /// Resets key index and session state
  static void resetKeyIndex() {
    resetSessionState();
  }

  /// Helper inspection methods for tests
  static Set<String> get deadKeys => Set.unmodifiable(_deadKeys);
  static Set<String> get unavailableModels => Set.unmodifiable(_unavailableModels);
  static bool isKeyDead(String key) => _deadKeys.contains(key);
  static bool isModelUnavailable(String model) => _unavailableModels.contains(model);

  /// Backwards compatibility getter for single key
  static String get geminiApiKey =>
      geminiApiKeys.isNotEmpty ? geminiApiKeys[_currentKeyIndex] : '';

  /// Injectable clock function for deterministic date/time tests
  static DateTime Function() clock = () => DateTime.now();

  // Temporary client-side rate limit: max 5 analyses per user per hour.
  // Note: Real rate limiting and abuse prevention will be enforced server-side later with Firebase AI Logic and App Check.
  static final List<DateTime> _analysisTimestamps = [];

  /// Enforces client-side rate limit (max 5 analyses per hour)
  static void checkRateLimit({DateTime? testTime}) {
    final now = testTime ?? DateTime.now();
    _analysisTimestamps.removeWhere((t) => now.difference(t).inHours >= 1);
    if (_analysisTimestamps.length >= 5) {
      throw GeminiApiException(
        statusCode: 429,
        userMessage: 'Hourly analysis limit reached (max 5 per hour). Please try again later.',
      );
    }
    _analysisTimestamps.add(now);
  }

  /// Clears analysis timestamps (useful in unit tests)
  static void resetRateLimit() {
    _analysisTimestamps.clear();
  }

  /// Converts Bengali numerals (০-৯) to standard Arabic digits (0-9)
  static String convertBanglaDigits(String input) {
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(bangla[i], i.toString());
    }
    return result;
  }

  /// Sanitizes classification reasons by redacting private names, emails, and phone numbers
  static String sanitizeClassificationReason(String reason) {
    if (reason.isEmpty) return reason;
    String clean = reason.trim();

    // Redact email addresses
    clean = clean.replaceAll(
      RegExp(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+'),
      '[redacted email]',
    );

    // Redact phone numbers
    clean = clean.replaceAll(
      RegExp(r'(\+?\d{1,4}[\s-]?)?\(?\d{2,4}\)?[\s-]?\d{3,4}[\s-]?\d{3,4}'),
      '[redacted phone]',
    );

    // Redact names following common prefixes: "belonging to <Name>", "named <Name>", "candidate <Name>"
    clean = clean.replaceAll(
      RegExp(
        r'\b(belonging to|named|candidate|student|patient|person)\s+([A-Z][a-zA-Z]+(\s+[A-Z][a-zA-Z]+)*)',
        caseSensitive: false,
      ),
      r'$1 [redacted name]',
    );
    clean = clean.replaceAll(
      RegExp(
        r'\b(of|for)\s+([A-Z][a-z]+(\s+[A-Z][a-z]+)+)',
        caseSensitive: false,
      ),
      r'$1 [redacted name]',
    );

    return clean;
  }

  /// Parses date string into DateTime with strict day-first convention (e.g. "05/10/26" -> 5 Oct 2026, never 10 May).
  /// Supports Bengali digits, day-first numeric formats (dd/MM/yy, dd/MM/yyyy, dd-MM-yyyy, dd.MM.yyyy),
  /// and textual dates ("05 Oct 2026", "5th October 2026").
  static DateTime? parseDateString(String text) {
    var clean = convertBanglaDigits(text.trim());
    if (clean.isEmpty) return null;

    // Strip ordinal suffixes: 1st, 2nd, 3rd, 4th, 5th, etc.
    clean = clean.replaceAll(RegExp(r'(\d+)(st|nd|rd|th)\b', caseSensitive: false), r'$1');

    // Day-first numeric format: dd/MM/yy or dd/MM/yyyy, dd-MM-yyyy, dd.MM.yyyy
    final dmyMatch = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})$').firstMatch(clean);
    if (dmyMatch != null) {
      final day = int.parse(dmyMatch.group(1)!);
      final month = int.parse(dmyMatch.group(2)!);
      final rawYear = int.parse(dmyMatch.group(3)!);
      final year = rawYear < 100 ? (rawYear < 70 ? 2000 + rawYear : 1900 + rawYear) : rawYear;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // YYYY-MM-DD or YYYY/MM/DD
    final ymdMatch = RegExp(r'^(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})$').firstMatch(clean);
    if (ymdMatch != null) {
      final year = int.parse(ymdMatch.group(1)!);
      final month = int.parse(ymdMatch.group(2)!);
      final day = int.parse(ymdMatch.group(3)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    const months = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };

    // Textual day-first: "05 Oct 2026", "5 October 2026", "16 Aug 2026"
    final textDayMatch = RegExp(r'(\d{1,2})\s+([a-zA-Z]+)\s+(\d{2,4})').firstMatch(clean);
    if (textDayMatch != null) {
      final day = int.parse(textDayMatch.group(1)!);
      final monthName = textDayMatch.group(2)!.toLowerCase();
      final rawYear = int.parse(textDayMatch.group(3)!);
      final year = rawYear < 100 ? (rawYear < 70 ? 2000 + rawYear : 1900 + rawYear) : rawYear;
      if (months.containsKey(monthName) && day >= 1 && day <= 31) {
        return DateTime(year, months[monthName]!, day);
      }
    }

    // Textual month-first: "October 5, 2026", "Oct 05 2026"
    final monthFirstMatch = RegExp(r'([a-zA-Z]+)\s+(\d{1,2}),?\s+(\d{2,4})').firstMatch(clean);
    if (monthFirstMatch != null) {
      final monthName = monthFirstMatch.group(1)!.toLowerCase();
      final day = int.parse(monthFirstMatch.group(2)!);
      final rawYear = int.parse(monthFirstMatch.group(3)!);
      final year = rawYear < 100 ? (rawYear < 70 ? 2000 + rawYear : 1900 + rawYear) : rawYear;
      if (months.containsKey(monthName) && day >= 1 && day <= 31) {
        return DateTime(year, months[monthName]!, day);
      }
    }

    final direct = DateTime.tryParse(clean);
    if (direct != null) return direct;

    return null;
  }

  /// Calculates medication status enforcing clinical safety rules:
  /// - "Ongoing / as needed" for PRN, SOS, symptoms, or continuous therapy
  /// - "Active" ONLY when both prescribed date and duration were parsed and prescribed_date + duration >= today
  /// - "Course ended" when prescribed_date + duration < today
  /// - "Prescribed date not stated" (grey chip) when prescribed date is missing/unparsable (unless discharge fallback applies)
  static String calculateMedicationStatus(
    String? prescribedDate,
    String? durationText, {
    String? frequency,
    String? dose,
    String? dischargeDateFallback,
    bool isDischargeSummary = false,
    DateTime? referenceDate,
  }) {
    final allCombined = '${durationText ?? ""} ${frequency ?? ""} ${dose ?? ""}'.toLowerCase().trim();

    // d) Ongoing / as needed check
    final ongoingKeywords = [
      'as needed',
      'prn',
      'sos',
      'if needed',
      'when needed',
      'if pain',
      'if fever',
      'প্রয়োজনে',
      'প্রয়োজনে',
      'প্রয়োজনমতো',
      'প্রয়োজনমতো',
      'শ্বাসকষ্ট হলে',
      'জ্বর হলে',
      'ব্যথা হলে',
      'চলবে',
      'ongoing',
      'continue',
      'continuing',
      'continuous',
      'indefinite',
      'lifetime',
    ];
    for (final kw in ongoingKeywords) {
      if (allCombined.contains(kw)) {
        return 'Ongoing / as needed';
      }
    }

    // Check duration parsing
    if (durationText == null || durationText.trim().isEmpty) {
      return 'Duration not stated';
    }

    final cleanDuration = convertBanglaDigits(durationText.trim().toLowerCase());
    final match = RegExp(
      r'(\d+)\s*(days?|weeks?|months?|years?|দিন|সপ্তাহ|মাস|বছর|d|w|m|y)?',
    ).firstMatch(cleanDuration);

    if (match == null) {
      return 'Duration not stated';
    }

    final amount = int.tryParse(match.group(1)!);
    if (amount == null) {
      return 'Duration not stated';
    }

    final unit = (match.group(2) ?? 'days').toLowerCase();
    Duration duration;
    if (unit.startsWith('w') || unit.contains('সপ্তাহ')) {
      duration = Duration(days: amount * 7);
    } else if (unit.startsWith('m') || unit.contains('মাস')) {
      duration = Duration(days: amount * 30);
    } else if (unit.startsWith('y') || unit.contains('বছর')) {
      duration = Duration(days: amount * 365);
    } else {
      duration = Duration(days: amount);
    }

    // Date parsing
    DateTime? startDate;
    if (prescribedDate != null && prescribedDate.trim().isNotEmpty) {
      startDate = parseDateString(prescribedDate);
    }

    // Discharge summary fallback
    if (startDate == null && isDischargeSummary && dischargeDateFallback != null) {
      startDate = parseDateString(dischargeDateFallback);
    }

    // If date is missing or unparsable
    if (startDate == null) {
      return 'Prescribed date not stated';
    }

    // Both date and duration are parsed:
    final now = referenceDate ?? clock();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(duration);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    if (endDay.isBefore(today)) {
      return 'Course ended';
    } else {
      return 'Active';
    }
  }

  /// Normalizes conditions with exact whole-name synonym matching (never substring).
  /// Unmapped conditions are kept untouched.
  /// Merges details (year, severity) into the surviving canonical entry.
  static List<String> normalizeAndDeduplicateConditions(List<dynamic> rawConditions) {
    final Map<String, _ConditionEntry> merged = {};

    const asthmaKeys = {'asthma', 'হাঁপানি', 'asthma (হাঁপানি)', 'হাঁপানি (asthma)', 'bronchial asthma'};
    const diabetesKeys = {'diabetes', 'diabetic', 'ডায়াবেটিস', 'diabetes (ডায়াবেটিস)', 'diabetes mellitus', 't2dm', 't1dm', 'type 2 diabetes', 'type 1 diabetes'};
    const allergyKeys = {'allergy', 'allergies', 'এলার্জি', 'allergy (এলার্জি)'};
    const htnKeys = {'hypertension', 'htn', 'উচ্চ রক্তচাপ', 'hypertension (উচ্চ রক্তচাপ)'};

    for (final raw in rawConditions) {
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isEmpty) continue;

      String cleanText = text;
      final extractedDetails = <String>[];

      // Extract parentheses: e.g. (২০১৫), (mild)
      final parenMatches = RegExp(r'\(([^)]+)\)').allMatches(cleanText);
      for (final pm in parenMatches) {
        final content = pm.group(1)?.trim();
        if (content != null && content.isNotEmpty) {
          extractedDetails.add(content);
        }
      }
      cleanText = cleanText.replaceAll(RegExp(r'\([^)]+\)'), '').trim();

      // Extract hyphen or comma modifiers: e.g. "Asthma - mild", "Asthma, mild"
      if (cleanText.contains(' - ')) {
        final parts = cleanText.split(' - ');
        cleanText = parts[0].trim();
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          extractedDetails.add(parts[1].trim());
        }
      } else if (cleanText.contains(', ')) {
        final parts = cleanText.split(', ');
        cleanText = parts[0].trim();
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          extractedDetails.add(parts[1].trim());
        }
      }

      final baseLower = cleanText.toLowerCase();

      String groupKey;
      String groupTitle;

      if (asthmaKeys.contains(baseLower)) {
        groupKey = 'asthma';
        groupTitle = 'Asthma (হাঁপানি)';
      } else if (diabetesKeys.contains(baseLower)) {
        groupKey = 'diabetes';
        groupTitle = 'Diabetes (ডায়াবেটিস)';
      } else if (allergyKeys.contains(baseLower)) {
        groupKey = 'allergy';
        groupTitle = 'Allergy (এলার্জি)';
      } else if (htnKeys.contains(baseLower)) {
        groupKey = 'hypertension';
        groupTitle = 'Hypertension (উচ্চ রক্তচাপ)';
      } else {
        groupKey = baseLower;
        groupTitle = cleanText;
      }

      final entry = merged.putIfAbsent(
        groupKey,
        () => _ConditionEntry(groupKey: groupKey, title: groupTitle),
      );

      // Process details: convert Bangla digits, format years and severity
      for (final rawDetail in extractedDetails) {
        final normalizedDetail = convertBanglaDigits(rawDetail.trim());
        final isYear = RegExp(r'^\d{4}$').hasMatch(normalizedDetail);
        if (isYear) {
          entry.addDetail('since $normalizedDetail', isOnset: true);
        } else if (normalizedDetail.toLowerCase().startsWith('since ') ||
            normalizedDetail.contains('থেকে')) {
          final yearMatch = RegExp(r'\d{4}').firstMatch(normalizedDetail);
          if (yearMatch != null) {
            entry.addDetail('since ${yearMatch.group(0)}', isOnset: true);
          } else {
            entry.addDetail(normalizedDetail, isOnset: true);
          }
        } else {
          entry.addDetail(normalizedDetail.toLowerCase(), isOnset: false);
        }
      }
    }

    return merged.values.map((e) => e.buildDisplay()).toList();
  }

  /// Maps HTTP status codes and responses to user-friendly messages without technical jargon or raw error dumps
  static String mapHttpError(int statusCode, String responseBody) {
    if (statusCode == 429) {
      // Check for retryDelay in body (e.g., {"error": {"details": [{"retryDelay": "54000s"}]}} or "Please retry after 54000s")
      final delayMatch = RegExp(r'retryDelay["\s:]+([0-9]+)s?', caseSensitive: false).firstMatch(responseBody) ??
          RegExp(r'retry after\s+([0-9]+)\s*s?', caseSensitive: false).firstMatch(responseBody) ??
          RegExp(r'([0-9]+)s\b').firstMatch(responseBody);

      if (delayMatch != null) {
        final sec = int.tryParse(delayMatch.group(1)!);
        if (sec != null && sec > 0) {
          if (sec >= 3600) {
            final hours = (sec / 3600).ceil();
            return 'The AI service has reached its usage limit. Please try again in about $hours ${hours == 1 ? "hour" : "hours"}.';
          } else {
            final mins = (sec / 60).ceil();
            return 'The AI service has reached its usage limit. Please try again in about $mins ${mins == 1 ? "minute" : "minutes"}.';
          }
        }
      }
      return 'The AI service has reached its usage limit. Please try again later.';
    }

    if (statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return 'The AI service is temporarily unavailable. Please try again.';
    }

    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      if (responseBody.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map<String, dynamic> && decoded['error'] != null) {
            final err = decoded['error'];
            final msg = err['message']?.toString();
            final status = err['status']?.toString();
            String? reason;
            if (err['details'] is List && (err['details'] as List).isNotEmpty) {
              final first = (err['details'] as List).first;
              if (first is Map && first['reason'] != null) {
                reason = first['reason'].toString();
              }
            }
            final detailsList = <String>[];
            if (msg != null && msg.isNotEmpty) detailsList.add(msg);
            if (status != null && status.isNotEmpty && status != msg) detailsList.add(status);
            if (reason != null && reason.isNotEmpty) detailsList.add('[$reason]');
            final detailSummary = detailsList.isNotEmpty ? detailsList.join(' - ') : responseBody;
            return 'AI service configuration problem (HTTP $statusCode): $detailSummary';
          }
        } catch (_) {}
        return 'AI service configuration problem (HTTP $statusCode): $responseBody';
      }
      return 'AI service configuration problem. Please contact support.';
    }

    return 'Unable to process document. Please try again.';
  }

  /// Maps any caught error or exception to a friendly UI message
  static String mapErrorToUserFriendlyMessage(dynamic error) {
    if (error is GeminiApiException) {
      return error.userMessage;
    }

    final str = error.toString().toLowerCase();

    if (str.contains('429') || str.contains('quota') || str.contains('resource_exhausted')) {
      return mapHttpError(429, error.toString());
    }

    if (str.contains('500') ||
        str.contains('502') ||
        str.contains('503') ||
        str.contains('504') ||
        str.contains('timeout') ||
        str.contains('timed out') ||
        str.contains('temporarily unavailable')) {
      return 'The AI service is temporarily unavailable. Please try again.';
    }

    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('no internet') ||
        str.contains('network is unreachable') ||
        str.contains('connection refused') ||
        str.contains('connection reset') ||
        str.contains('clientexception')) {
      return 'No internet connection.';
    }

    if (str.contains('400') ||
        str.contains('401') ||
        str.contains('403') ||
        str.contains('unauthorized') ||
        str.contains('forbidden') ||
        str.contains('api_key_invalid') ||
        str.contains('permission_denied')) {
      final errText = error.toString();
      if (errText.trim().isNotEmpty && !errText.toLowerCase().startsWith('instance of')) {
        return 'AI service configuration problem: $errText';
      }
      return 'AI service configuration problem. Please contact support.';
    }

    return 'Unable to process document. Please try again.';
  }

  /// Strict System Prompt enforcing document type classification, JSON-only schema, and clinical guardrails
  static const String systemPrompt = '''
You are a strict clinical data extraction engine for university medical center onboarding.

CLASSIFICATION RULES:
1. Medical documents are: prescriptions, lab reports, discharge summaries, doctor notes, clinical records, vaccination cards, medical certificates.
   Everything else (CV/resume, invoice, receipt, ID card, certificate of education, general photo, etc.) is "other_non_medical" and "is_medical_document" must be false.
2. A non-clinical document that merely mentions a health word (for example a CV listing a blood group or hobbies) is NOT a medical document. "is_medical_document" MUST be false.
3. If the file is too blurry or empty to read, use document_type "unreadable" and "is_medical_document" false.
4. When "is_medical_document" is false: return every other clinical field empty/null. Do NOT extract anything.
5. In "classification_reason", provide a brief generic explanation (e.g. "Curriculum Vitae / Resume detected", "Educational certificate detected", "Invoice or receipt detected"). NEVER include personal names, patient names, email addresses, phone numbers, or any personally identifiable details in classification_reason.
6. Extract ONLY what is written in the document. Never guess, infer, or hallucinate. Use null if missing. Never write 'none' unless the document explicitly says no allergies.

MULTI-DOCUMENT TIMELINE & LATEST DATA PRIORITY:
7. The document may be a merged multi-page PDF or composite record containing multiple historical prescriptions and clinical reports across different dates:
   - Scan all pages and establish a strict chronological timeline of all consultation dates and prescription dates.
   - Enforce "Latest Date Priority" for current active status: The most recent prescription or visit takes precedence and defines current status. If an older prescription prescribed a medication (e.g. 500mg) and a later visit updated the dosage (e.g. 250mg), discontinued it, or substituted it, reflect the latest active dosage/medication in "current_medications". Similarly, for optical/refraction reports (glasses prescription), report the latest date's values.

HISTORICAL RETENTION (SURGERIES & ADMISSIONS):
8. Past significant clinical events must NEVER be discarded or overwritten by newer visits:
   - Permanently retain all past surgeries and major surgical procedures (e.g. "2018 ASD Closure", "Laparoscopic Hernia Repair", "Appendectomy", "Fracture fixation") in "procedures".
   - Record all prior hospital admissions, ICU stays, and discharge dates in "hospital_admissions".
   - Record prior significant clinical encounters and illnesses in "past_visits".
   Even if the newest prescription is for a minor acute issue (e.g. seasonal fever, cold, or eye checkup), all historical surgeries, procedures, and admissions discovered across older pages must be preserved.

HANDWRITING & UNCLEAR TEXT INTELLIGENCE:
9. Exercise contextual medical validation when parsing doctor's handwritten notes, abbreviations, and numerical dosages:
   - Cross-check abbreviations and numbers with common pharmacological and clinical standards.
   - If any doctor's handwritten drug name, dosage number, frequency, or instruction is ambiguous, smudged, illegible, or uncertain, do NOT guess or hallucinate.
   - Label ambiguous values safely with "Unverified - confirm with doctor" (for example: dose: "Unverified - confirm with doctor", or drug name: "Tab. Metformin [Unverified - confirm with doctor]").

BLOOD GROUP RULES:
10. "blood_group" must be strictly one of: "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", or null. Normalize forms like "B positive", "B ve", Bangla spellings. If it is ambiguous, return null.
11. "blood_group_source" is "lab_report" ONLY if the document is a blood grouping or lab test report. A prescription or doctor note gives "clinical_record". Any other non-clinical file gives "other_document". If there is no blood group, use "not_found".
12. "blood_group_evidence" is the exact words from the document stating the blood group, or null if absent.

SURGERIES, ADMISSIONS & PROCEDURES RULES:
13. Extract past or recent procedures/surgeries into "procedures": [{"name": "Exact procedure name", "date": "Date if written or null"}].
14. Extract formal diagnoses into "diagnoses": [{"name": "Diagnosis name", "date": "Date if written or null"}].
15. Extract hospital admissions/stays into "hospital_admissions": [{"admit_date": "Date or null", "discharge_date": "Date or null", "reason": "Reason for admission or null"}]. Extract only what is written.

MEDICATION TIMING RULES:
16. For each medication in "current_medications", extract:
    "name": medicine name,
    "dose": dosage as written,
    "frequency": frequency as written,
    "prescribed_date": start or prescribed date if written, else null,
    "duration_text": exact duration string written (e.g. "5 days", "14 days", "1 month", "2 weeks", "২ সপ্তাহ", "চলবে", "as needed", or null).
    Do NOT compute or infer end dates in Gemini; return the exact duration_text and prescribed_date as written.

CONDITION DEDUPLICATION RULES:
17. Merge identical conditions across languages into a bilingual form: e.g. if the document mentions both 'Asthma' and 'হাঁপানি', or either one, output "Asthma (হাঁপানি)". For diabetes, output "Diabetes (ডায়াবেটিস)". For allergies, output "Allergy (এলার্জি)". For hypertension, output "Hypertension (উচ্চ রক্তচাপ)". Never output duplicate conditions.

ALLERGY REACTION RULES:
18. In "drug_allergies", "food_allergies", and "environmental_allergies", extract each allergy as an object:
    {"substance": "Name of substance or medication", "reaction": "Symptoms or reactions like itching, rash, swelling, or null if unstated"}.

FOLLOW-UP APPOINTMENT RULES:
19. Always list every follow-up appointment, revisit, or scheduled checkup that is written in the document into "follow_ups":
    [{"date": "Date of appointment or null", "place": "Clinic/department/room or null", "purpose": "Purpose or reason for follow-up or null"}].
    If no follow-up is written in the document, return an empty array [].

PATIENT NAME RULES:
20. If a patient's name is explicitly written or printed on the document (e.g. "Name: Tanvir Rahman", "Pt: Sajol Hassan"), extract it into "patient_name". If missing or unstated, return null.

Return ONLY a valid JSON object without markdown formatting.

Required JSON Schema:
{
  "is_medical_document": true,
  "document_type": "prescription | lab_report | discharge_summary | clinical_record | other_non_medical | unreadable",
  "classification_reason": "Short generic explanation without any personal names or private details",
  "patient_name": "String or null",
  "blood_group": "A+ | A- | B+ | B- | AB+ | AB- | O+ | O- | null",
  "blood_group_source": "lab_report | clinical_record | other_document | not_found",
  "blood_group_evidence": "String or null",
  "drug_allergies": [{"substance": "String", "reaction": "String or null"}],
  "food_allergies": [{"substance": "String", "reaction": "String or null"}],
  "environmental_allergies": [{"substance": "String", "reaction": "String or null"}],
  "chronic_conditions": ["String"],
  "procedures": [{"name": "String", "date": "String or null"}],
  "diagnoses": [{"name": "String", "date": "String or null"}],
  "hospital_admissions": [{"admit_date": "String or null", "discharge_date": "String or null", "reason": "String or null"}],
  "current_medications": [{"name": "String", "dose": "String", "frequency": "String", "prescribed_date": "String or null", "duration_text": "String or null"}],
  "abnormal_labs": ["String"],
  "past_visits": [{"date": "String", "diagnosis": "String"}],
  "follow_ups": [{"date": "String or null", "place": "String or null", "purpose": "String or null"}],
  "doctor_advice": "String or null"
}
''';

  /// Resolves the exact MIME type based on file extension
  static String lookupMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'application/pdf';
    }
  }

  /// Real multimodal Gemini API network call
  Future<Map<String, dynamic>> extractMedicalJson({
    required String fileName,
    required int fileSizeBytes,
    Uint8List? fileBytes,
  }) async {
    // Check client-side rate limit before proceeding
    checkRateLimit();

    if (fileBytes == null || fileBytes.isEmpty) {
      throw GeminiApiException(
        userMessage: 'Selected file "$fileName" has empty or unreadable byte content.',
      );
    }

    final String mimeType = lookupMimeType(fileName);
    final String base64Data = base64Encode(fileBytes);

    if (kDebugMode) {
      debugPrint('GeminiAiService: Starting analysis for "$fileName"');
      debugPrint('GeminiAiService: Detected MIME type: $mimeType, Size: $fileSizeBytes bytes');
    }

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': systemPrompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Data,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0,
      }
    };

    final List<String> activeKeys = GeminiAiService.geminiApiKeys;
    final int totalKeys = activeKeys.length;
    if (totalKeys == 0) {
      throw GeminiApiException(
        statusCode: 503,
        userMessage: allFailFriendlyMessage,
      );
    }

    final client = httpClient ?? http.Client();
    int? lastFailureStatusCode;
    String? lastFailureBody;

    try {
      for (final model in modelChain) {
        // 404 -> mark that model as unavailable, never retry it, move to the next model.
        if (_unavailableModels.contains(model)) {
          if (kDebugMode) {
            debugPrint('GeminiAiService: Model "$model" is marked unavailable for this session. Skipping.');
          }
          continue;
        }

        bool modelIsUnavailable = false;

        for (int i = 0; i < totalKeys; i++) {
          if (modelIsUnavailable) {
            break; // 404 was encountered for this model; move to next model
          }

          final int keyIndex = (_currentKeyIndex + i) % totalKeys;
          final String currentKey = activeKeys[keyIndex].trim();

          // 403 / 401 / 400 -> mark that key as dead for this session, move on.
          if (_deadKeys.contains(currentKey)) {
            if (kDebugMode) {
              debugPrint('GeminiAiService: Key at index $keyIndex is marked dead for this session. Skipping.');
            }
            continue;
          }

          // 429 -> mark that key+model on cooldown, move to the next key/model.
          final cooldownKey = '$currentKey:$model';
          final cooldownExpiry = _keyModelCooldowns[cooldownKey];
          if (cooldownExpiry != null && clock().isBefore(cooldownExpiry)) {
            if (kDebugMode) {
              debugPrint('GeminiAiService: Key at index $keyIndex on model "$model" is currently on cooldown. Skipping.');
            }
            continue;
          }

          // 503 / 500 / 504 / timeout (25s) -> retry the same key up to 2 times (wait ~2s, then ~5s), then move to the next key, then the next model.
          const int maxSameKeyAttempts = 3; // 1 initial + 2 retries
          for (int attempt = 0; attempt < maxSameKeyAttempts; attempt++) {
            if (attempt == 1) {
              await sleeper(const Duration(seconds: 2));
            } else if (attempt == 2) {
              await sleeper(const Duration(seconds: 5));
            }

            final url = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$currentKey',
            );

            http.Response? response;
            bool isTimeout = false;
            bool isClientNetworkError = false;

            try {
              response = await client
                  .post(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'x-goog-api-key': currentKey,
                    },
                    body: jsonEncode(payload),
                  )
                  .timeout(const Duration(seconds: 25));
            } on TimeoutException {
              isTimeout = true;
              if (kDebugMode) {
                debugPrint('🔄 [GeminiAiService] Timeout (25s) on model "$model", key index $keyIndex (attempt ${attempt + 1}/$maxSameKeyAttempts)');
              }
            } on http.ClientException catch (e) {
              isClientNetworkError = true;
              if (kDebugMode) {
                debugPrint('🔄 [GeminiAiService] ClientException on model "$model", key index $keyIndex: $e');
              }
            } catch (e) {
              final errStr = e.toString().toLowerCase();
              if (errStr.contains('timeout') || errStr.contains('timed out')) {
                isTimeout = true;
              } else {
                isClientNetworkError = true;
              }
            }

            // Case 1: Timeout or Client Exception (transient network error)
            if (isTimeout || isClientNetworkError) {
              lastFailureStatusCode = isTimeout ? 504 : 503;
              lastFailureBody = isTimeout ? 'TimeoutException' : 'ClientException';

              if (attempt < maxSameKeyAttempts - 1) {
                continue; // retry same key
              } else {
                break; // retries exhausted on this key -> move to next key
              }
            }

            // Response received
            final statusCode = response!.statusCode;
            final bodyStr = response.body;
            lastFailureStatusCode = statusCode;
            lastFailureBody = bodyStr;

            if (kDebugMode) {
              debugPrint('GeminiAiService: [Model: $model, Key Index: $keyIndex] HTTP Status: $statusCode');
            }

            // 200 -> success, return.
            if (statusCode == 200) {
              _currentKeyIndex = keyIndex; // update working key
              return _parseGeminiJsonResponse(bodyStr);
            }

            // 404 -> mark that model as unavailable, never retry it, move to the next model.
            if (statusCode == 404) {
              _unavailableModels.add(model);
              modelIsUnavailable = true;
              debugPrint(
                '🔄 [GeminiAiService] HTTP 404 Model Not Found for "$model". '
                'Marking model as unavailable for this session and moving to next model...',
              );
              break;
            }

            // 403 / 401 / 400 -> mark that key as dead for this session, move on.
            if (statusCode == 403 || statusCode == 401 || statusCode == 400) {
              _deadKeys.add(currentKey);
              final reason = statusCode == 403
                  ? 'HTTP 403 Permission Denied'
                  : (statusCode == 401 ? 'HTTP 401 Unauthorized' : 'HTTP 400 Bad Request');
              debugPrint(
                '🔄 [GeminiAiService] $reason on model "$model", key index $keyIndex. '
                'Marking key as dead for this session and moving to next key...',
              );
              break;
            }

            // 429 -> mark that key+model on cooldown, move to the next key/model.
            if (statusCode == 429) {
              final cooldownDuration = _parseCooldownDuration(bodyStr);
              _keyModelCooldowns[cooldownKey] = clock().add(cooldownDuration);
              debugPrint(
                '🔄 [GeminiAiService] Quota/Rate limit exceeded (HTTP 429) on model "$model", key index $keyIndex. '
                'Cooldown set for ${cooldownDuration.inSeconds}s. Moving to next key/model...',
              );
              break;
            }

            // 503 / 500 / 504 -> retry the same key up to 2 times (wait ~2s, then ~5s), then move to the next key, then the next model.
            if (statusCode == 503 || statusCode == 500 || statusCode == 504) {
              debugPrint(
                '🔄 [GeminiAiService] Server error (HTTP $statusCode) on model "$model", key index $keyIndex (attempt ${attempt + 1}/$maxSameKeyAttempts)...',
              );
              if (attempt < maxSameKeyAttempts - 1) {
                continue; // retry same key
              } else {
                break; // retries exhausted on this key -> move to next key
              }
            }

            // Any other status code -> move to next key
            debugPrint('🔄 [GeminiAiService] Unexpected HTTP $statusCode on model "$model", key index $keyIndex. Moving to next key...');
            break;
          }
        }
      }
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }

    // If everything fails, show: "AI service is temporarily unavailable. You can continue by filling the form manually." and keep the manual form fully usable.
    _currentKeyIndex = 0;
    throw GeminiApiException(
      statusCode: lastFailureStatusCode ?? 503,
      userMessage: allFailFriendlyMessage,
      technicalDetails: kDebugMode ? lastFailureBody : null,
    );
  }

  static Duration _parseCooldownDuration(String responseBody) {
    try {
      final delayMatch = RegExp(r'retryDelay["\s:]+([0-9]+)s?', caseSensitive: false).firstMatch(responseBody) ??
          RegExp(r'retry after\s+([0-9]+)\s*s?', caseSensitive: false).firstMatch(responseBody) ??
          RegExp(r'([0-9]+)s\b').firstMatch(responseBody);
      if (delayMatch != null) {
        final sec = int.tryParse(delayMatch.group(1)!);
        if (sec != null && sec > 0) {
          return Duration(seconds: sec);
        }
      }
    } catch (_) {}
    return const Duration(seconds: 60);
  }

  static Map<String, dynamic> _parseGeminiJsonResponse(String body) {
    final Map<String, dynamic> responseJson = jsonDecode(body) as Map<String, dynamic>;
    final candidates = responseJson['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiApiException(
        userMessage: 'The AI service returned an empty response. Please try again.',
      );
    }

    final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw GeminiApiException(
        userMessage: 'The AI service returned no readable clinical content.',
      );
    }

    final String rawText = parts[0]['text']?.toString() ?? '';
    if (kDebugMode) {
      debugPrint('GeminiAiService: Extracted Text Content: $rawText');
    }

    String cleanJson = rawText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    } else if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    try {
      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      throw GeminiApiException(
        userMessage: 'The AI service output could not be formatted. Please try again.',
        technicalDetails: kDebugMode ? 'Failed to parse JSON: $e\nRaw: $cleanJson' : null,
      );
    }
  }

  /// Multimodal Gemini clinical parsing returning typed ExtractedMedicalData
  Future<ExtractedMedicalData> analyzeMedicalDocument({
    required String fileName,
    required int fileSizeBytes,
    Uint8List? fileBytes,
  }) async {
    final Map<String, dynamic> jsonMap = await extractMedicalJson(
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      fileBytes: fileBytes,
    );
    return ExtractedMedicalData.fromMap(jsonMap);
  }
}

/// Helper class to merge and deduplicate condition details
class _ConditionEntry {
  final String groupKey;
  final String title;
  final List<String> severities = [];
  final List<String> onsets = [];

  _ConditionEntry({required this.groupKey, required this.title});

  void addDetail(String detail, {required bool isOnset}) {
    if (isOnset) {
      if (!onsets.contains(detail)) onsets.add(detail);
    } else {
      if (!severities.contains(detail)) severities.add(detail);
    }
  }

  String buildDisplay() {
    final all = [...severities, ...onsets];
    if (all.isEmpty) return title;
    return '$title - ${all.join(", ")}';
  }
}
