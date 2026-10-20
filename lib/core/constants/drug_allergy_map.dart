// MVP list only, not a clinical decision support system.

/// Known drug cross-reactivity and allergy families for MVP clinical safety warning.
/// Note: This is an MVP heuristic check to surface AI-extracted allergy warnings to physicians.
/// It is NOT a full clinical decision support system (CDSS) and must be confirmed with the patient.
const Map<String, List<String>> kDrugAllergyFamilies = {
  'penicillin': [
    'penicillin',
    'amoxicillin',
    'ampicillin',
    'amoxiclav',
    'co-amoxiclav',
    'flucloxacillin',
    'piperacillin',
    'oxacillin',
    'cloxacillin',
    'augmentin',
    'moxacil',
  ],
  'sulfa': [
    'sulfa',
    'sulfonamide',
    'sulfamethoxazole',
    'cotrimoxazole',
    'bactrim',
    'septra',
    'sulfadiazine',
    'sulfasalazine',
  ],
  'aspirin': [
    'aspirin',
    'nsaid',
    'ibuprofen',
    'diclofenac',
    'naproxen',
    'ketorolac',
    'aceclofenac',
    'indomethacin',
    'mefenamic',
    'etoricoxib',
    'celecoxib',
  ],
  'nsaid': [
    'nsaid',
    'aspirin',
    'ibuprofen',
    'diclofenac',
    'naproxen',
    'ketorolac',
    'aceclofenac',
    'indomethacin',
    'mefenamic',
    'etoricoxib',
    'celecoxib',
  ],
};

class AllergyConflictResult {
  final bool hasConflict;
  final String? matchedAllergy;
  final String? medicineName;
  final String? matchedFamily;

  const AllergyConflictResult({
    required this.hasConflict,
    this.matchedAllergy,
    this.medicineName,
    this.matchedFamily,
  });

  static const AllergyConflictResult noConflict = AllergyConflictResult(hasConflict: false);
}

/// Checks if a given medicine name conflicts with any patient-reported known allergies.
/// Uses substring matching and drug-family cross-reactivity mapping.
AllergyConflictResult checkMedicineAllergyConflict(
  String rawMedicineName,
  List<String> rawAllergies,
) {
  final med = rawMedicineName.trim().toLowerCase();
  if (med.isEmpty || rawAllergies.isEmpty) {
    return AllergyConflictResult.noConflict;
  }

  for (final rawAllergy in rawAllergies) {
    final allergy = rawAllergy.trim().toLowerCase();
    if (allergy.isEmpty) continue;

    // 1. Direct substring matching (e.g. "Paracetamol" in "Paracetamol 500mg" or vice-versa)
    if (med.contains(allergy) || (allergy.length >= 3 && allergy.contains(med))) {
      return AllergyConflictResult(
        hasConflict: true,
        matchedAllergy: rawAllergy.trim(),
        medicineName: rawMedicineName.trim(),
        matchedFamily: null,
      );
    }

    // 2. Drug-family mapping (e.g. penicillin <-> amoxicillin, sulfa <-> cotrimoxazole)
    for (final entry in kDrugAllergyFamilies.entries) {
      final familyKey = entry.key;
      final familyMembers = entry.value;

      final allergyBelongsToFamily = allergy.contains(familyKey) ||
          familyMembers.any((m) => allergy.contains(m));

      final medicineBelongsToFamily = med.contains(familyKey) ||
          familyMembers.any((m) => med.contains(m));

      if (allergyBelongsToFamily && medicineBelongsToFamily) {
        return AllergyConflictResult(
          hasConflict: true,
          matchedAllergy: rawAllergy.trim(),
          medicineName: rawMedicineName.trim(),
          matchedFamily: familyKey,
        );
      }
    }
  }

  return AllergyConflictResult.noConflict;
}
