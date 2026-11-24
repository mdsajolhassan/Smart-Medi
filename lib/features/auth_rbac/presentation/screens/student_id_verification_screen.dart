import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/document_scan_widgets.dart';
import '../../../medical_onboarding_ai/data/services/gemini_ai_service.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../controllers/auth_controller.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../../features/admin_portal/presentation/screens/feedback_screens.dart';

/// Max encoded photo size stored in Firestore (doc limit is 1 MiB).
const int kMaxIdPhotoBytes = 650 * 1024;

class PickedIdPhoto {
  final Uint8List bytes;
  final String name;
  const PickedIdPhoto(this.bytes, this.name);

  String get mimeType => name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
}

/// First-time student gate: the account stays inactive until a BAUST admin
/// approves a photo of the student's ID card.
class StudentIdVerificationScreen extends ConsumerStatefulWidget {
  final Future<PickedIdPhoto?> Function(bool fromCamera)? onPickOverride;
  final Future<Map<String, dynamic>> Function(PickedIdPhoto photo)? onAnalyzeOverride;
  final Future<void> Function(PickedIdPhoto photo, Map<String, dynamic>? aiCheck)? onSubmitOverride;

  /// Listen to Firestore for the admin decision (disabled in widget tests).
  final bool watchReview;

  const StudentIdVerificationScreen({
    super.key,
    this.onPickOverride,
    this.onAnalyzeOverride,
    this.onSubmitOverride,
    this.watchReview = true,
  });

  @override
  ConsumerState<StudentIdVerificationScreen> createState() => _StudentIdVerificationScreenState();
}

class _StudentIdVerificationScreenState extends ConsumerState<StudentIdVerificationScreen> {
  PickedIdPhoto? _photo;
  Map<String, dynamic>? _aiCheck;
  bool _checking = false;
  bool _submitting = false;
  bool _resubmitting = false;
  String? _aiError;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _reviewSub;

  @override
  void initState() {
    super.initState();
    if (widget.watchReview) _watchReview();
  }

