import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../auth_rbac/presentation/screens/student_id_verification_screen.dart';
import '../../../../core/widgets/responsive.dart';

/// Admin queue for approving/rejecting student ID card submissions.
class IdVerificationReviewScreen extends ConsumerStatefulWidget {
  /// Test hook: supplies submissions instead of Firestore.
  final Stream<List<Map<String, dynamic>>> Function(String status)? streamOverride;
  final Future<void> Function(String uid, bool approve, String? note)? onReviewOverride;

  const IdVerificationReviewScreen({super.key, this.streamOverride, this.onReviewOverride});

  @override
  ConsumerState<IdVerificationReviewScreen> createState() => _IdVerificationReviewScreenState();
}

class _IdVerificationReviewScreenState extends ConsumerState<IdVerificationReviewScreen> {
  String _status = 'pending';
  final Set<String> _busy = {};

  Stream<List<Map<String, dynamic>>> _stream() {
    if (widget.streamOverride != null) return widget.streamOverride!(_status);
    return FirebaseFirestore.instance
        .collection('id_verifications')
        .where('status', isEqualTo: _status)
        .limit(100)
        .snapshots()
        .map((q) {
          final list = q.docs.map((d) => {...d.data(), 'uid': d.id}).toList();
          int ts(Map m) => (m['submittedAt'] is Timestamp) ? (m['submittedAt'] as Timestamp).millisecondsSinceEpoch : 0;
          list.sort((a, b) => _status == 'pending' ? ts(a).compareTo(ts(b)) : ts(b).compareTo(ts(a)));
          return list;
        });
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    String? note;
    if (!approve) {
      note = await _askReason();
      if (note == null) return;
    }
    final uid = item['uid'] as String;
    setState(() => _busy.add(uid));
    try {
      if (widget.onReviewOverride != null) {
        await widget.onReviewOverride!(uid, approve, note);
      } else {
        await ref
            .read(authControllerProvider.notifier)
            .reviewStudentIdVerification(studentUid: uid, approve: approve, note: note);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: approve ? BaustColors.successGreen : BaustColors.emergencyRed,
          content: Text('${item['displayName'] ?? 'Student'} ${approve ? 'verified' : 'rejected'}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  Future<String?> _askReason() {
    final c = TextEditingController();
    const presets = [
      'Photo is blurry or unreadable',
      'Name does not match profile',
      'Student ID does not match profile',
      'Not a BAUST student ID card',
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Reject ID card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in presets) ActionChip(label: Text(p), onPressed: () => setD(() => c.text = p)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason shown to the student'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: BaustColors.emergencyRed),
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student ID Verification')),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', icon: Icon(Icons.hourglass_top_rounded), label: Text('Pending')),
                  ButtonSegment(value: 'verified', icon: Icon(Icons.verified_rounded), label: Text('Verified')),
                  ButtonSegment(value: 'rejected', icon: Icon(Icons.block_rounded), label: Text('Rejected')),
                ],
                selected: {_status},
                onSelectionChanged: (s) => setState(() => _status = s.first),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(_status),
                stream: _stream(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Could not load submissions: ${snap.error}'));
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _status == 'pending' ? 'No ID cards waiting for review' : 'Nothing here yet',
                            style: const TextStyle(color: BaustColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _card(items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final uid = item['uid'] as String;
    final busy = _busy.contains(uid);
    Uint8List? img;
    final b64 = item['imageBase64'];
    if (b64 is String && b64.isNotEmpty) {
      try {
        img = base64Decode(b64);
      } catch (_) {}
    }
    final ai = item['aiCheck'];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (img != null)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(img!))),
              ),
              child: Image.memory(img, height: 200, fit: BoxFit.cover),
            )
          else
            Container(
              height: 56,
              color: const Color(0xFFF4F1FA),
              alignment: Alignment.center,
              child: const Text('Photo removed after review', style: TextStyle(color: BaustColors.textMuted)),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['displayName']?.toString() ?? 'Student',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID ${item['studentRoll'] ?? '—'}  •  ${item['department'] ?? '—'}',
                  style: const TextStyle(fontSize: 12.5, color: BaustColors.textMuted),
                ),
                Text(
                  item['email']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                ),
                if (ai is Map) ...[const SizedBox(height: 10), IdAiCheckSummary(Map<String, dynamic>.from(ai))],
                if ((item['reviewNote'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Note: ${item['reviewNote']}', style: const TextStyle(fontSize: 12.5)),
                ],
                if (_status == 'pending') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: BaustColors.emergencyRed),
                          onPressed: busy ? null : () => _review(item, false),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => _review(item, true),
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
