import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../data/user_admin_service.dart';

typedef CreateUserFn = Future<void> Function(Map<String, String> fields);

/// Admin / super-admin account management: add, change role, remove, restore.
/// Deliberately has no password or "open this user's dashboard" features.
class UserManagementScreen extends ConsumerStatefulWidget {
  final Stream<List<Map<String, dynamic>>> Function()? usersStreamOverride;
  final CreateUserFn? onCreateOverride;
  final Future<void> Function(Map<String, dynamic> user, String role)? onSetRoleOverride;
  final Future<void> Function(Map<String, dynamic> user, bool removed)? onSetRemovedOverride;

  const UserManagementScreen({
    super.key,
    this.usersStreamOverride,
    this.onCreateOverride,
    this.onSetRoleOverride,
    this.onSetRemovedOverride,
  });

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  late final Stream<List<Map<String, dynamic>>> _stream;
  UserAdminService? _svc;

  UserAdminService get _service => _svc ??= UserAdminService();

  @override
  void initState() {
    super.initState();
    _stream = widget.usersStreamOverride?.call() ?? _service.watchUsers();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String roleOf(Map<String, dynamic> u) {
    final r = (u['role'] ?? 'student').toString();
    if (const {'medical_officer', 'medical_assistant', 'nurse'}.contains(r)) return 'doctor';
    return r;
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((u) {
      final removed = u['accountStatus'] == 'removed';
      if (_filter == 'removed') {
        if (!removed) return false;
      } else {
        if (removed) return false;
        if (_filter != 'all' && roleOf(u) != _filter) return false;
      }
      if (q.isEmpty) return true;
      return [
        u['displayName'],
        u['email'],
        u['studentRoll'],
        u['department'],
      ].any((v) => (v ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(backgroundColor: BaustColors.successGreen, content: Text(success)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _changeRole(UserProfile actor, Map<String, dynamic> u, String role) async {
    final ok = await _confirm(
      'Change role?',
      'Make ${u['displayName'] ?? u['email']} a ${_label(role)}? They will see the ${_label(role)} dashboard next time they open the app.',
      'Change role',
    );
    if (!ok) return;
    await _run(
      () => widget.onSetRoleOverride != null ? widget.onSetRoleOverride!(u, role) : _service.setRole(actor, u, role),
      'Role updated',
    );
  }

  Future<void> _setRemoved(UserProfile actor, Map<String, dynamic> u, bool removed) async {
    final ok = await _confirm(
      removed ? 'Remove user?' : 'Restore user?',
      removed
          ? '${u['displayName'] ?? u['email']} will be signed out and blocked from Smart Medi. Their medical records are kept and you can restore them later.'
          : 'Restore access for ${u['displayName'] ?? u['email']}?',
      removed ? 'Remove' : 'Restore',
      destructive: removed,
    );
    if (!ok) return;
    await _run(
      () => widget.onSetRemovedOverride != null
          ? widget.onSetRemovedOverride!(u, removed)
          : _service.setRemoved(actor, u, removed),
      removed ? 'User removed' : 'User restored',
    );
  }

  Future<bool> _confirm(String title, String body, String action, {bool destructive = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: destructive ? FilledButton.styleFrom(backgroundColor: BaustColors.emergencyRed) : null,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openAddUser(UserProfile actor) async {
    final roles = UserAdminService.assignableRoles(actor);
    final fields = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AddUserDialog(roles: roles),
    );
    if (fields == null) return;
    await _run(() async {
      if (widget.onCreateOverride != null) {
        await widget.onCreateOverride!(fields);
      } else {
        await _service.createUser(
          actor: actor,
          email: fields['email']!,
          displayName: fields['displayName']!,
          role: fields['role']!,
          department: fields['department'],
          studentRoll: fields['studentRoll'],
          designation: fields['designation'],
          bmdcRegistrationNumber: fields['bmdc'],
          phone: fields['phone'],
        );
      }
    }, 'Account created. ${fields['email']} will get an email to set their own password.');
  }

  static String _label(String role) => switch (role) {
    'student' => 'Student',
    'doctor' => 'Doctor',
    'pharmacist' => 'Pharmacist',
    'admin' => 'Admin',
    'superadmin' => 'Super Admin',
    _ => role,
  };

  static Color _roleColor(String role) => switch (role) {
    'student' => const Color(0xFF0EA5E9),
    'doctor' => const Color(0xFF10B981),
    'pharmacist' => const Color(0xFF0D9488),
    'admin' => const Color(0xFFF59E0B),
    'superadmin' => const Color(0xFFE11D48),
    _ => BaustColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authControllerProvider).userProfile;
    if (actor == null || !actor.isAdmin) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Admins only')),
      );
    }
    final gutter = Breakpoints.gutter(context);

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddUser(actor),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add user'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Could not load users: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final shown = _apply(all);
          int count(String r) =>
              all.where((u) => u['accountStatus'] != 'removed' && (r == 'all' || roleOf(u) == r)).length;
          final removedCount = all.where((u) => u['accountStatus'] == 'removed').length;

          return ResponsiveCenter(
            maxWidth: 1200,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            hintText: 'Search name, email, student ID…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(icon: const Icon(Icons.clear), onPressed: _search.clear),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final f in const [
                                'all',
                                'student',
                                'doctor',
                                'pharmacist',
                                'admin',
                                'superadmin',
                                'removed',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${f == 'all'
                                          ? 'All'
                                          : f == 'removed'
                                          ? 'Removed'
                                          : _label(f)} (${f == 'removed' ? removedCount : count(f)})',
                                    ),
                                    selected: _filter == f,
                                    onSelected: (_) => setState(() => _filter = f),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('No users match', style: TextStyle(color: BaustColors.textMuted)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 96),
                    sliver: SliverToBoxAdapter(
                      child: ResponsiveWrapGrid(
                        minTileWidth: 360,
                        children: [for (final u in shown) _userCard(actor, u)],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _userCard(UserProfile actor, Map<String, dynamic> u) {
    final role = roleOf(u);
    final removed = u['accountStatus'] == 'removed';
    final canManage = UserAdminService.canManage(actor, u);
    final name = (u['displayName'] ?? '').toString().trim();
    final color = _roleColor(role);
    final assignable = UserAdminService.assignableRoles(actor).where((r) => r != role).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Unnamed user' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: removed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    (u['email'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(_label(role), color),
                      if (removed) _badge('Removed', BaustColors.emergencyRed),
                      if (role == 'student' && u['idVerificationStatus'] == 'pending')
                        _badge('ID pending', Colors.amber.shade800),
                      if ((u['studentRoll'] ?? '').toString().isNotEmpty)
                        _badge('ID ${u['studentRoll']}', BaustColors.textMuted),
                    ],
                  ),
                ],
              ),
            ),
            if (canManage)
              PopupMenuButton<String>(
                tooltip: 'Manage',
                onSelected: (v) {
                  if (v.startsWith('role:')) _changeRole(actor, u, v.substring(5));
                  if (v == 'remove') _setRemoved(actor, u, true);
                  if (v == 'restore') _setRemoved(actor, u, false);
                },
                itemBuilder: (_) => [
                  if (!removed)
                    for (final r in assignable)
                      PopupMenuItem(
                        value: 'role:$r',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.swap_horiz_rounded, color: _roleColor(r)),
                          title: Text('Make ${_label(r)}'),
                        ),
                      ),
                  if (!removed)
                    const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_remove_rounded, color: BaustColors.emergencyRed),
                        title: Text('Remove user'),
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'restore',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.restore_rounded),
                        title: Text('Restore user'),
                      ),
                    ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Tooltip(message: 'You cannot manage this account', child: Icon(Icons.lock_outline, size: 18)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _AddUserDialog extends StatefulWidget {
  final List<String> roles;
  const _AddUserDialog({required this.roles});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _roll = TextEditingController();
  final _designation = TextEditingController();
  final _bmdc = TextEditingController();
  late String _role = widget.roles.first;
  String? _dept;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _roll, _designation, _bmdc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {
      'displayName': _name.text.trim(),
      'email': _email.text.trim(),
      'role': _role,
      'phone': _phone.text.trim(),
      'department': ?_dept,
      if (_role == 'student') 'studentRoll': _roll.text.trim(),
      if (_role == 'doctor') 'designation': _designation.text.trim(),
      if (_role == 'doctor') 'bmdc': _bmdc.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Add user', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'The user receives an email to set their own password. You will never see it.',
                style: TextStyle(fontSize: 12.5, color: BaustColors.textMuted),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  for (final r in widget.roles)
                    ButtonSegment(value: r, label: Text(_UserManagementScreenState._label(r))),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name *', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a full name' : null,
              ),
              gap,
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.alternate_email)),
                validator: (v) =>
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
              ),
              gap,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _dept,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment_rounded)),
                items: [
                  for (final d in BaustDepartments.departments)
                    DropdownMenuItem(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _dept = v),
              ),
              if (_role == 'student') ...[
                gap,
                TextFormField(
                  controller: _roll,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Student ID *', prefixIcon: Icon(Icons.tag)),
                  validator: (v) => RegExp(r'^\d{6,20}$').hasMatch((v ?? '').trim()) ? null : '6–20 digits',
                ),
              ],
              if (_role == 'doctor') ...[
                gap,
                TextFormField(
                  controller: _designation,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _bmdc,
                  decoration: const InputDecoration(
                    labelText: 'BMDC registration number',
                    prefixIcon: Icon(Icons.verified_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
