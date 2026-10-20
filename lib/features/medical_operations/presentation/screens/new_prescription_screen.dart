import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/constants/drug_allergy_map.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../data/models/prescription_model.dart';
import '../../../medical_onboarding_ai/data/services/gemini_ai_service.dart';

class MedicineRowData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();
  AllergyConflictResult conflictResult = AllergyConflictResult.noConflict;

  bool isNameAiExtracted = false;
  bool isDoseAiExtracted = false;
  bool isFrequencyAiExtracted = false;
  bool isDurationAiExtracted = false;
  bool isInstructionsAiExtracted = false;

  void dispose() {
    nameController.dispose();
    doseController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }
}

class NewPrescriptionScreen extends ConsumerStatefulWidget {
  final String studentUid;
  final String studentId;
  final String studentName;
  final List<String> knownAllergies;
  final String? studentDepartment;
  final String? studentBloodGroup;
  final Future<void> Function(PrescriptionModel rx)? onIssuePrescriptionOverride;
  final Future<ExtractedMedicalData> Function(PlatformFile file)? onScanOverride;
  final Future<PlatformFile?> Function()? onPickFileOverride;

  const NewPrescriptionScreen({
    super.key,
    required this.studentUid,
    required this.studentId,
    required this.studentName,
    required this.knownAllergies,
    this.studentDepartment,
    this.studentBloodGroup,
    this.onIssuePrescriptionOverride,
    this.onScanOverride,
    this.onPickFileOverride,
  });

  @override
  ConsumerState<NewPrescriptionScreen> createState() => _NewPrescriptionScreenState();
}

