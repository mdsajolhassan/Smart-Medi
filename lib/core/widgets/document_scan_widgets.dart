import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/baust_constants.dart';

/// Max upload size accepted by the AI pipeline.
const int kMaxScanBytes = 5 * 1024 * 1024;

enum _ScanSource { camera, gallery, files }

/// Shows a modern bottom sheet letting the user take a photo, choose an image,
/// or browse for a PDF/JPG/PNG. Photos are downscaled/compressed so handwritten
/// prescriptions stay legible while staying under [kMaxScanBytes].
Future<PlatformFile?> pickMedicalDocument(BuildContext context, {String title = 'Add a prescription'}) async {
  final canUseCamera =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  final source = await showModalBottomSheet<_ScanSource>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BaustColors.textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Handwritten or printed • lay the paper flat in good light',
              style: TextStyle(fontSize: 12.5, color: BaustColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (canUseCamera)
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                color: BaustColors.primaryArmyGreen,
                title: 'Take a photo',
                subtitle: 'Best for paper prescriptions',
                onTap: () => Navigator.pop(ctx, _ScanSource.camera),
              ),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF7C3AED),
              title: 'Choose from gallery',
              subtitle: 'JPG or PNG image',
              onTap: () => Navigator.pop(ctx, _ScanSource.gallery),
            ),
            _SourceTile(
              icon: Icons.upload_file_rounded,
              color: const Color(0xFF0284C7),
              title: 'Browse files',
              subtitle: 'PDF, JPG or PNG up to 5 MB',
              onTap: () => Navigator.pop(ctx, _ScanSource.files),
            ),
          ],
        ),
      ),
    ),
  );

  if (source == null) return null;

  if (source == _ScanSource.files) {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    return (result != null && result.files.isNotEmpty) ? result.files.first : null;
  }

  final image = await ImagePicker().pickImage(
    source: source == _ScanSource.camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 88,
  );
  if (image == null) return null;
  final bytes = await image.readAsBytes();
  var name = image.name.isNotEmpty ? image.name : 'prescription.jpg';
  if (!RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(name)) {
    name = '$name.jpg';
  }
  return PlatformFile(name: name, size: bytes.length, bytes: bytes);
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: BaustColors.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated, step-by-step progress shown while the AI reads a document.
/// Steps advance on a timer purely for feedback; the real request runs independently.
class AiScanProgress extends StatefulWidget {
  final List<String> steps;
  final String title;
  final bool compact;

  const AiScanProgress({
    super.key,
    this.title = 'Reading your prescription',
    this.steps = const [
      'Enhancing image',
      'Recognising handwriting',
      'Extracting medicines & dosage',
      'Structuring clinical details',
    ],
    this.compact = false,
  });

  @override
  State<AiScanProgress> createState() => _AiScanProgressState();
}

class _AiScanProgressState extends State<AiScanProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted && _step < widget.steps.length - 1) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.compact ? 16 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3EEFF), Color(0xFFEFF6FF)],
        ),
        border: Border.all(color: BaustColors.primaryArmyGreen.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BaustColors.primaryArmyGreen,
                    boxShadow: [
                      BoxShadow(
                        color: BaustColors.primaryArmyGreen.withValues(alpha: 0.35 * _pulse.value),
                        blurRadius: 6 + 14 * _pulse.value,
                        spreadRadius: 2 * _pulse.value,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BaustColors.textDark),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        '${widget.steps[_step]}…',
                        key: ValueKey(_step),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: BaustColors.armyGreenLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Color(0xFFE2E8F0),
              color: BaustColors.primaryArmyGreen,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < widget.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      i < _step
                          ? Icons.check_circle_rounded
                          : (i == _step ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                      key: ValueKey('$i-${i < _step}-${i == _step}'),
                      size: 18,
                      color: i <= _step ? BaustColors.successGreen : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.steps[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: i == _step ? FontWeight.w700 : FontWeight.w500,
                      color: i <= _step ? BaustColors.textDark : BaustColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small pill used to tag AI-produced values.
class AiPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const AiPill({super.key, required this.label, this.icon = Icons.auto_awesome, this.color = const Color(0xFF1D4ED8)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
