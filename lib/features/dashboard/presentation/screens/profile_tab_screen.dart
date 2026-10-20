import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../admin_portal/presentation/screens/superadmin_dashboard.dart';
import '../../../advisor_portal/presentation/screens/staff_dashboard_screen.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../medical_operations/presentation/screens/doctor_dashboard_screen.dart';
import '../../../medical_operations/presentation/screens/pharmacist_inventory_screen.dart';

class ProfileTabScreen extends ConsumerStatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  ConsumerState<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends ConsumerState<ProfileTabScreen> {
  void _openEditProfileModal(UserProfile user) {
    final formKey = GlobalKey<FormState>();
    final roomController = TextEditingController(text: user.effectiveRoomNumber);
    final upazilaController = TextEditingController(text: user.upazila ?? '');
    final detailedAddressController = TextEditingController(text: user.detailedAddress ?? '');
    final phoneController = TextEditingController(text: user.phone ?? '');
    String residencyStatus = user.residencyStatus;
    String selectedDistrict = (user.district != null && BangladeshDistricts.districts.contains(user.district))
        ? user.district!
        : BangladeshDistricts.districts.first;
    String selectedHall = BaustHalls.residentialHalls.contains(user.residentialHall)
        ? user.residentialHall!
        : (BaustHalls.residentialHalls.contains(user.effectiveResidentialHall)
            ? user.effectiveResidentialHall
            : BaustHalls.residentialHalls.first);
    bool isWillingToDonate = user.isWillingToDonateBlood;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_location_alt, color: BaustColors.primaryArmyGreen),
                          SizedBox(width: 8),
                          Text(
                            'Edit Location Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: BaustColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Update your residential hall or home address for instant SOS dispatches.',
                    style: TextStyle(color: BaustColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Residency Selector
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => residencyStatus = 'residential'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              color: residencyStatus == 'residential'
                                  ? BaustColors.primaryArmyGreen.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: residencyStatus == 'residential'
                                    ? BaustColors.primaryArmyGreen
                                    : Colors.grey.shade300,
                                width: residencyStatus == 'residential' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  residencyStatus == 'residential'
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: residencyStatus == 'residential'
                                      ? BaustColors.primaryArmyGreen
                                      : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Residential Hall',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => residencyStatus = 'non_residential'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              color: residencyStatus == 'non_residential'
                                  ? BaustColors.primaryArmyGreen.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: residencyStatus == 'non_residential'
                                    ? BaustColors.primaryArmyGreen
                                    : Colors.grey.shade300,
                                width: residencyStatus == 'non_residential' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  residencyStatus == 'non_residential'
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: residencyStatus == 'non_residential'
                                      ? BaustColors.primaryArmyGreen
                                      : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Non-Residential',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (residencyStatus == 'residential') ...[
                    // Hall Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedHall,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Residential Hall *',
                        prefixIcon: Icon(Icons.apartment, color: BaustColors.primaryArmyGreen),
                      ),
                      items: BaustHalls.residentialHalls
                          .where((h) => !h.toLowerCase().contains('non-resident'))
                          .map(
                            (hall) => DropdownMenuItem(
                              value: hall,
                              child: Text(hall, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedHall = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Room Number
                    TextFormField(
                      controller: roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room Number * (e.g. 402-B)',
                        prefixIcon: Icon(Icons.meeting_room_outlined, color: BaustColors.primaryArmyGreen),
                      ),
                      validator: (v) {
                        if (residencyStatus == 'residential') {
                          if (v == null || v.trim().isEmpty) return 'Room number is required';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    // District Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedDistrict,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'District (জেলা) *',
                        prefixIcon: Icon(Icons.map_outlined, color: BaustColors.primaryArmyGreen),
                      ),
                      items: BangladeshDistricts.districts
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDistrict = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Upazila
                    TextFormField(
                      controller: upazilaController,
                      decoration: const InputDecoration(
                        labelText: 'Upazila (উপজেলা) *',
                        hintText: 'e.g. Saidpur, Nilphamari Sadar...',
                        prefixIcon: Icon(Icons.location_city_outlined, color: BaustColors.primaryArmyGreen),
                      ),
                      validator: (v) {
                        if (residencyStatus == 'non_residential') {
                          if (v == null || v.trim().isEmpty) return 'Upazila is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Detailed Address
                    TextFormField(
                      controller: detailedAddressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Detailed Address (বিস্তারিত ঠিকানা) *',
                        hintText: 'Road/Village, House no, Mess...',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.home_outlined, color: BaustColors.primaryArmyGreen),
                      ),
                      validator: (v) {
                        if (residencyStatus == 'non_residential') {
                          if (v == null || v.trim().isEmpty) return 'Detailed address is required';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Phone Number
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number (Optional)',
                      hintText: '01712345678',
                      prefixIcon: Icon(Icons.phone_outlined, color: BaustColors.primaryArmyGreen),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Blood donor opt-in switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: BaustColors.primaryArmyGreen,
                    title: const Text('Volunteer as Campus Blood Donor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('List availability in the university blood bank directory', style: TextStyle(fontSize: 11, color: BaustColors.textMuted)),
                    value: isWillingToDonate,
                    onChanged: (val) {
                      setModalState(() => isWillingToDonate = val);
                    },
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BaustColors.primaryArmyGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      isSaving ? 'SAVING CHANGES...' : 'SAVE & UPDATE PROFILE',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (formKey.currentState?.validate() ?? false) {
                              setModalState(() => isSaving = true);
                              try {
                                await ref.read(authControllerProvider.notifier).updateUserProfileDetails(
                                      residencyStatus: residencyStatus,
                                      residentialHall: residencyStatus == 'residential' ? selectedHall : 'Non-Residential (Day Scholar)',
                                      roomNumber: residencyStatus == 'residential' ? roomController.text.trim() : 'N/A',
                                      district: residencyStatus == 'non_residential' ? selectedDistrict : null,
                                      upazila: residencyStatus == 'non_residential' ? upazilaController.text.trim() : null,
                                      detailedAddress: residencyStatus == 'non_residential' ? detailedAddressController.text.trim() : null,
                                      phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                                      isWillingToDonateBlood: isWillingToDonate,
                                    );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: BaustColors.successGreen,
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('Profile and location successfully updated!'),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: BaustColors.emergencyRed,
                                      content: Text('Failed to update profile: $e'),
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => isSaving = false);
                                }
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;

    if (user == null) {
      return const Center(child: CircularProgressIndicator(color: BaustColors.primaryArmyGreen));
    }

    final isSuperAdmin = user.isSuperAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Profile Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSuperAdmin
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [BaustColors.armyGreenDark, BaustColors.primaryArmyGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (isSuperAdmin ? Colors.black45 : BaustColors.primaryArmyGreen).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSuperAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SUPER ADMIN',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.role.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      if (user.studentRoll != null && user.studentRoll!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Student ID: ${user.studentRoll}',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Persistent Location Card with Edit Button (Task 2)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: BaustColors.emergencyRed, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          user.isResidential
                              ? 'RESIDENTIAL EMERGENCY LOCATION'
                              : 'NON-RESIDENTIAL EMERGENCY ADDRESS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: BaustColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _openEditProfileModal(user),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: BaustColors.primaryArmyGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (user.isResidential) ...[
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.apartment,
                          title: 'Residential Hall',
                          value: user.effectiveResidentialHall,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.meeting_room,
                          title: 'Room Number',
                          value: user.effectiveRoomNumber,
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.location_city,
                          title: 'District & Upazila',
                          value: '${user.upazila ?? "Saidpur"}, ${user.district ?? "Nilphamari"}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.home,
                          title: 'Detailed Address',
                          value: user.detailedAddress ?? 'Day Scholar Residence',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Blood Profile & Donation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bloodtype, color: BaustColors.emergencyRed, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'BLOOD GROUP & DONOR STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: BaustColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            user.bloodGroup ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: BaustColors.emergencyRed,
                            ),
                          ),
                          const Text(
                            'Blood Group',
                            style: TextStyle(fontSize: 10, color: BaustColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                user.bloodGroupVerified ? Icons.verified : Icons.help_outline,
                                size: 14,
                                color: user.bloodGroupVerified ? BaustColors.successGreen : Colors.amber.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.bloodGroupVerified ? 'Lab Report Verified' : 'Unverified (Pending Lab)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: user.bloodGroupVerified ? BaustColors.successGreen : Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.isWillingToDonateBlood
                                ? 'Volunteer Donor enrolled in Blood Bank'
                                : 'Not registered as a donor volunteer',
                            style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Academic & Contact Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACADEMIC & CONTACT DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: BaustColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.school_outlined,
                  label: 'Department',
                  value: user.department ?? 'Computer Science & Engineering (CSE)',
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  icon: Icons.timeline,
                  label: 'Level & Term',
                  value: '${user.level ?? "Level 4"} • ${user.term ?? "Term 1"}',
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone Contact',
                  value: user.phone ?? 'Not provided',
                ),
              ],
            ),
          ),

          // Super Admin Elevated Tools Card (Task 4)
          if (isSuperAdmin) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Color(0xFFF59E0B), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'SUPER ADMIN PRIVILEGES ACTIVE',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Full institutional elevation enabled for ${user.displayName} (${user.email}). Tap to open management portals:',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  _buildAdminTile(
                    icon: Icons.admin_panel_settings,
                    title: 'System Hierarchy & Faculty RBAC',
                    subtitle: 'Provision personnel, view metrics & assignments',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SuperAdminDashboard()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAdminTile(
                    icon: Icons.local_hospital,
                    title: 'Doctor Dashboard & Emergency SOS Logs',
                    subtitle: 'Real-time university medical center dispatch queue',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAdminTile(
                    icon: Icons.medication,
                    title: 'Pharmacy & Drug Inventory',
                    subtitle: 'Medical dispensary stock and drug issue logs',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PharmacistInventoryScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAdminTile(
                    icon: Icons.person_pin_outlined,
                    title: 'Academic Advisor / Staff Portal',
                    subtitle: 'Department guides and faculty counseling desk',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StaffDashboardScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Sign Out Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: BaustColors.emergencyRed,
              side: const BorderSide(color: BaustColors.emergencyRed),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('SIGN OUT OF ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BaustColors.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: BaustColors.primaryArmyGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: BaustColors.textMuted)),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: BaustColors.primaryArmyGreen),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: BaustColors.textMuted, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BaustColors.textDark)),
      ],
    );
  }

  Widget _buildAdminTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white60, size: 14),
          ],
        ),
      ),
    );
  }
}