  void _watchReview() {
    final uid = ref.read(authControllerProvider).userProfile?.uid;
    if (uid == null) return;
    try {
      _reviewSub = FirebaseFirestore.instance.collection('id_verifications').doc(uid).snapshots().listen((snap) {
        final status = snap.data()?['status'];
        final current = ref.read(authControllerProvider).userProfile?.idVerificationStatus;
        if (status is String && status != 'pending' && status != current) {
          ref.read(authControllerProvider.notifier).reloadUser();
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _reviewSub?.cancel();
    super.dispose();
  }

  bool get _canUseCamera =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pick(bool fromCamera) async {
    try {
      PickedIdPhoto? photo;
      if (widget.onPickOverride != null) {
        photo = await widget.onPickOverride!(fromCamera);
      } else {
        final x = await ImagePicker().pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1400,
          maxHeight: 1400,
          imageQuality: 72,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (x != null) {
          var name = x.name.isNotEmpty ? x.name : 'student_id.jpg';
          if (!RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(name)) name = '$name.jpg';
          photo = PickedIdPhoto(await x.readAsBytes(), name);
        }
      }
      if (photo == null || !mounted) return;
      if (photo.bytes.length > kMaxIdPhotoBytes) {
        _snack(
          'Photo is too large (${(photo.bytes.length / 1024).round()} KB). Please crop or retake it closer to the card.',
          error: true,
        );
        return;
      }
      setState(() {
        _photo = photo;
        _aiCheck = null;
        _aiError = null;
      });
      await _runAiCheck();
    } catch (e) {
      _snack('Could not open the photo: $e', error: true);
    }
  }

  Future<void> _runAiCheck() async {
    final photo = _photo;
    final user = ref.read(authControllerProvider).userProfile;
    if (photo == null || user == null) return;
    setState(() => _checking = true);
    try {
      final card = widget.onAnalyzeOverride != null
          ? await widget.onAnalyzeOverride!(photo)
          : await GeminiAiService().analyzeStudentIdCard(fileName: photo.name, fileBytes: photo.bytes);
      if (!mounted) return;
      setState(() {
        _aiCheck = GeminiAiService.compareIdCardWithProfile(
          card,
          profileName: user.displayName,
          profileStudentId: user.studentRoll,
        );
      });
    } catch (e) {
      if (!mounted) return;
      // AI is only a helper; the admin still reviews, so submission stays possible.
      setState(() => _aiError = 'Automatic check unavailable — an admin will review the photo manually.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null) return;
    if (_aiCheck != null && _aiCheck!['isIdCard'] != true) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('This may not be an ID card'),
          content: const Text('The automatic check could not find a student ID card in this photo. Submit anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retake')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit anyway')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _submitting = true);
    try {
      if (widget.onSubmitOverride != null) {
        await widget.onSubmitOverride!(photo, _aiCheck);
      } else {
        await ref
            .read(authControllerProvider.notifier)
            .submitStudentIdVerification(
              imageBase64: base64Encode(photo.bytes),
              mimeType: photo.mimeType,
              aiCheck: _aiCheck,
            );
      }
      if (!mounted) return;
      setState(() {
        _photo = null;
        _resubmitting = false;
      });
      _snack('Submitted! You will get access once an admin verifies your ID.');
    } catch (e) {
      _snack('Submission failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: error ? BaustColors.emergencyRed : BaustColors.successGreen, content: Text(msg)),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).userProfile;
    final status = user?.idVerificationStatus ?? 'not_submitted';
    final showUpload = status == 'not_submitted' || status == 'rejected' || _resubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Student ID'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.manage_accounts_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          const FeedbackIconButton(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _stepper(status),
            const SizedBox(height: 16),
            if (status == 'rejected' && !_resubmitting) _rejectedBanner(user?.idReviewNote),
            if (status == 'pending' && !_resubmitting) _pendingCard(user),
            if (showUpload) ...[if (status == 'rejected') const SizedBox(height: 12), _uploadCard(user)],
          ],
        ),
      ),
    );
  }

  Widget _stepper(String status) {
    final step = switch (status) {
      'pending' => 1,
      'verified' => 2,
      _ => 0,
    };
    Widget dot(int i, String label, IconData icon) {
      final done = i < step;
      final active = i == step;
      final color = done || active ? BaustColors.primaryArmyGreen : Colors.grey.shade400;
      return Expanded(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? BaustColors.primaryArmyGreen
                    : (active ? color.withValues(alpha: 0.12) : Colors.grey.shade100),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(done ? Icons.check_rounded : icon, size: 20, color: done ? Colors.white : color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            dot(0, 'Upload ID card', Icons.badge_outlined),
            dot(1, 'Admin review', Icons.hourglass_top_rounded),
            dot(2, 'Account active', Icons.verified_rounded),
          ],
        ),
      ),
    );
  }

  Widget _uploadCard(UserProfile? user) {
    final photo = _photo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload your BAUST student ID card',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Your account becomes active after an admin matches the card with your profile '
              '(${user?.displayName ?? ''}${(user?.studentRoll ?? '').isNotEmpty ? ' • ID ${user!.studentRoll}' : ''}).',
              style: const TextStyle(fontSize: 12.5, color: BaustColors.textMuted),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: photo == null
                  ? _emptyDropZone()
                  : ClipRRect(
                      key: const ValueKey('preview'),
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(photo.bytes, height: 220, fit: BoxFit.cover, gaplessPlayback: true),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_canUseCamera) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : () => _pick(true),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _pick(false),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(photo == null ? 'Choose photo' : 'Change photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _Tips(),
            if (_checking) ...[
              const SizedBox(height: 12),
              const AiScanProgress(
                compact: true,
                title: 'Checking your ID card',
                steps: ['Reading the card', 'Matching name & student ID', 'Checking photo quality'],
              ),
            ],
            if (!_checking && _aiCheck != null) ...[const SizedBox(height: 12), IdAiCheckSummary(_aiCheck!)],
            if (!_checking && _aiError != null) ...[
              const SizedBox(height: 12),
              Text(_aiError!, style: const TextStyle(fontSize: 12, color: BaustColors.textMuted)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: photo == null || _checking || _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Submitting…' : 'Submit for Verification'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyDropZone() => InkWell(
    key: const ValueKey('empty'),
    borderRadius: BorderRadius.circular(16),
    onTap: () => _pick(_canUseCamera),
    child: Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: BaustColors.primaryArmyGreen.withValues(alpha: 0.05),
        border: Border.all(color: BaustColors.primaryArmyGreen.withValues(alpha: 0.3), width: 1.5),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_rounded, size: 48, color: BaustColors.primaryArmyGreen),
          SizedBox(height: 8),
          Text(
            'Tap to add a photo of the front of your ID card',
            style: TextStyle(fontWeight: FontWeight.w700, color: BaustColors.armyGreenDark),
          ),
        ],
      ),
    ),
  );

  Widget _pendingCard(UserProfile? user) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber.shade50),
            child: Icon(Icons.hourglass_top_rounded, size: 40, color: Colors.amber.shade800),
          ),
          const SizedBox(height: 14),
          const Text('ID card under review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'A BAUST admin is checking your student ID. This page updates automatically once you are approved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: BaustColors.textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => ref.read(authControllerProvider.notifier).reloadUser(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check status'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _resubmitting = true),
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Upload a different photo'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _rejectedBanner(String? note) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade200),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: BaustColors.emergencyRed),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verification was not approved',
                style: TextStyle(fontWeight: FontWeight.w800, color: BaustColors.emergencyRed),
              ),
              const SizedBox(height: 4),
              Text(
                (note != null && note.trim().isNotEmpty) ? 'Reason: $note' : 'Please upload a clearer photo of your own BAUST ID card. Make sure your profile name and student ID match the card.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    Widget tip(IconData i, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(i, size: 15, color: BaustColors.armyGreenLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t, style: const TextStyle(fontSize: 12, color: BaustColors.textMuted)),
          ),
        ],
      ),
    );
    return Column(
      children: [
        tip(Icons.light_mode_outlined, 'Good light, no glare on the card'),
        tip(Icons.crop_free_rounded, 'Whole card visible, name and ID readable'),
        tip(Icons.no_photography_outlined, 'Original card only — no screenshots or photocopies'),
      ],
    );
  }
}

class IdAiCheckSummary extends StatelessWidget {
  final Map<String, dynamic> check;
  const IdAiCheckSummary(this.check, {super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(bool ok, String label, [String? detail]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 18,
            color: ok ? BaustColors.successGreen : Colors.amber.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  if (detail != null && detail.isNotEmpty)
                    TextSpan(
                      text: '  $detail',
                      style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final good = check['looksValid'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: good ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AiPill(label: 'AI pre-check'),
              const SizedBox(width: 8),
              Text(
                good ? 'Looks good' : 'Needs attention',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: good ? BaustColors.successGreen : Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row(check['isIdCard'] == true, 'Student ID card detected'),
          row(check['isBaust'] == true, 'Issued by BAUST'),
          row(check['nameMatch'] == true, 'Name matches profile', check['cardName']?.toString()),
          row(check['idMatch'] == true, 'Student ID matches profile', check['cardStudentId']?.toString()),
          if (check['notes'] != null && check['notes'].toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: ${check['notes']}',
                style: const TextStyle(fontSize: 11.5, color: BaustColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
