import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/auth_config.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _studentIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roomController = TextEditingController();
  final _upazilaController = TextEditingController();
  final _detailedAddressController = TextEditingController();

  String _residencyStatus = 'residential'; // 'residential' | 'non_residential'
  String _selectedDistrict = BangladeshDistricts.districts.first;
  String _selectedDepartment = AuthConfig.academicDepartments.first;
  String _selectedLevel = AuthConfig.academicLevels.first;
  String _selectedTerm = AuthConfig.academicTerms.first;
  String _selectedHall = AuthConfig.residentialHalls.first;
  bool _isWillingToDonateBlood = false;
  bool _sharePhoneInDonorDirectory = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).userProfile;
    if (user != null) {
      _residencyStatus = user.residencyStatus;
      if (user.district != null && BangladeshDistricts.districts.contains(user.district)) {
        _selectedDistrict = user.district!;
      }
      if (user.upazila != null && user.upazila!.isNotEmpty) {
        _upazilaController.text = user.upazila!;
      }
      if (user.detailedAddress != null && user.detailedAddress!.isNotEmpty) {
        _detailedAddressController.text = user.detailedAddress!;
      }
      if (user.studentRoll != null && user.studentRoll!.isNotEmpty) {
        _studentIdController.text = user.studentRoll!;
      }
      if (user.phone != null && user.phone!.isNotEmpty) {
        _phoneController.text = user.phone!;
      }
      if (user.roomNumber != null && user.roomNumber!.isNotEmpty) {
        _roomController.text = user.roomNumber!;
      } else {
        _roomController.text = '402-B';
      }
      if (user.department != null &&
          AuthConfig.academicDepartments.contains(user.department)) {
        _selectedDepartment = user.department!;
      }
      if (user.level != null &&
          AuthConfig.academicLevels.contains(user.level)) {
        _selectedLevel = user.level!;
      }
      if (user.term != null &&
          AuthConfig.academicTerms.contains(user.term)) {
        _selectedTerm = user.term!;
      }
      if (user.residentialHall != null &&
          AuthConfig.residentialHalls.contains(user.residentialHall)) {
        _selectedHall = user.residentialHall!;
      }
      _isWillingToDonateBlood = user.isWillingToDonateBlood;
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _phoneController.dispose();
    _roomController.dispose();
    _upazilaController.dispose();
    _detailedAddressController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndContinue() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      try {
        await ref.read(authControllerProvider.notifier).saveStudentProfileSetup(
              studentId: _studentIdController.text.trim(),
              department: _selectedDepartment,
              level: _selectedLevel,
              term: _selectedTerm,
              residencyStatus: _residencyStatus,
              residentialHall: _residencyStatus == 'residential'
                  ? _selectedHall
                  : 'Non-Residential (Day Scholar)',
              roomNumber: _residencyStatus == 'residential'
                  ? (_roomController.text.trim().isNotEmpty
                      ? _roomController.text.trim()
                      : '402-B')
                  : 'N/A',
              district: _residencyStatus == 'non_residential' ? _selectedDistrict : null,
              upazila: _residencyStatus == 'non_residential'
                  ? _upazilaController.text.trim()
                  : null,
              detailedAddress: _residencyStatus == 'non_residential'
                  ? _detailedAddressController.text.trim()
                  : null,
              phone: _phoneController.text.trim().isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
              isWillingToDonateBlood: _isWillingToDonateBlood,
              sharePhoneInDonorDirectory: _sharePhoneInDonorDirectory,
            );
      } on StudentIdAlreadyRegisteredException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(e.message)),
              ],
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            content: Text('Profile setup error: $e'),
          ),
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Student Profile Setup'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header Step Tracker Card
                  Container(
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
                            color: BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            color: BaustColors.primaryArmyGreen,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Step 1 of 2: Academic Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: BaustColors.primaryArmyGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Welcome, ${user?.displayName ?? "Student"}! Complete your student record before proceeding to medical onboarding.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: BaustColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Form Card
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STUDENT IDENTIFICATION & ACADEMIC DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: BaustColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Student ID (Required, trimmed, format regex)
                            TextFormField(
                              controller: _studentIdController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Student ID * (Required)',
                                hintText: 'e.g. Student ID',
                                prefixIcon: Icon(
                                  Icons.pin_outlined,
                                  color: BaustColors.primaryArmyGreen,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Student ID is required.';
                                }
                                if (!AuthConfig.isValidStudentId(val.trim())) {
                                  return 'Enter a valid student ID.';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Department (Dropdown)
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDepartment,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Department *',
                                prefixIcon: Icon(
                                  Icons.school_outlined,
                                  color: BaustColors.primaryArmyGreen,
                                ),
                              ),
                              items: AuthConfig.academicDepartments.map((dept) {
                                return DropdownMenuItem(
                                  value: dept,
                                  child: Text(
                                    dept,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDepartment = val);
                              },
                            ),

                            const SizedBox(height: 16),

                            // Level & Term Row (Dropdowns)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedLevel,
                                    decoration: const InputDecoration(
                                      labelText: 'Academic Level *',
                                      prefixIcon: Icon(
                                        Icons.timeline,
                                        color: BaustColors.primaryArmyGreen,
                                      ),
                                    ),
                                    items: AuthConfig.academicLevels.map((lvl) {
                                      return DropdownMenuItem(
                                        value: lvl,
                                        child: Text(lvl, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedLevel = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedTerm,
                                    decoration: const InputDecoration(
                                      labelText: 'Academic Term *',
                                      prefixIcon: Icon(
                                        Icons.view_agenda_outlined,
                                        color: BaustColors.primaryArmyGreen,
                                      ),
                                    ),
                                    items: AuthConfig.academicTerms.map((trm) {
                                      return DropdownMenuItem(
                                        value: trm,
                                        child: Text(trm, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedTerm = val);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Residency Status Selector (Residential vs Non-Residential)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Residency Status / আবাসন স্থিতি *',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: BaustColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _residencyStatus = 'residential'),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _residencyStatus == 'residential'
                                                ? BaustColors.primaryArmyGreen.withValues(alpha: 0.08)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _residencyStatus == 'residential'
                                                  ? BaustColors.primaryArmyGreen
                                                  : Colors.grey.shade300,
                                              width: _residencyStatus == 'residential' ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _residencyStatus == 'residential'
                                                    ? Icons.radio_button_checked
                                                    : Icons.radio_button_unchecked,
                                                color: _residencyStatus == 'residential'
                                                    ? BaustColors.primaryArmyGreen
                                                    : Colors.grey,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              const Flexible(
                                                child: Text(
                                                  'Residential\n(আবাসিক)',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: BaustColors.textDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _residencyStatus = 'non_residential'),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _residencyStatus == 'non_residential'
                                                ? BaustColors.primaryArmyGreen.withValues(alpha: 0.08)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _residencyStatus == 'non_residential'
                                                  ? BaustColors.primaryArmyGreen
                                                  : Colors.grey.shade300,
                                              width: _residencyStatus == 'non_residential' ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _residencyStatus == 'non_residential'
                                                    ? Icons.radio_button_checked
                                                    : Icons.radio_button_unchecked,
                                                color: _residencyStatus == 'non_residential'
                                                    ? BaustColors.primaryArmyGreen
                                                    : Colors.grey,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              const Flexible(
                                                child: Text(
                                                  'Non-Residential\n(অনাবাসিক)',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: BaustColors.textDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // If Residential: Show Hall Dropdown & Room Number
                            if (_residencyStatus == 'residential') ...[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedHall,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Residential Hall *',
                                  prefixIcon: Icon(
                                    Icons.apartment,
                                    color: BaustColors.primaryArmyGreen,
                                  ),
                                ),
                                items: BaustHalls.residentialHalls
                                    .where((h) => !h.toLowerCase().contains('non-resident'))
                                    .map((hall) {
                                  return DropdownMenuItem(
                                    value: hall,
                                    child: Text(
                                      hall,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedHall = val);
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _roomController,
                                keyboardType: TextInputType.text,
                                decoration: const InputDecoration(
                                  labelText: 'Hall Room Number * (e.g. 402-B)',
                                  hintText: '402-B',
                                  prefixIcon: Icon(
                                    Icons.meeting_room_outlined,
                                    color: BaustColors.primaryArmyGreen,
                                  ),
                                ),
                                validator: (val) {
                                  if (_residencyStatus == 'residential') {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Room number is required for residential students.';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              // If Non-Residential: Show District (জেলা), Upazila (উপজেলা), Detailed Address (বিস্তারিত ঠিকানা)
                              DropdownButtonFormField<String>(
                                initialValue: _selectedDistrict,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'District (জেলা) *',
                                  prefixIcon: Icon(
                                    Icons.map_outlined,
                                    color: BaustColors.primaryArmyGreen,
                                  ),
                                ),
                                items: BangladeshDistricts.districts.map((district) {
                                  return DropdownMenuItem(
                                    value: district,
                                    child: Text(
                                      district,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedDistrict = val);
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _upazilaController,
                                keyboardType: TextInputType.text,
                                decoration: const InputDecoration(
                                  labelText: 'Upazila / Thana (উপজেলা / থানা) *',
                                  hintText: 'e.g. Saidpur, Nilphamari Sadar, Kotwali...',
                                  prefixIcon: Icon(
                                    Icons.location_city_outlined,
                                    color: BaustColors.primaryArmyGreen,
                                  ),
                                ),
                                validator: (val) {
                                  if (_residencyStatus == 'non_residential') {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Upazila is required for non-residential students.';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _detailedAddressController,
                                maxLines: 2,
                                keyboardType: TextInputType.streetAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Detailed Address (বিস্তারিত ঠিকানা) *',
                                  hintText: 'Village/Road, House no, Mess/Hostel name, Post Office...',
                                  alignLabelWithHint: true,
                                  prefixIcon: Icon(
                                    Icons.home_outlined,
                                    color: BaustColors.primaryArmyGreen,
                                  ),
                                ),
                                validator: (val) {
                                  if (_residencyStatus == 'non_residential') {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Detailed address is required for non-residential emergency dispatch.';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Phone (Optional, validated)
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Emergency Phone Number (Optional)',
                                hintText: '01712345678',
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  color: BaustColors.primaryArmyGreen,
                                ),
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  if (!AuthConfig.isValidPhone(val)) {
                                    return 'Please enter a valid 11-digit phone number.';
                                  }
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            // Blood Donor Opt-in Card
                            Container(
                              decoration: BoxDecoration(
                                color: _isWillingToDonateBlood
                                    ? BaustColors.primaryArmyGreen.withValues(alpha: 0.06)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isWillingToDonateBlood
                                      ? BaustColors.primaryArmyGreen
                                      : Colors.grey.shade300,
                                  width: _isWillingToDonateBlood ? 1.5 : 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      value: _isWillingToDonateBlood,
                                      activeColor: BaustColors.primaryArmyGreen,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      title: const Text(
                                        'Volunteer as a Blood Donor (Optional)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Allow BAUST Medical Center to contact you for emergency campus blood donation.',
                                        style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
                                      ),
                                      onChanged: (val) {
                                        setState(() => _isWillingToDonateBlood = val ?? false);
                                      },
                                    ),
                                    if (_isWillingToDonateBlood) ...[
                                      const Divider(height: 1, indent: 12, endIndent: 12),
                                      SwitchListTile(
                                        value: _sharePhoneInDonorDirectory,
                                        activeThumbColor: BaustColors.primaryArmyGreen,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        title: const Text(
                                          'Share phone number in Blood Donor Directory',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        subtitle: const Text(
                                          'Default: Hidden. If unchecked, students can only request you via the Medical Center.',
                                          style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
                                        ),
                                        onChanged: (val) {
                                          setState(() => _sharePhoneInDonorDirectory = val);
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Save and Continue Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BaustColors.primaryArmyGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isSaving ? null : _handleSaveAndContinue,
                              icon: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                _isSaving ? 'REGISTERING STUDENT ID...' : 'CONTINUE TO MEDICAL ONBOARDING',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