class _NewPrescriptionScreenState extends ConsumerState<NewPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _adviceController = TextEditingController();
  DateTime? _selectedFollowUpDate;
  bool _isSubmitting = false;
  bool _isScanning = false;
  String _prescriptionSource = 'digital';

  String? _nameWarningType; // 'mismatch' | 'not_found' | null
  String? _extractedPatientName;

  bool _isDiagnosisAiExtracted = false;
  String _prefilledDiagnosis = '';

  bool _isAdviceAiExtracted = false;
  String _prefilledAdvice = '';

  bool _isFollowUpAiExtracted = false;

  final List<MedicineRowData> _medicineRows = [];

  @override
  void initState() {
    super.initState();

    _diagnosisController.addListener(() {
      if (_isDiagnosisAiExtracted && _diagnosisController.text != _prefilledDiagnosis) {
        setState(() => _isDiagnosisAiExtracted = false);
      }
    });

    _adviceController.addListener(() {
      if (_isAdviceAiExtracted && _adviceController.text != _prefilledAdvice) {
        setState(() => _isAdviceAiExtracted = false);
      }
    });

    _addMedicineRow();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _adviceController.dispose();
    for (final row in _medicineRows) {
      row.dispose();
    }
    super.dispose();
  }

  MedicineRowData _createMedicineRow({
    String name = '',
    String dose = '',
    String frequency = '',
    String duration = '',
    String instructions = '',
    bool isAi = false,
  }) {
    final row = MedicineRowData();
    row.nameController.text = name;
    row.doseController.text = dose;
    row.frequencyController.text = frequency;
    row.durationController.text = duration;
    row.instructionsController.text = instructions;

    row.isNameAiExtracted = isAi && name.isNotEmpty;
    row.isDoseAiExtracted = isAi && dose.isNotEmpty;
    row.isFrequencyAiExtracted = isAi && frequency.isNotEmpty;
    row.isDurationAiExtracted = isAi && duration.isNotEmpty;
    row.isInstructionsAiExtracted = isAi && instructions.isNotEmpty;

    row.nameController.addListener(() {
      if (row.isNameAiExtracted && row.nameController.text != name) {
        row.isNameAiExtracted = false;
        if (mounted) setState(() {});
      }
      final conflict = checkMedicineAllergyConflict(
        row.nameController.text,
        widget.knownAllergies,
      );
      if (row.conflictResult.hasConflict != conflict.hasConflict ||
          row.conflictResult.matchedAllergy != conflict.matchedAllergy) {
        if (mounted) {
          setState(() {
            row.conflictResult = conflict;
          });
        }
      }
    });

    row.doseController.addListener(() {
      if (row.isDoseAiExtracted && row.doseController.text != dose) {
        row.isDoseAiExtracted = false;
        if (mounted) setState(() {});
      }
    });

    row.frequencyController.addListener(() {
      if (row.isFrequencyAiExtracted && row.frequencyController.text != frequency) {
        row.isFrequencyAiExtracted = false;
        if (mounted) setState(() {});
      }
    });

    row.durationController.addListener(() {
      if (row.isDurationAiExtracted && row.durationController.text != duration) {
        row.isDurationAiExtracted = false;
        if (mounted) setState(() {});
      }
    });

    row.instructionsController.addListener(() {
      if (row.isInstructionsAiExtracted && row.instructionsController.text != instructions) {
        row.isInstructionsAiExtracted = false;
        if (mounted) setState(() {});
      }
    });

    if (name.isNotEmpty) {
      row.conflictResult = checkMedicineAllergyConflict(name, widget.knownAllergies);
    }

    return row;
  }

  void _addMedicineRow() {
    if (_medicineRows.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 20 medicines allowed per prescription.')),
      );
      return;
    }

    final row = _createMedicineRow();
    setState(() {
      _medicineRows.add(row);
    });
  }

  void _removeMedicineRow(int index) {
    if (_medicineRows.length <= 1) return;
    setState(() {
      final removed = _medicineRows.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedFollowUpDate ?? now.add(const Duration(days: 5)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedFollowUpDate = picked;
        _isFollowUpAiExtracted = false;
      });
    }
  }

  List<AllergyConflictResult> get _activeConflicts {
    return _medicineRows
        .map((r) => r.conflictResult)
        .where((c) => c.hasConflict)
        .toList();
  }

  static bool isPatientNameMatch(String currentName, String? extractedName) {
    if (extractedName == null || extractedName.trim().isEmpty) return true;
    final normCurrent = _normalizeName(currentName);
    final normExtracted = _normalizeName(extractedName);
    if (normCurrent.isEmpty || normExtracted.isEmpty) return true;
    if (normCurrent == normExtracted) return true;
    if (normCurrent.contains(normExtracted) || normExtracted.contains(normCurrent)) return true;
    final tokens1 = normCurrent.split(' ').where((t) => t.length > 2).toSet();
    final tokens2 = normExtracted.split(' ').where((t) => t.length > 2).toSet();
    if (tokens1.isNotEmpty && tokens2.isNotEmpty && tokens1.intersection(tokens2).isNotEmpty) {
      return true;
    }
    return false;
  }

  static String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\b(mr|md|mst|dr|mrs|ms)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _handleScanPrescription() async {
    if (_isScanning || _isSubmitting) return;

    try {
      PlatformFile? pickedFile;
      if (widget.onPickFileOverride != null) {
        pickedFile = await widget.onPickFileOverride!();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          pickedFile = result.files.first;
        }
      }

      if (pickedFile == null) return;

      const maxBytes = 5 * 1024 * 1024; // 5 MB
      if (pickedFile.size > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            content: Text('File is larger than 5 MB. Please upload a smaller file.'),
          ),
        );
        return;
      }

      setState(() => _isScanning = true);

      final ExtractedMedicalData result;
      if (widget.onScanOverride != null) {
        result = await widget.onScanOverride!(pickedFile);
      } else {
        final bytes = pickedFile.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('File content could not be read into memory. Please re-select the file.');
        }
        final aiService = GeminiAiService();
        result = await aiService.analyzeMedicalDocument(
          fileName: pickedFile.name,
          fileSizeBytes: pickedFile.size,
          fileBytes: bytes,
        );
      }

      if (!mounted) return;

      // 1. Classification & Non-prescription rejection check
      final bool isPrescription = result.isMedicalDocument &&
          (result.documentType == 'prescription' || result.documentType == 'clinical_record');

      if (!result.isMedicalDocument || !isPrescription) {
        final String rejectionMessage;
        if (!result.isMedicalDocument || result.documentType == 'unreadable') {
          rejectionMessage = result.documentType == 'unreadable'
              ? 'We could not read this file. Please upload a clearer photo or PDF.'
              : 'This does not look like a medical document. This looks like a non-medical document such as a CV, invoice or ID card.';
        } else {
          rejectionMessage = 'The uploaded document is not a prescription. Please upload a valid prescription.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(rejectionMessage)),
              ],
            ),
          ),
        );
        return;
      }

      // 2. Patient name verification
      final extName = result.patientName;
      if (extName == null || extName.trim().isEmpty) {
        _nameWarningType = 'not_found';
        _extractedPatientName = null;
      } else if (!isPatientNameMatch(widget.studentName, extName)) {
        _nameWarningType = 'mismatch';
        _extractedPatientName = extName.trim();
      } else {
        _nameWarningType = null;
        _extractedPatientName = null;
      }

      // 3. Mark source as 'scan'
      _prescriptionSource = 'scan';

      // 4. Map Diagnosis
      String diag = '';
      if (result.diagnoses.isNotEmpty) {
        diag = result.diagnoses.map((d) => d.name).join(', ').trim();
      } else if (result.rawJson['diagnosis'] != null) {
        diag = result.rawJson['diagnosis'].toString().trim();
      }
      if (diag.isNotEmpty) {
        _diagnosisController.text = diag;
        _prefilledDiagnosis = diag;
        _isDiagnosisAiExtracted = true;
      }

      // 5. Map Doctor Advice
      if (result.doctorAdvice != null && result.doctorAdvice!.trim().isNotEmpty) {
        _adviceController.text = result.doctorAdvice!.trim();
        _prefilledAdvice = result.doctorAdvice!.trim();
        _isAdviceAiExtracted = true;
      }

      // 6. Map Follow-up Date
      if (result.followUps.isNotEmpty && result.followUps.first.date != null) {
        final parsedDate = GeminiAiService.parseDateString(result.followUps.first.date!);
        if (parsedDate != null) {
          _selectedFollowUpDate = parsedDate;
          _isFollowUpAiExtracted = true;
        }
      }

      // 7. Map Medicines
      for (final r in _medicineRows) {
        r.dispose();
      }
      _medicineRows.clear();

      if (result.currentMedications.isNotEmpty) {
        for (final med in result.currentMedications.take(20)) {
          final row = _createMedicineRow(
            name: med.name,
            dose: med.dose,
            frequency: med.frequency,
            duration: med.durationText ?? '',
            instructions: med.toMap()['instructions']?.toString() ?? '',
            isAi: true,
          );
          _medicineRows.add(row);
        }
      } else {
        _medicineRows.add(_createMedicineRow());
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.successGreen,
          content: Text('Prescription scanned and pre-filled! Please review and verify all fields.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final friendlyMsg = GeminiAiService.mapErrorToUserFriendlyMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(friendlyMsg)),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _handleIssuePrescription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_medicineRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one medicine is required.')),
      );
      return;
    }

    final conflicts = _activeConflicts;
    bool hasCheckedWithPatient = false;

    // Show Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool canConfirm = conflicts.isEmpty || hasCheckedWithPatient;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.assignment_turned_in, color: BaustColors.primaryArmyGreen),
                  SizedBox(width: 8),
                  Text('Confirm Prescription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient: ${widget.studentName} (${widget.studentId})'),
                    const SizedBox(height: 4),
                    Text('Diagnosis: ${_diagnosisController.text.trim()}'),
                    Text('Medications: ${_medicineRows.length} item(s)'),
                    Text('Source: ${_prescriptionSource == 'scan' ? 'Digitized from paper scan' : 'Digital direct issue'}'),
                    const SizedBox(height: 12),

                    if (conflicts.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BaustColors.emergencyRed),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: BaustColors.emergencyRed, size: 20),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'CRITICAL ALLERGY CONFLICT WARNING',
                                    style: TextStyle(
                                      color: BaustColors.emergencyRed,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final c in conflicts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• Possible allergy conflict: patient reported ${c.matchedAllergy} (AI-extracted, unverified - confirm with patient)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: BaustColors.emergencyRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: hasCheckedWithPatient,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: BaustColors.emergencyRed,
                        title: const Text(
                          'I have checked with the patient',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            hasCheckedWithPatient = val ?? false;
                          });
                        },
                      ),
                    ] else ...[
                      const Text(
                        'This digital prescription will be cryptographically locked and stored as an immutable clinical record.',
                        style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canConfirm ? BaustColors.primaryArmyGreen : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: canConfirm ? () => Navigator.pop(dialogCtx, true) : null,
                  child: const Text('Issue Prescription'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final authState = ref.read(authControllerProvider);
      final currentDoctor = authState.userProfile;
      final doctorUid = currentDoctor?.uid ?? 'doctor_test_uid';
      final doctorName = currentDoctor?.displayName ?? 'Dr. Medical Officer';

      final items = _medicineRows.map((r) {
        return PrescriptionItem(
          name: r.nameController.text.trim(),
          dose: r.doseController.text.trim(),
          frequency: r.frequencyController.text.trim(),
          duration: r.durationController.text.trim(),
          instructions: r.instructionsController.text.trim().isNotEmpty
              ? r.instructionsController.text.trim()
              : null,
        );
      }).toList();

      final prescription = PrescriptionModel(
        id: '',
        studentUid: widget.studentUid,
        studentId: widget.studentId,
        studentName: widget.studentName,
        doctorUid: doctorUid,
        doctorName: doctorName,
        doctorDesignation: 'Senior Medical Officer',
        diagnosis: _diagnosisController.text.trim(),
        items: items,
        advice: _adviceController.text.trim().isNotEmpty ? _adviceController.text.trim() : null,
        followUpDate: _selectedFollowUpDate,
        source: _prescriptionSource,
        studentDepartment: widget.studentDepartment,
        studentBloodGroup: widget.studentBloodGroup,
      );

      if (widget.onIssuePrescriptionOverride != null) {
        await widget.onIssuePrescriptionOverride!(prescription);
      } else {
        // Live Firestore writes
        final firestore = FirebaseFirestore.instance;
        final docRef = firestore.collection('prescriptions').doc();
        await docRef.set(prescription.toFirestoreMap());

        // Audit Trail access_logs
        await firestore.collection('access_logs').add({
          'doctorUid': doctorUid,
          'doctorName': doctorName,
          'studentUid': widget.studentUid,
          'studentId': widget.studentId,
          'action': 'create_prescription',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: BaustColors.successGreen,
            content: Text('Prescription issued successfully!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            content: Text('Failed to issue prescription: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 10, color: Color(0xFF1D4ED8)),
          SizedBox(width: 3),
          Text(
            'AI-extracted - verify',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Issue Digital Prescription'),
        backgroundColor: Colors.white,
        foregroundColor: BaustColors.primaryNavy,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // PATIENT HEADER CARD
              // ==========================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: BaustColors.primaryNavy.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: BaustColors.primaryNavy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.studentName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: BaustColors.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Student ID: ${widget.studentId}',
                                style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                              ),
                              if (widget.studentDepartment != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.studentDepartment!,
                                  style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            widget.studentBloodGroup != null
                                ? '${widget.studentBloodGroup} • Unverified'
                                : 'Blood Group: Unverified',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Allergy Status / Amber Note
                    if (widget.knownAllergies.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'No allergy information on file - confirm with patient.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Reported Allergies:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BaustColors.emergencyRed),
                          ),
                          ...widget.knownAllergies.map((a) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  a,
                                  style: const TextStyle(fontSize: 10, color: BaustColors.emergencyRed, fontWeight: FontWeight.bold),
                                ),
                              )),
                        ],
                      ),
                  ],
                ),
              ),

              // ==========================================
              // PATIENT NAME WARNING BANNER (SCAN)
              // ==========================================
              if (_nameWarningType == 'mismatch') ...[
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BaustColors.emergencyRed, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: BaustColors.emergencyRed, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Name on document does not match this patient - verify before issuing.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: BaustColors.emergencyRed,
                              ),
                            ),
                            if (_extractedPatientName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Document Name: $_extractedPatientName • Current Patient: ${widget.studentName}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_nameWarningType == 'not_found') ...[
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF78350F), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No patient name found on document.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // ==========================================
              // SCAN PAPER PRESCRIPTION BUTTON
              // ==========================================
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  side: const BorderSide(color: BaustColors.primaryArmyGreen, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Colors.white,
                  foregroundColor: BaustColors.primaryArmyGreen,
                ),
                icon: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BaustColors.primaryArmyGreen,
                        ),
                      )
                    : const Icon(Icons.document_scanner_outlined, size: 20),
                label: Text(
                  _isScanning ? 'Analyzing Paper Prescription with Gemini AI...' : 'Scan Paper Prescription',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: _isScanning ? null : _handleScanPrescription,
              ),

              if (_isScanning) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: BaustColors.primaryNavy),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Processing handwritten / printed prescription in memory via Gemini AI...',
                          style: TextStyle(fontSize: 12, color: BaustColors.primaryNavy, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // ==========================================
              // DIAGNOSIS FIELD (REQUIRED)
              // ==========================================
              Row(
                children: [
                  const Text('Clinical Diagnosis *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BaustColors.textDark)),
                  const SizedBox(width: 8),
                  if (_isDiagnosisAiExtracted) _buildAiBadge(),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _diagnosisController,
                decoration: InputDecoration(
                  hintText: 'e.g., Acute Pharyngitis, Viral Fever, Gastritis',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Diagnosis is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ==========================================
              // MEDICINES SECTION (1..20)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Prescribed Medicines',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: BaustColors.textDark),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Medicine'),
                    onPressed: _medicineRows.length < 20 ? _addMedicineRow : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              for (int i = 0; i < _medicineRows.length; i++) ...[
                _buildMedicineCard(i, _medicineRows[i]),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 12),

              // ==========================================
              // ADVICE (OPTIONAL)
              // ==========================================
              Row(
                children: [
                  const Text('Advice / Instructions (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BaustColors.textDark)),
                  const SizedBox(width: 8),
                  if (_isAdviceAiExtracted) _buildAiBadge(),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _adviceController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Complete the full antibiotic course. Drink plenty of water.',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 14),

              // ==========================================
              // FOLLOW-UP DATE (OPTIONAL)
              // ==========================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: BaustColors.primaryArmyGreen, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Follow-up Consultation',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                if (_isFollowUpAiExtracted) _buildAiBadge(),
                              ],
                            ),
                            Text(
                              _selectedFollowUpDate != null
                                  ? '${_selectedFollowUpDate!.day}/${_selectedFollowUpDate!.month}/${_selectedFollowUpDate!.year}'
                                  : 'Not scheduled',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _pickFollowUpDate,
                      child: Text(_selectedFollowUpDate != null ? 'Change Date' : 'Set Date'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // ISSUE PRESCRIPTION BUTTON
              // ==========================================
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BaustColors.primaryArmyGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting ? 'Issuing Prescription...' : 'Issue Prescription',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSubmitting ? null : _handleIssuePrescription,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineCard(int index, MedicineRowData row) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.conflictResult.hasConflict ? BaustColors.emergencyRed : Colors.grey.shade300,
          width: row.conflictResult.hasConflict ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medicine #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BaustColors.primaryNavy),
              ),
              if (_medicineRows.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeMedicineRow(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Medicine Name
          Row(
            children: [
              const Text('Medicine Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              if (row.isNameAiExtracted) _buildAiBadge(),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: row.nameController,
            decoration: InputDecoration(
              hintText: 'e.g. Amoxicillin 500mg, Napa 500mg',
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Medicine name required';
              }
              return null;
            },
          ),

          // Allergy Conflict Banner on Row
          if (row.conflictResult.hasConflict) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BaustColors.emergencyRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: BaustColors.emergencyRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Possible allergy conflict: patient reported ${row.conflictResult.matchedAllergy} (AI-extracted, unverified - confirm with patient)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: BaustColors.emergencyRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Dose, Frequency, Duration Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        const Text('Dose *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        if (row.isDoseAiExtracted) _buildAiBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: row.doseController,
                      decoration: InputDecoration(
                        hintText: '1 tab',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        const Text('Frequency *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        if (row.isFrequencyAiExtracted) _buildAiBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: row.frequencyController,
                      decoration: InputDecoration(
                        hintText: '1+0+1',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        const Text('Duration *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        if (row.isDurationAiExtracted) _buildAiBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: row.durationController,
                      decoration: InputDecoration(
                        hintText: '5 days',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Instructions (Optional)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              const Text('Instructions (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              if (row.isInstructionsAiExtracted) _buildAiBadge(),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: row.instructionsController,
            decoration: InputDecoration(
              hintText: 'e.g. After meals / with water',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
