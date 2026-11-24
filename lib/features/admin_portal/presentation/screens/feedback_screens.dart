import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../data/user_admin_service.dart';

const _types = {
  'bug': ('Report a bug', Icons.bug_report_rounded, Color(0xFFE11D48)),
  'feedback': ('Feedback', Icons.chat_bubble_rounded, Color(0xFF7C3AED)),
  'suggestion': ('Suggestion', Icons.lightbulb_rounded, Color(0xFFF59E0B)),
};

/// Any signed-in user can send feedback or report a bug.
class SendFeedbackScreen extends ConsumerStatefulWidget {
  final Future<void> Function(String type, String message)? onSubmitOverride;
  const SendFeedbackScreen({super.key, this.onSubmitOverride});

  @override
  ConsumerState<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends ConsumerState<SendFeedbackScreen> {
  final _msg = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _type = 'bug';
  bool _sending = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      if (widget.onSubmitOverride != null) {
        await widget.onSubmitOverride!(_type, _msg.text);
      } else {
        await FeedbackService().submit(
          user: ref.read(authControllerProvider).userProfile,
          type: _type,
          message: _msg.text,
          platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.successGreen,
          content: Text('Thanks! Your report was sent to the Smart Medi team.'),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(backgroundColor: BaustColors.emergencyRed, content: Text('Could not send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Bug Report')),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: Form(
          key: _form,
          child: ListView(
            padding: EdgeInsets.all(Breakpoints.gutter(context)),
            children: [
              const Text(
                'What would you like to tell us?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _types.entries)
                    ChoiceChip(
                      avatar: Icon(e.value.$2, size: 18, color: e.value.$3),
                      label: Text(e.value.$1),
                      selected: _type == e.key,
                      onSelected: (_) => setState(() => _type = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _msg,
                minLines: 6,
                maxLines: 12,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: _type == 'bug' ? 'What went wrong? Steps to reproduce help a lot.' : 'Your message',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v ?? '').trim().length < 10 ? 'Please write at least 10 characters' : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your name, role and device type are attached so we can follow up. Please don\'t include passwords or medical details.',
                style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending…' : 'Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Super admin inbox for feedback and bug reports.
class FeedbackInboxScreen extends ConsumerStatefulWidget {
  final Stream<List<Map<String, dynamic>>> Function(String status)? streamOverride;
  final Future<void> Function(String id, String status)? onSetStatusOverride;

  const FeedbackInboxScreen({super.key, this.streamOverride, this.onSetStatusOverride});

  @override
  ConsumerState<FeedbackInboxScreen> createState() => _FeedbackInboxScreenState();
}

class _FeedbackInboxScreenState extends ConsumerState<FeedbackInboxScreen> {
  String _status = 'open';
  String _type = 'all';

  Stream<List<Map<String, dynamic>>> _stream() =>
      widget.streamOverride?.call(_status) ?? FeedbackService().watch(_status);

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    final id = item['id'] as String;
    try {
      if (widget.onSetStatusOverride != null) {
        await widget.onSetStatusOverride!(id, status);
      } else {
        await FeedbackService().setStatus(id, status, by: ref.read(authControllerProvider).userProfile?.email);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).userProfile;
    if (user == null || !user.isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Super admins only')),
      );
    }
    final gutter = Breakpoints.gutter(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Bug Reports')),
      body: ResponsiveCenter(
        maxWidth: 1100,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'open', icon: Icon(Icons.inbox_rounded), label: Text('Open')),
                      ButtonSegment(value: 'resolved', icon: Icon(Icons.task_alt_rounded), label: Text('Resolved')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (s) => setState(() => _status = s.first),
                  ),
                  DropdownButton<String>(
                    value: _type,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All types')),
                      for (final e in _types.entries) DropdownMenuItem(value: e.key, child: Text(e.value.$1)),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'all'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(_status),
                stream: _stream(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Could not load: ${snap.error}'));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final items = snap.data!.where((i) => _type == 'all' || i['type'] == _type).toList();
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('Nothing here 🎉', style: TextStyle(color: BaustColors.textMuted)),
                    );
                  }
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
                    child: ResponsiveWrapGrid(
                      minTileWidth: 420,
                      maxColumns: 2,
                      children: [for (final i in items) _card(i)],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> i) {
    final t = _types[i['type']] ?? _types['feedback']!;
    final ts = i['createdAt'];
    final when = ts is Timestamp ? _fmt(ts.toDate()) : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(t.$2, color: t.$3, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.$1,
                  style: TextStyle(fontWeight: FontWeight.w800, color: t.$3),
                ),
                const Spacer(),
                Text(when, style: const TextStyle(fontSize: 11.5, color: BaustColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText((i['message'] ?? '').toString(), style: const TextStyle(fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 10),
            Text(
              '${i['displayName'] ?? ''} • ${i['role'] ?? ''} • ${i['email'] ?? ''}${(i['platform'] ?? '').toString().isNotEmpty ? ' • ${i['platform']}' : ''}',
              style: const TextStyle(fontSize: 11.5, color: BaustColors.textMuted),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _status == 'open'
                  ? FilledButton.tonalIcon(
                      onPressed: () => _setStatus(i, 'resolved'),
                      icon: const Icon(Icons.task_alt_rounded),
                      label: const Text('Mark resolved'),
                    )
                  : TextButton.icon(
                      onPressed: () => _setStatus(i, 'open'),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Reopen'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// App-bar button that opens the feedback / bug report form (goes to the super admin).
class FeedbackIconButton extends StatelessWidget {
  const FeedbackIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Report a bug / Send feedback',
      icon: const Icon(Icons.feedback_outlined),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SendFeedbackScreen())),
    );
  }
}
