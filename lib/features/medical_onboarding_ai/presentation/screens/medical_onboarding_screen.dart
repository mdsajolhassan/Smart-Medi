import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../data/services/gemini_ai_service.dart';

enum OnboardingStep { selectDocument, analyzing, reviewSummary, completing }

class MedicalOnboardingScreen extends ConsumerStatefulWidget {
  final OnboardingStep? initialStep;
  final ExtractedMedicalData? initialData;

  const MedicalOnboardingScreen({
    super.key,
    this.initialStep,
    this.initialData,
  });

  @override
  ConsumerState<MedicalOnboardingScreen> createState() => _MedicalOnboardingScreenState();
}

class _MedicalOnboardingScreenState extends ConsumerState<MedicalOnboardingScreen> {
  final GeminiAiService _aiService = GeminiAiService();

  late OnboardingStep _currentStep;
  PlatformFile? _selectedFile;
  int _analysisStage = 0;
  bool _confirmEmptyRecord = false;
  Timer? _cooldownTimer;
  int _retryCooldownSeconds = 0;

  ExtractedMedicalData? _extractedData;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep ?? OnboardingStep.selectDocument;
    _extractedData = widget.initialData;
  }

  @override
  void didUpdateWidget(covariant MedicalOnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData) {
      _extractedData = widget.initialData;
    }
    if (widget.initialStep != oldWidget.initialStep && widget.initialStep != null) {
      _currentStep = widget.initialStep!;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer([int seconds = 30]) {
    _cooldownTimer?.cancel();
    setState(() {
      _retryCooldownSeconds = seconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_retryCooldownSeconds > 1) {
          _retryCooldownSeconds--;
        } else {
          _retryCooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _resetDocumentSelection() {
    setState(() {
      _selectedFile = null;
      _extractedData = null;
      _currentStep = OnboardingStep.selectDocument;
      _confirmEmptyRecord = false;
      _analysisStage = 0;
    });
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Crucial for web to get file bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        const maxBytes = 5 * 1024 * 1024; // 5 MB
        if (picked.size > maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: BaustColors.emergencyRed,
              content: Text('File is larger than 5 MB. Please upload a smaller file.'),
            ),
          );
          return;
        }

        setState(() {
          _selectedFile = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('Error selecting file: $e'),
        ),
      );
    }
  }

  Future<void> _startAiAnalysis() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('Please select or upload a medical document first.'),
        ),
      );
      return;
    }

    const maxBytes = 5 * 1024 * 1024; // 5 MB
    if (_selectedFile!.size > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('File is larger than 5 MB. Please upload a smaller file.'),
        ),
      );
      return;
    }

    final fileBytes = _selectedFile!.bytes;
    if (fileBytes == null || fileBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('File content could not be read into memory. Please re-select the file.'),
        ),
      );
      return;
    }

    setState(() {
      _currentStep = OnboardingStep.analyzing;
      _analysisStage = 1;
    });

    // Simulate multi-stage visual progression
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _analysisStage = 2);

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _analysisStage = 3);

    try {
      final result = await _aiService.analyzeMedicalDocument(
        fileName: _selectedFile!.name,
        fileSizeBytes: _selectedFile!.size,
        fileBytes: fileBytes,
      );

      if (!mounted) return;
      setState(() {
        _extractedData = result;
        _currentStep = OnboardingStep.reviewSummary;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentStep = OnboardingStep.selectDocument;
      });
      _startCooldownTimer(30);
      final friendlyMsg = GeminiAiService.mapErrorToUserFriendlyMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(friendlyMsg),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _currentStep = OnboardingStep.completing);

    await ref.read(authControllerProvider.notifier).completeOnboarding(
          medicalData: _extractedData,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: BaustColors.successGreen,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Medical Onboarding Complete! Emergency SOS activated.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: const Text('AI Medical History Onboarding'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Progress / Stepper Card
            _buildHeaderBanner(),

            const SizedBox(height: 20),

            if (_currentStep == OnboardingStep.selectDocument)
              _buildUploadCard(),

            if (_currentStep == OnboardingStep.analyzing)
              _buildAnalyzingState(),

            if (_currentStep == OnboardingStep.reviewSummary ||
                _currentStep == OnboardingStep.completing)
              _buildSummaryView(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BaustColors.primaryNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: BaustColors.primaryNavy, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BAUST Smart Medi Onboarding',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 2),
                Text(
                  'Upload clinical documents for automated Gemini 2.0 extraction.',
                  style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    final hasFile = _selectedFile != null;
    final fileName = _selectedFile?.name ?? '';
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final fileSizeKb = hasFile ? (_selectedFile!.size / 1024).toStringAsFixed(1) : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STEP 1: SELECT MEDICAL DOCUMENT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: BaustColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),

        // Clickable Upload Box
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _pickDocument,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFile
                      ? BaustColors.successGreen
                      : BaustColors.primaryNavy.withValues(alpha: 0.3),
                  width: hasFile ? 2 : 1.5,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasFile
                          ? BaustColors.successGreen.withValues(alpha: 0.1)
                          : BaustColors.primaryNavy.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasFile
                          ? (isPdf ? Icons.picture_as_pdf : Icons.image)
                          : Icons.cloud_upload_outlined,
                      size: 48,
                      color: hasFile ? BaustColors.successGreen : BaustColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasFile ? 'Document Selected' : 'Upload Past Prescriptions / Medical Records',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasFile
                        ? 'Tap here to change or re-select file'
                        : 'Tap here to browse PDF, JPG, or PNG from your device',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                  ),
                  const SizedBox(height: 18),

                  if (hasFile) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: BaustColors.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.image,
                            color: isPdf ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$fileSizeKb KB • Ready for AI extraction',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: BaustColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: BaustColors.successGreen,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _pickDocument,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Browse Files on Device'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BaustColors.primaryNavy,
                        side: const BorderSide(color: BaustColors.primaryNavy),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _retryCooldownSeconds > 0
                ? Colors.grey.shade400
                : BaustColors.primaryNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(_retryCooldownSeconds > 0 ? Icons.timer_outlined : Icons.auto_awesome),
          label: Text(
            _retryCooldownSeconds > 0
                ? 'TRY AGAIN (${_retryCooldownSeconds}s)'
                : 'ANALYZE WITH GEMINI AI',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          onPressed: _retryCooldownSeconds > 0 ? null : _startAiAnalysis,
        ),
      ],
    );
  }

  Widget _buildAnalyzingState() {
    final stages = [
      'Preparing document for processing...',
      'Uploading binary to secure medical storage...',
      'Gemini 2.0 Flash analyzing handwriting and diagnoses...',
      'Structuring clinical issues and active medications...',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              height: 56,
              width: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: BaustColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Medical Analysis in Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              stages[_analysisStage],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: BaustColors.navyLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: (_analysisStage + 1) / stages.length,
              backgroundColor: const Color(0xFFE2E8F0),
              color: BaustColors.primaryNavy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    final data = _extractedData;
    if (data == null) return const SizedBox.shrink();

    // Problem 1 fix: Non-medical or unreadable files must not show a clinical summary
    if (!data.isMedicalDocument) {
      return _buildNonMedicalDocumentView(data);
    }

    final isCompleting = _currentStep == OnboardingStep.completing;
    final hasDrugAllergies = data.drugAllergies.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header without confidence score
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'EXTRACTED CLINICAL SUMMARY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: BaustColors.textMuted,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BaustColors.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: BaustColors.primaryNavy),
                  SizedBox(width: 4),
                  Text(
                    'Strict Document Extraction',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: BaustColors.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Problem 2 fix: Blood Group Card with source identification & unverified status chip
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.bloodGroup ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: BaustColors.emergencyRed,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blood Group (as written in document)',
                        style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.bloodGroup != null
                            ? 'Group: ${data.bloodGroup}'
                            : 'Not found - confirm with patient',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.navyDark,
                        ),
                      ),
                      if (data.bloodGroup != null) ...[
                        const SizedBox(height: 4),
                        if (data.bloodGroupSource == 'lab_report')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              'From lab report',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'Unverified - confirm with a lab test',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // SECTION: CATEGORIZED ALLERGIES (Drug, Food, Environmental)
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: hasDrugAllergies
                  ? BaustColors.emergencyRed.withValues(alpha: 0.6)
                  : Colors.grey.shade300,
              width: hasDrugAllergies ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasDrugAllergies
                          ? Icons.warning_rounded
                          : Icons.shield_outlined,
                      color: hasDrugAllergies
                          ? BaustColors.emergencyRed
                          : BaustColors.primaryNavy,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Allergies by Category',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 18),

                // 1. Drug Allergies (Critical)
                _buildAllergyCategory(
                  title: 'Drug Allergies (Critical Alert)',
                  items: data.drugAllergies,
                  isCritical: true,
                  icon: Icons.medication_liquid_rounded,
                ),

                const SizedBox(height: 12),

                // 2. Food Allergies
                _buildAllergyCategory(
                  title: 'Food Allergies',
                  items: data.foodAllergies,
                  isCritical: false,
                  icon: Icons.restaurant_rounded,
                ),

                const SizedBox(height: 12),

                // 3. Environmental Allergies
                _buildAllergyCategory(
                  title: 'Environmental Allergies',
                  items: data.environmentalAllergies,
                  isCritical: false,
                  icon: Icons.air_rounded,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // SECTION: CHRONIC CONDITIONS
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medical_information_outlined, color: BaustColors.primaryNavy),
                    SizedBox(width: 8),
                    Text(
                      'Chronic Conditions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (data.chronicConditions.isEmpty)
                  const Text(
                    'Not found - confirm with patient',
                    style: TextStyle(fontSize: 13, color: BaustColors.textMuted, fontStyle: FontStyle.italic),
                  )
                else
                  ...data.chronicConditions.map((condition) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Expanded(
                            child: Text(
                              condition,
                              style: const TextStyle(fontSize: 13, color: BaustColors.textDark, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // SECTION: MEDICATIONS (FROM DOCUMENT)
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medication_rounded, color: BaustColors.primaryNavy),
                    SizedBox(width: 8),
                    Text(
                      'Medications (from document)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (data.currentMedications.isEmpty)
                  const Text(
                    'Not found - confirm with patient',
                    style: TextStyle(fontSize: 13, color: BaustColors.textMuted, fontStyle: FontStyle.italic),
                  )
                else
                  ...data.currentMedications.map((med) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BaustColors.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.medication_outlined, color: BaustColors.primaryNavy, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        med.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    _buildMedicationStatusChip(med.status),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dose: ${med.dose.isNotEmpty ? med.dose : "Unspecified"} • Frequency: ${med.frequency.isNotEmpty ? med.frequency : "Unspecified"}',
                                  style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                                ),
                                if (med.prescribedDisplay != null && med.prescribedDisplay!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    med.prescribedDisplay!,
                                    style: const TextStyle(fontSize: 11, color: BaustColors.textDark),
                                  ),
                                ] else if (med.prescribedDate != null && med.prescribedDate!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Prescribed: ${med.prescribedDate}',
                                    style: const TextStyle(fontSize: 11, color: BaustColors.textDark),
                                  ),
                                ],
                                if (med.durationText != null && med.durationText!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Duration: ${med.durationText}',
                                    style: const TextStyle(fontSize: 11, color: BaustColors.textDark),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // SECTION: ABNORMAL LABS
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.biotech_outlined, color: BaustColors.primaryNavy),
                    SizedBox(width: 8),
                    Text(
                      'Abnormal Lab Findings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (data.abnormalLabs.isEmpty)
                  const Text(
                    'Not found - confirm with patient',
                    style: TextStyle(fontSize: 13, color: BaustColors.textMuted, fontStyle: FontStyle.italic),
                  )
                else
                  ...data.abnormalLabs.map((lab) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lab,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // SECTION: SURGERIES AND HOSPITAL ADMISSIONS
        if (data.procedures.isNotEmpty || data.hospitalAdmissions.isNotEmpty) ...[
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_hospital_outlined, color: BaustColors.primaryNavy),
                      SizedBox(width: 8),
                      Text(
                        'Surgeries and Hospital Admissions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  ...data.procedures.map((proc) {
                    final procText = proc.date != null && proc.date!.isNotEmpty
                        ? '${proc.name} - ${proc.date}'
                        : proc.name;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.healing_outlined, color: BaustColors.primaryNavy, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              procText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BaustColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ...data.hospitalAdmissions.map((adm) {
                    String admText;
                    if (adm.admitDate != null && adm.dischargeDate != null) {
                      admText = 'Admitted ${adm.admitDate} - ${adm.dischargeDate}';
                    } else if (adm.admitDate != null) {
                      admText = 'Admitted ${adm.admitDate}';
                    } else if (adm.dischargeDate != null) {
                      admText = 'Discharged ${adm.dischargeDate}';
                    } else {
                      admText = 'Hospital Admission';
                    }
                    if (adm.reason != null && adm.reason!.isNotEmpty) {
                      admText = '$admText, ${adm.reason}';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.hotel_outlined, color: BaustColors.primaryNavy, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              admText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BaustColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // SECTION: PAST VISITS
        if (data.pastVisits.isNotEmpty) ...[
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_edu_outlined, color: BaustColors.primaryNavy),
                      SizedBox(width: 8),
                      Text(
                        'Past Clinical Visits',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  ...data.pastVisits.map((visit) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.event_note, color: BaustColors.primaryNavy, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${visit.date}: ${visit.diagnosis}',
                              style: const TextStyle(fontSize: 13, color: BaustColors.textDark),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // SECTION: DOCTOR'S ADVICE & FOLLOW-UP
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, color: BaustColors.primaryNavy),
                    SizedBox(width: 8),
                    Text(
                      "Doctor's Advice & Follow-up",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 18),
                Text(
                  (data.doctorAdvice != null && data.doctorAdvice!.trim().isNotEmpty)
                      ? data.doctorAdvice!.trim()
                      : 'No specific advice or follow-up documented.',
                  style: TextStyle(
                    fontSize: 13,
                    color: (data.doctorAdvice != null && data.doctorAdvice!.trim().isNotEmpty)
                        ? BaustColors.textDark
                        : BaustColors.textMuted,
                    fontStyle: (data.doctorAdvice != null && data.doctorAdvice!.trim().isNotEmpty)
                        ? FontStyle.normal
                        : FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                if (data.followUps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, color: BaustColors.primaryNavy, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Scheduled Follow-ups',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...data.followUps.map((fu) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📅 ', style: TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              fu.displayText.isNotEmpty ? fu.displayText : 'Follow-up scheduled',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BaustColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // SECTION: BLOOD DONATION STATUS (HARDCODED CLINICAL SAFETY)
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.amber.shade400,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Blood Donation Status',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PENDING REVIEW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                const Text(
                  'Pending Clinical Screening (Requires Manual Staff Review)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: BaustColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'For student and patient safety, automated AI eligibility decisions are disabled. Blood donor qualification must be evaluated in-person by BAUST Medical Center medical officers.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Problem 2 Guard: Require explicit user confirmation if document has zero clinical details
        if (data.hasNoClinicalDetails) ...[
          Card(
            elevation: 1,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.amber.shade400, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No clinical details were found in this file',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No allergies, medications, blood group, or clinical history could be extracted from this document.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _confirmEmptyRecord,
                    activeColor: BaustColors.primaryNavy,
                    onChanged: (val) {
                      setState(() {
                        _confirmEmptyRecord = val ?? false;
                      });
                    },
                    title: const Text(
                      'I confirm this file contains no clinical details and wish to proceed.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Save & Continue Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: BaustColors.primaryNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: isCompleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(
            isCompleting ? 'SAVING PROFILE...' : 'SAVE & CONTINUE TO SOS PORTAL',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          onPressed: isCompleting || (data.hasNoClinicalDetails && !_confirmEmptyRecord)
              ? null
              : _saveAndContinue,
        ),
      ],
    );
  }

  /// Displays red error card for non-medical or unreadable documents
  Widget _buildNonMedicalDocumentView(ExtractedMedicalData data) {
    final bool isUnreadable = data.documentType == 'unreadable';
    final String errorTitle = isUnreadable
        ? 'We could not read this file'
        : 'This does not look like a medical document';
    final String errorBody = isUnreadable
        ? 'Please upload a clearer photo or PDF.'
        : 'This looks like a non-medical document such as a CV, invoice or ID card.';

    if (kDebugMode && data.classificationReason.isNotEmpty) {
      debugPrint('[AI Document Rejection] Reason: ${data.classificationReason}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          color: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade300, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isUnreadable ? Icons.broken_image_outlined : Icons.gpp_bad_rounded,
                    color: BaustColors.emergencyRed,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        errorTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.emergencyRed,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        errorBody,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: BaustColors.primaryNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.upload_file),
          label: const Text(
            'Upload another file',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _resetDocumentSelection,
        ),
      ],
    );
  }

  Widget _buildAllergyCategory({
    required String title,
    required List<String> items,
    required bool isCritical,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical && items.isNotEmpty
            ? Colors.red.shade50
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCritical && items.isNotEmpty
              ? Colors.red.shade200
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isCritical && items.isNotEmpty
                    ? BaustColors.emergencyRed
                    : BaustColors.primaryNavy,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCritical && items.isNotEmpty
                      ? BaustColors.emergencyRed
                      : BaustColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            if (isCritical)
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Text(
                    'Not found - confirm with patient',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Not found - confirm with patient',
                style: TextStyle(fontSize: 12, color: BaustColors.textMuted, fontStyle: FontStyle.italic),
              )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCritical ? BaustColors.emergencyRed : BaustColors.textDark,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCritical ? FontWeight.bold : FontWeight.w500,
                          color: isCritical ? BaustColors.emergencyRed : BaustColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicationStatusChip(String status) {
    Color bg;
    Color border;
    Color textColor;

    switch (status) {
      case 'Course ended':
        bg = Colors.grey.shade100;
        border = Colors.grey.shade300;
        textColor = Colors.grey.shade700;
        break;
      case 'Ongoing / as needed':
        bg = Colors.blue.shade50;
        border = Colors.blue.shade300;
        textColor = Colors.blue.shade800;
        break;
      case 'Active':
        bg = Colors.green.shade50;
        border = Colors.green.shade300;
        textColor = Colors.green.shade800;
        break;
      case 'Prescribed date not stated':
        bg = Colors.grey.shade200;
        border = Colors.grey.shade400;
        textColor = Colors.grey.shade700;
        break;
      case 'Duration not stated':
      default:
        bg = Colors.amber.shade50;
        border = Colors.amber.shade300;
        textColor = Colors.amber.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
