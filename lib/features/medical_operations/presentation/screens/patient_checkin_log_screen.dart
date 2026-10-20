import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/auth_config.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../controllers/patient_checkin_controller.dart';

class PatientCheckInLogScreen extends ConsumerStatefulWidget {
  const PatientCheckInLogScreen({super.key});

  @override
  ConsumerState<PatientCheckInLogScreen> createState() => _PatientCheckInLogScreenState();
}

class _PatientCheckInLogScreenState extends ConsumerState<PatientCheckInLogScreen> {
  String _searchQuery = '';
  String _selectedPurposeFilter = 'All';

  final List<String> _purposeFilters = [
    'All',
    'Emergency SOS',
    'Consultation',
    'Medicine Dispense',
    'First Aid',
    'Vitals Check',
  ];

  void _showNewCheckInDialog(BuildContext context, UserProfile? currentUser) {
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    String selectedPurpose = 'Routine Doctor Consultation';

    final purposeOptions = [
      'Routine Doctor Consultation',
      'Emergency SOS Treatment',
      'Pharmacy Medicine Dispense / Refill',
      'First Aid & Dressing',
      'Blood Pressure / Vitals Check',
      'Fever & Flu Examination',
      'Other Clinical Purpose',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1,
                              color: BaustColors.primaryArmyGreen,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Record Patient Check-In',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: BaustColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Medical Center Staff "Who & When" Entry',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: BaustColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      TextFormField(
                        controller: idController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Student ID / Roll *',
                          hintText: 'e.g. 0802420205101137',
                          prefixIcon: Icon(Icons.badge_outlined, color: BaustColors.primaryArmyGreen),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Student ID is required.';
                          }
                          if (!AuthConfig.isValidStudentId(val.trim())) {
                            return 'Enter a valid student ID (6-20 digits).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Student Name *',
                          hintText: 'e.g. Student Name',
                          prefixIcon: Icon(Icons.person_outline, color: BaustColors.primaryArmyGreen),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Student Name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPurpose,
                        decoration: const InputDecoration(
                          labelText: 'Visit Purpose *',
                          prefixIcon: Icon(Icons.healing_outlined, color: BaustColors.primaryArmyGreen),
                        ),
                        items: purposeOptions.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(opt, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedPurpose = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Clinical Notes / Actions (Optional)',
                          hintText: 'e.g. Temperature 101F, given Paracetamol 500mg.',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.edit_note, color: BaustColors.primaryArmyGreen),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BaustColors.primaryArmyGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.save),
                          label: const Text(
                            'Save to Medical Center Staff Log',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              final staffName = currentUser?.displayName ?? 'Medical Staff';
                              final staffRole = currentUser?.designation ?? currentUser?.role ?? 'Staff';
                              ref.read(patientCheckInProvider.notifier).addCheckIn(
                                    studentId: idController.text.trim(),
                                    studentName: nameController.text.trim(),
                                    purpose: selectedPurpose,
                                    recordedBy: '$staffName ($staffRole)',
                                    notes: notesController.text.trim().isNotEmpty
                                        ? notesController.text.trim()
                                        : null,
                                  );

                              Navigator.pop(modalContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: BaustColors.successGreen,
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Check-In recorded for ${nameController.text.trim()} (ID: ${idController.text.trim()})',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkIns = ref.watch(patientCheckInProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;

    final filteredCheckIns = checkIns.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.studentId.contains(_searchQuery);

      bool matchesPurpose = true;
      if (_selectedPurposeFilter != 'All') {
        matchesPurpose = item.purpose.toLowerCase().contains(_selectedPurposeFilter.toLowerCase());
      }

      return matchesSearch && matchesPurpose;
    }).toList();

    final emergencyCount = checkIns.where((c) => c.purpose.toLowerCase().contains('emergency') || c.purpose.toLowerCase().contains('sos')).length;
    final routineCount = checkIns.where((c) => c.purpose.toLowerCase().contains('consultation') || c.purpose.toLowerCase().contains('routine')).length;

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Medical Center Patient Check-in Log'),
        actions: [
          IconButton(
            tooltip: 'New Check-In',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _showNewCheckInDialog(context, user),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BaustColors.primaryArmyGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showNewCheckInDialog(context, user),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Metrics Cards
            Row(
              children: [
                _buildStatCard(
                  'Total Checked In',
                  '${checkIns.length}',
                  BaustColors.primaryNavy,
                  Icons.assignment_ind,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  'Emergency SOS',
                  '$emergencyCount',
                  BaustColors.emergencyRed,
                  Icons.emergency,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  'Consultations',
                  '$routineCount',
                  BaustColors.successGreen,
                  Icons.medical_services_outlined,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by Student Name or Student ID...',
                      prefixIcon: const Icon(Icons.search, color: BaustColors.primaryArmyGreen),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _purposeFilters.map((flt) {
                        final isSelected = _selectedPurposeFilter == flt;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(flt, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: BaustColors.primaryArmyGreen.withValues(alpha: 0.15),
                            checkmarkColor: BaustColors.primaryArmyGreen,
                            onSelected: (val) {
                              setState(() => _selectedPurposeFilter = flt);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PATIENT VISITS & LOG TIMELINE (${filteredCheckIns.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: BaustColors.textMuted,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showNewCheckInDialog(context, user),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Entry', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: BaustColors.primaryArmyGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (filteredCheckIns.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        checkIns.isEmpty
                            ? 'No check-ins yet.'
                            : 'No matching patient check-ins found.',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCheckIns.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final log = filteredCheckIns[index];
                  final isEmergency = log.purpose.toLowerCase().contains('emergency') || log.purpose.toLowerCase().contains('sos');

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isEmergency ? BaustColors.emergencyRed.withValues(alpha: 0.6) : Colors.grey.shade200,
                        width: isEmergency ? 1.5 : 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: isEmergency
                                    ? Colors.red.shade50
                                    : BaustColors.primaryArmyGreen.withValues(alpha: 0.1),
                                child: Icon(
                                  isEmergency ? Icons.warning_amber_rounded : Icons.person,
                                  color: isEmergency ? BaustColors.emergencyRed : BaustColors.primaryArmyGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.studentName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${log.studentId}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: BaustColors.primaryNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isEmergency ? Colors.red.shade100 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEmergency ? BaustColors.emergencyRed : BaustColors.successGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: BaustColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${log.arrivalTime.day.toString().padLeft(2, '0')}/${log.arrivalTime.month.toString().padLeft(2, '0')}/${log.arrivalTime.year} at ${log.arrivalTime.hour.toString().padLeft(2, '0')}:${log.arrivalTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                              ),
                              const Spacer(),
                              const Icon(Icons.badge, size: 14, color: BaustColors.textMuted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'By: ${log.recordedBy}',
                                  style: const TextStyle(fontSize: 11, color: BaustColors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isEmergency ? Colors.red.shade50 : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.medical_information_outlined,
                                  size: 15,
                                  color: isEmergency ? BaustColors.emergencyRed : BaustColors.primaryNavy,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Purpose: ${log.purpose}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isEmergency ? BaustColors.emergencyRed : BaustColors.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (log.notes != null && log.notes!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Notes: ${log.notes}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: BaustColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
