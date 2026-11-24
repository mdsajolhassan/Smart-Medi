import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/auth_config.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../../core/widgets/responsive.dart';

/// Roles that get the professional (clinical staff) profile section.
const _clinicalRoles = {'doctor', 'medical_officer', 'medical_assistant', 'nurse', 'pharmacist'};

/// Manual profile editor with role-specific sections:
/// * Students: personal, academic, residence and blood-donation details.
/// * Doctors & medical staff: personal and professional (designation, BMDC) details.
class EditProfileScreen extends ConsumerStatefulWidget {
  /// Test hook: replaces the Firestore save.
  final Future<void> Function(Map<String, dynamic> values)? onSaveOverride;

  const EditProfileScreen({super.key, this.onSaveOverride});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  // Student
  late final TextEditingController _room;
  late final TextEditingController _upazila;
  late final TextEditingController _address;
  // Clinical staff
  late final TextEditingController _bmdc;
  late final TextEditingController _customDesignation;

  String? _department;
  String? _level;
  String? _term;
  bool _residential = true;
  String? _hall;
  String? _district;
  bool _willingToDonate = false;
  String? _bloodGroup;
  String? _designation;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  bool _saving = false;
  bool _dirty = false;

  static const _otherDesignation = 'Other…';

  UserProfile? get _user => ref.read(authControllerProvider).userProfile;

  bool get _isStudent => (_user?.role ?? 'student') == 'student';
  bool get _isClinical => _clinicalRoles.contains(_user?.role);

