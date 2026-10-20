import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../blood_bank/presentation/screens/blood_donor_directory.dart';
import '../controllers/sos_controller.dart';

class SosScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final bool showAppBar;

  const SosScreen({
    super.key,
    this.onNavigateToProfile,
    this.showAppBar = true,
  });

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _customEmergencyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final List<String> _symptomCategories = [
    'Chest Pain / Breathing Difficulty',
    'Severe Trauma / Bleeding',
    'Unconscious / Fainting',
    'Severe Asthma Attack',
    'Acute Food Poisoning',
    'Other Critical Emergency',
  ];
  late String _selectedSymptom;

  @override
  void initState() {
    super.initState();
    _selectedSymptom = _symptomCategories.first;

    // Pulse animation for the panic button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _customEmergencyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showConfirmationDialog({
    required String hall,
    required String room,
    required bool isResidential,
    required String locationSummary,
    String? studentName,
    String? studentRoll,
    String? department,
  }) {
    final finalIssue = (_selectedSymptom == 'Other Critical Emergency' &&
            _customEmergencyController.text.trim().isNotEmpty)
        ? 'Other Critical Emergency: ${_customEmergencyController.text.trim()}'
        : _selectedSymptom;

    final locationText = isResidential
        ? '• Hall: $hall\n• Room: $room'
        : '• Student Status: Non-Residential\n• Location: $locationSummary';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: BaustColors.emergencyRed),
            SizedBox(width: 8),
            Text('Confirm SOS Alert', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will trigger an immediate emergency alert to BAUST Medical Center and your guide advisor for:\n\n'
          '$locationText\n'
          '• Issue: $finalIssue',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BaustColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BaustColors.emergencyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(sosControllerProvider.notifier).triggerEmergency(
                    residentialHall: hall,
                    roomNumber: room,
                    symptomCategory: finalIssue,
                    optionalNote: _noteController.text,
                    studentName: studentName,
                    studentRoll: studentRoll,
                    department: department,
                  );
            },
            child: const Text('DISPATCH NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosControllerProvider);

    ref.listen<SosState>(sosControllerProvider, (previous, next) {
      if (next.status == SosStatus.triggered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emergency SOS Dispatched! Alert ID: ${next.activeAlertId?.substring(0, 8)}...',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (next.status == SosStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            content: Text(next.errorMessage ?? 'Failed to send SOS.'),
          ),
        );
      }
    });

    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;
    final isRes = user?.isResidential ?? true;
    final hall = user?.effectiveResidentialHall ?? 'Shaheed Dr. Zikrul Haque Hall (SDZHH)';
    final room = user?.effectiveRoomNumber ?? '402-B';
    final locationSummary = user?.effectiveLocationSummary ?? '$hall, Room: $room';

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Emergency Medical SOS'),
              actions: [
                IconButton(
                  tooltip: 'Smart Blood Bank',
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BloodDonorDirectoryScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                ),
              ],
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Emergency Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_services, color: BaustColors.emergencyRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'BAUST Medical Center 24/7 Hotline: ${BaustEmergencyContacts.hotlineDisplay}\nAmbulance: ${BaustEmergencyContacts.ambulanceDisplay}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Blood Donor Directory Quick Banner
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BloodDonorDirectoryScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volunteer_activism,
                        color: BaustColors.emergencyRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blood Donor Directory',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: BaustColors.textDark,
                            ),
                          ),
                          Text(
                            'Self-reported blood groups - confirm before transfusion',
                            style: TextStyle(
                              fontSize: 11,
                              color: BaustColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: BaustColors.emergencyRed,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Pulsing Panic Button
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: sosState.status == SosStatus.triggering
                    ? null
                    : () => _showConfirmationDialog(
                          hall: hall,
                          room: room,
                          isResidential: isRes,
                          locationSummary: locationSummary,
                          studentName: user?.displayName,
                          studentRoll: user?.studentRoll,
                          department: user?.department,
                        ),
                child: Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFEF4444), BaustColors.emergencyRed],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: BaustColors.emergencyRed.withValues(alpha: 0.4),
                        blurRadius: 28,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: sosState.status == SosStatus.triggering
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.touch_app, color: Colors.white, size: 48),
                              const SizedBox(height: 4),
                              Text(
                                sosState.status == SosStatus.triggered ? 'SENT!' : 'PANIC SOS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Text(
                                'Tap to Dispatch',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Registered Persistent Location Card (Removed manual dropdown/entry per Task 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
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
                          const SizedBox(width: 6),
                          Text(
                            'DISPATCH LOCATION (PROFILE RECORD)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      if (widget.onNavigateToProfile != null)
                        TextButton.icon(
                          onPressed: widget.onNavigateToProfile,
                          icon: const Icon(Icons.edit_location_alt_outlined, size: 15),
                          label: const Text('Edit in Profile', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: BaustColors.primaryArmyGreen,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isRes) ...[
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: BaustColors.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.apartment, color: BaustColors.primaryArmyGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Residential Hall',
                                        style: TextStyle(fontSize: 10, color: BaustColors.textMuted),
                                      ),
                                      Text(
                                        hall,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: BaustColors.surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.meeting_room, color: BaustColors.primaryArmyGreen, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Room',
                                    style: TextStyle(fontSize: 10, color: BaustColors.textMuted),
                                  ),
                                  Text(
                                    room,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: BaustColors.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_city, color: BaustColors.primaryArmyGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'District & Upazila',
                                        style: TextStyle(fontSize: 10, color: BaustColors.textMuted),
                                      ),
                                      Text(
                                        '${user?.upazila ?? "Saidpur"}, ${user?.district ?? "Nilphamari"}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: BaustColors.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.home, color: BaustColors.primaryArmyGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Home Address',
                                        style: TextStyle(fontSize: 10, color: BaustColors.textMuted),
                                      ),
                                      Text(
                                        user?.detailedAddress ?? 'Day Scholar Residence',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Symptom Category Dropdown
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'NATURE OF EMERGENCY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _selectedSymptom,
              decoration: const InputDecoration(
                labelText: 'Primary Symptom / Category',
                prefixIcon: Icon(Icons.emergency, color: BaustColors.emergencyRed),
              ),
              items: _symptomCategories.map((symptom) {
                return DropdownMenuItem<String>(
                  value: symptom,
                  child: Text(symptom, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSymptom = val);
              },
            ),

            // Dynamic custom critical emergency note (Task 3)
            if (_selectedSymptom == 'Other Critical Emergency') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customEmergencyController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Specify Critical Emergency Condition *',
                  hintText: 'e.g. Severe allergic shock, seizure, acute trauma, chest compression...',
                  prefixIcon: Icon(Icons.edit_note, color: BaustColors.emergencyRed),
                  alignLabelWithHint: true,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Optional note
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Optional quick note (e.g. Patient is unconscious)',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            if (sosState.status == SosStatus.triggered)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BaustColors.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset for New Alert'),
                onPressed: () {
                  ref.read(sosControllerProvider.notifier).resetAlert();
                },
              ),
          ],
        ),
      ),
    );
  }
}