  @override
  void initState() {
    super.initState();
    final u = _user;
    _name = TextEditingController(text: u?.displayName ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _room = TextEditingController(text: (u?.roomNumber == 'N/A' ? '' : u?.roomNumber) ?? '');
    _upazila = TextEditingController(text: u?.upazila ?? '');
    _address = TextEditingController(text: u?.detailedAddress ?? '');
    _bmdc = TextEditingController(text: u?.bmdcRegistrationNumber ?? '');
    _customDesignation = TextEditingController();

    _department = _pick(u?.department, BaustDepartments.departments);
    _level = _pick(u?.level, AuthConfig.academicLevels);
    _term = _pick(u?.term, AuthConfig.academicTerms);
    _residential = u?.isResidential ?? true;
    _hall = _pick(u?.residentialHall, _halls);
    _district = _pick(u?.district, BangladeshDistricts.districts);
    _willingToDonate = u?.isWillingToDonateBlood ?? false;
    _bloodGroup = _pick(u?.bloodGroup, _bloodGroups);

    final d = u?.designation?.trim();
    if (d != null && d.isNotEmpty) {
      if (FacultyDesignations.designations.contains(d)) {
        _designation = d;
      } else {
        _designation = _otherDesignation;
        _customDesignation.text = d;
      }
    }

    for (final c in [_name, _phone, _room, _upazila, _address, _bmdc, _customDesignation]) {
      c.addListener(_markDirty);
    }
  }

  static List<String> get _halls => BaustHalls.residentialHalls.where((h) => !h.startsWith('Non-Residential')).toList();

  static String? _pick(String? value, List<String> options) =>
      (value != null && options.contains(value)) ? value : null;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _set(VoidCallback fn) => setState(() {
    fn();
    _dirty = true;
  });

  @override
  void dispose() {
    for (final c in [_name, _phone, _room, _upazila, _address, _bmdc, _customDesignation]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _effectiveDesignation =>
      _designation == _otherDesignation ? _customDesignation.text.trim() : _designation;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final values = <String, dynamic>{
      'displayName': _name.text.trim(),
      'phone': _phone.text.trim(),
      'department': _department,
      if (_isStudent) ...{
        'level': _level,
        'term': _term,
        'residencyStatus': _residential ? 'residential' : 'non_residential',
        'residentialHall': _residential ? _hall : null,
        'roomNumber': _residential ? _room.text.trim() : null,
        'district': _district,
        'upazila': _upazila.text.trim(),
        'detailedAddress': _address.text.trim(),
        'isWillingToDonateBlood': _willingToDonate,
        'bloodGroup': _bloodGroup,
      } else ...{
        'designation': _effectiveDesignation,
        if (_isClinical) 'bmdcRegistrationNumber': _bmdc.text.trim(),
      },
    };

    try {
      if (widget.onSaveOverride != null) {
        await widget.onSaveOverride!(values);
      } else {
        await ref
            .read(authControllerProvider.notifier)
            .updateUserProfileDetails(
              displayName: values['displayName'],
              phone: values['phone'],
              department: values['department'],
              level: values['level'],
              term: values['term'],
              residencyStatus: values['residencyStatus'],
              residentialHall: values['residentialHall'],
              roomNumber: values['roomNumber'],
              district: values['district'],
              upazila: values['upazila'],
              detailedAddress: values['detailedAddress'],
              isWillingToDonateBlood: values['isWillingToDonateBlood'],
              designation: values['designation'],
              bmdcRegistrationNumber: values['bmdcRegistrationNumber'],
              bloodGroup: values['bloodGroup'],
            );
      }
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.successGreen,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile updated'),
            ],
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(backgroundColor: BaustColors.emergencyRed, content: Text('Could not save profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved profile changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return discard ?? false;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).userProfile;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save Changes'),
            ),
          ),
        ),
        body: ResponsiveCenter(
          maxWidth: 760,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _header(user),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.person_rounded,
                  title: 'Personal',
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Enter your full name' : null,
                    ),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '01XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: _validatePhone,
                    ),
                    _readOnly('Email', user.email, Icons.alternate_email),
                  ],
                ),
                if (_isStudent) ..._studentSections(user) else ..._staffSections(user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _validatePhone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (s.isEmpty) return null;
    return RegExp(r'^(\+?880|0)1[3-9]\d{8}$').hasMatch(s) ? null : 'Enter a valid Bangladeshi mobile number';
  }

  Widget _header(UserProfile user) {
    final roleLabel = switch (user.role) {
      'student' => 'Student',
      'doctor' => 'Doctor',
      'medical_officer' => 'Medical Officer',
      'medical_assistant' => 'Medical Assistant',
      'nurse' => 'Nurse',
      'pharmacist' => 'Pharmacist',
      'staff' => 'Faculty / Staff',
      _ => user.role,
    };
    final initial = (_name.text.trim().isNotEmpty ? _name.text.trim()[0] : 'U').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [BaustColors.armyGreenDark, BaustColors.armyGreenLight]),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Icon(
              _isStudent ? Icons.school_rounded : Icons.medical_services_rounded,
              color: Colors.white,
              size: 30,
              semanticLabel: initial,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (_, v, _) => Text(
                    v.text.trim().isEmpty ? 'Your name' : v.text.trim(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(roleLabel, Icons.verified_user_rounded),
                    if (_isStudent && (user.studentRoll ?? '').isNotEmpty) _chip('ID ${user.studentRoll}', Icons.tag),
                    if (_isStudent)
                      user.isIdVerified
                          ? _chip('ID verified', Icons.verified_rounded)
                          : _chip(
                              user.idVerificationStatus == 'pending' ? 'ID under review' : 'ID not verified',
                              Icons.hourglass_top_rounded,
                            ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _section({required IconData icon, required String title, String? subtitle, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: BaustColors.primaryArmyGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                        if (subtitle != null)
                          Text(subtitle, style: const TextStyle(fontSize: 12, color: BaustColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (int i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]],
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnly(String label, String value, IconData icon) => TextFormField(
    initialValue: value,
    enabled: false,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: const Tooltip(message: 'Managed by BAUST admin', child: Icon(Icons.lock_outline, size: 18)),
      fillColor: const Color(0xFFF4F1FA),
    ),
  );

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => _set(() => onChanged(v)),
      validator: validator,
    );
  }

  List<Widget> _studentSections(UserProfile user) => [
    _section(
      icon: Icons.school_rounded,
      title: 'Academic',
      children: [
        _readOnly('Student ID', user.studentRoll ?? 'Not set', Icons.tag),
        _dropdown(
          label: 'Department *',
          icon: Icons.apartment_rounded,
          value: _department,
          items: BaustDepartments.departments,
          onChanged: (v) => _department = v,
          validator: (v) => v == null ? 'Select your department' : null,
        ),
        Row(
          children: [
            Expanded(
              child: _dropdown(
                label: 'Level',
                icon: Icons.stairs_rounded,
                value: _level,
                items: AuthConfig.academicLevels,
                onChanged: (v) => _level = v,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dropdown(
                label: 'Term',
                icon: Icons.event_note_rounded,
                value: _term,
                items: AuthConfig.academicTerms,
                onChanged: (v) => _term = v,
              ),
            ),
          ],
        ),
      ],
    ),
    _section(
      icon: Icons.home_work_rounded,
      title: 'Residence',
      subtitle: 'Used by the SOS team to reach you quickly',
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, icon: Icon(Icons.apartment), label: Text('Hall resident')),
            ButtonSegment(value: false, icon: Icon(Icons.directions_bus), label: Text('Day scholar')),
          ],
          selected: {_residential},
          onSelectionChanged: (s) => _set(() => _residential = s.first),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: _residential
              ? Column(
                  children: [
                    _dropdown(
                      label: 'Residential hall *',
                      icon: Icons.location_city_rounded,
                      value: _hall,
                      items: _halls,
                      onChanged: (v) => _hall = v,
                      validator: (v) => _residential && v == null ? 'Select your hall' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _room,
                      decoration: const InputDecoration(
                        labelText: 'Room number *',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      validator: (v) =>
                          _residential && (v == null || v.trim().isEmpty) ? 'Enter your room number' : null,
                    ),
                  ],
                )
              : Column(
                  children: [
                    _dropdown(
                      label: 'District',
                      icon: Icons.map_outlined,
                      value: _district,
                      items: BangladeshDistricts.districts,
                      onChanged: (v) => _district = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _upazila,
                      decoration: const InputDecoration(
                        labelText: 'Upazila / Thana',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Detailed address',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
    _section(
      icon: Icons.bloodtype_rounded,
      title: 'Blood donation',
      children: [
        if (user.bloodGroupVerified)
          _readOnly('Blood group (verified by Medical Center)', user.bloodGroup ?? '—', Icons.water_drop_outlined)
        else
          _dropdown(
            label: 'Blood group (self-reported)',
            icon: Icons.water_drop_outlined,
            value: _bloodGroup,
            items: _bloodGroups,
            onChanged: (v) => _bloodGroup = v,
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _willingToDonate,
          onChanged: (v) => _set(() => _willingToDonate = v),
          title: const Text('List me as a voluntary donor', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Shown in the Campus Blood Bank directory'),
        ),
      ],
    ),
  ];

  List<Widget> _staffSections(UserProfile user) => [
    _section(
      icon: Icons.medical_services_rounded,
      title: 'Professional',
      subtitle: _isClinical ? 'Printed on the prescriptions you issue' : null,
      children: [
        _dropdown(
          label: 'Designation *',
          icon: Icons.work_outline_rounded,
          value: _designation,
          items: [...FacultyDesignations.designations, _otherDesignation],
          onChanged: (v) => _designation = v,
          validator: (v) => v == null ? 'Select your designation' : null,
        ),
        if (_designation == _otherDesignation)
          TextFormField(
            controller: _customDesignation,
            decoration: const InputDecoration(labelText: 'Your designation *', prefixIcon: Icon(Icons.edit_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your designation' : null,
          ),
        if (_isClinical)
          TextFormField(
            controller: _bmdc,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'BMDC registration number',
              hintText: 'e.g. A-12345',
              prefixIcon: Icon(Icons.verified_outlined),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) {
                return user.role == 'doctor' || user.role == 'medical_officer' ? 'Required for doctors' : null;
              }
              return RegExp(r'^[A-Za-z]{0,2}-?\d{3,7}$').hasMatch(s) ? null : 'Format like A-12345';
            },
          ),
        _dropdown(
          label: 'Department / Unit',
          icon: Icons.apartment_rounded,
          value: _department,
          items: BaustDepartments.departments,
          onChanged: (v) => _department = v,
        ),
        _readOnly('Role', user.role.replaceAll('_', ' '), Icons.admin_panel_settings_outlined),
      ],
    ),
  ];
}
