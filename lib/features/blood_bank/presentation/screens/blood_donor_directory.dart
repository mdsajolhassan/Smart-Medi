import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';

/// Minimal public donor profile representation in the campus blood bank directory (H2)
/// Adheres strictly to minimal public fields:
/// NEVER exposes studentId/roll, allergies, conditions, medications, or clinical history.
class BloodDonorRecord {
  final String id;
  final String displayName;
  final String bloodGroup;
  final bool bloodGroupVerified;
  final String department;
  final String hall;
  final bool isAvailable;
  final String? phone; // Optional: only if user explicitly opted in (default hidden)
  final DateTime? updatedAt;

  const BloodDonorRecord({
    required this.id,
    required this.displayName,
    required this.bloodGroup,
    required this.bloodGroupVerified,
    required this.department,
    required this.hall,
    required this.isAvailable,
    this.phone,
    this.updatedAt,
  });

  factory BloodDonorRecord.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? updated;
    if (data['updatedAt'] is Timestamp) {
      updated = (data['updatedAt'] as Timestamp).toDate();
    }

    return BloodDonorRecord(
      id: id,
      displayName: data['displayName']?.toString() ?? 'Anonymous Volunteer',
      bloodGroup: data['bloodGroup']?.toString() ?? 'Unknown',
      bloodGroupVerified: data['bloodGroupVerified'] as bool? ?? false,
      department: data['department']?.toString() ?? 'General',
      hall: data['hall']?.toString() ?? 'Campus Resident',
      isAvailable: data['isAvailable'] as bool? ?? true,
      phone: data['phone']?.toString(),
      updatedAt: updated,
    );
  }
}

class BloodDonorDirectoryScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const BloodDonorDirectoryScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  ConsumerState<BloodDonorDirectoryScreen> createState() =>
      _BloodDonorDirectoryScreenState();
}

class _BloodDonorDirectoryScreenState
    extends ConsumerState<BloodDonorDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedBloodGroup = 'All';

  final List<String> _bloodGroups = [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _callDonor(BloodDonorRecord donor) {
    final hasPhone = donor.phone != null && donor.phone!.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: BaustColors.emergencyRed),
            ),
            const SizedBox(width: 10),
            const Text('Contact Blood Donor', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              donor.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${donor.department} • ${donor.hall}',
              style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPhone ? Icons.phone_android : Icons.privacy_tip_outlined,
                    size: 20,
                    color: hasPhone ? BaustColors.primaryArmyGreen : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasPhone ? donor.phone! : 'Phone hidden by donor for privacy',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: hasPhone ? BaustColors.textDark : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Donor Blood Group: ${donor.bloodGroup}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: BaustColors.emergencyRed,
              ),
            ),
            if (!hasPhone) ...[
              const SizedBox(height: 8),
              const Text(
                'This volunteer has chosen to hide their personal contact number. Please coordinate through BAUST Medical Center dispatch.',
                style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BaustColors.primaryArmyGreen,
              foregroundColor: Colors.white,
            ),
            icon: Icon(hasPhone ? Icons.call : Icons.local_hospital, size: 16),
            label: Text(hasPhone ? 'Dial Now' : 'Call Medical Center'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: BaustColors.primaryArmyGreen,
                  content: Text(
                    hasPhone
                        ? 'Simulating call to ${donor.displayName} (${donor.phone})'
                        : 'Calling BAUST Medical Center (${BaustEmergencyContacts.hotlineDisplay}) to request donor ${donor.displayName}',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _sendEmergencyRequest(BloodDonorRecord donor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency_outlined, color: BaustColors.emergencyRed),
            SizedBox(width: 8),
            Text('Emergency Blood Request', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Send an urgent in-app emergency alert to ${donor.displayName} (${donor.bloodGroup}) at ${donor.hall}?\n\n'
          'The volunteer will receive a high-priority notification to report to BAUST Medical Center.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BaustColors.emergencyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: BaustColors.successGreen,
                  content: Text(
                    'Emergency blood request dispatched to ${donor.displayName} (${donor.bloodGroup})!',
                  ),
                ),
              );
            },
            child: const Text('SEND SOS REQUEST'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Stream<QuerySnapshot<Map<String, dynamic>>>? donorStream;
    try {
      donorStream = FirebaseFirestore.instance
          .collection('blood_donors')
          .where('isAvailable', isEqualTo: true)
          .snapshots();
    } catch (_) {
      donorStream = null;
    }

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Blood Donor Directory — BAUST'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: donorStream,
        builder: (context, snapshot) {
          final List<BloodDonorRecord> allDonors = [];

          if (snapshot.hasData && snapshot.data != null) {
            for (final doc in snapshot.data!.docs) {
              allDonors.add(BloodDonorRecord.fromFirestore(doc.id, doc.data()));
            }
          }

          // Search and filter
          final query = _searchController.text.trim().toLowerCase();
          final displayedDonors = allDonors.where((donor) {
            final matchesGroup = _selectedBloodGroup == 'All' ||
                donor.bloodGroup.toUpperCase() == _selectedBloodGroup.toUpperCase();

            final matchesQuery = query.isEmpty ||
                donor.displayName.toLowerCase().contains(query) ||
                donor.hall.toLowerCase().contains(query) ||
                donor.department.toLowerCase().contains(query);

            return matchesGroup && matchesQuery;
          }).toList();

          final rareCount = allDonors.where((d) => d.bloodGroup.contains('-')).length;

          return Column(
            children: [
              // Header Overview Card
              Container(
                color: BaustColors.primaryArmyGreen,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            color: Colors.white,
                            size: 22,
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
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Self-reported blood groups - confirm before transfusion',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${allDonors.length} Active',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by volunteer name, dept, or hall...',
                          hintStyle: const TextStyle(fontSize: 13, color: BaustColors.textMuted),
                          prefixIcon: const Icon(Icons.search, color: BaustColors.primaryArmyGreen),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Blood Group Filter Chips
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _bloodGroups.map((group) {
                      final isSelected = _selectedBloodGroup == group;
                      final isNegative = group.contains('-');

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          label: Text(
                            group,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isNegative ? BaustColors.emergencyRed : BaustColors.textDark),
                            ),
                          ),
                          backgroundColor: isNegative ? Colors.red.shade50 : const Color(0xFFF1F5F9),
                          selectedColor: isNegative ? BaustColors.emergencyRed : BaustColors.primaryArmyGreen,
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : (isNegative ? Colors.red.shade200 : Colors.grey.shade300),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedBloodGroup = group;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Filter Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 15, color: BaustColors.successGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Minimal registry ($rareCount rare Rh-negative). Medical records private.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${displayedDonors.length} found',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: BaustColors.primaryArmyGreen,
                      ),
                    ),
                  ],
                ),
              ),

              // Donors List
              Expanded(
                child: displayedDonors.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bloodtype_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allDonors.isEmpty
                                    ? 'No active donors registered yet'
                                    : 'No donors found for "$_selectedBloodGroup"',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: BaustColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Students who volunteer in their Profile Settings appear here with protected privacy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: displayedDonors.length,
                        itemBuilder: (context, index) {
                          final donor = displayedDonors[index];
                          final isRare = donor.bloodGroup.contains('-');
                          final hasPhone = donor.phone != null && donor.phone!.trim().isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isRare ? Colors.red.shade200 : Colors.grey.shade200,
                                width: isRare ? 1.5 : 1.0,
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
                                      // Blood Group Avatar
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: isRare ? Colors.red.shade700 : BaustColors.emergencyRed,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: BaustColors.emergencyRed.withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            donor.bloodGroup,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Donor Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    donor.displayName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      color: BaustColors.textDark,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.amber.shade400),
                                                  ),
                                                  child: Text(
                                                    'Unverified',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber.shade900,
                                                    ),
                                                  ),
                                                ),
                                                if (isRare) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.red.shade300),
                                                    ),
                                                    child: const Text(
                                                      'RARE RH-',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: BaustColors.emergencyRed,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              donor.department,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: BaustColors.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.apartment,
                                                  size: 13,
                                                  color: BaustColors.primaryArmyGreen,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    donor.hall,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: BaustColors.textDark,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  // Action Row
                                  Row(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            hasPhone ? Icons.phone : Icons.phone_disabled,
                                            size: 13,
                                            color: hasPhone ? BaustColors.successGreen : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            hasPhone ? 'Contact available' : 'Phone hidden',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: hasPhone ? BaustColors.successGreen : Colors.grey.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          side: BorderSide(
                                            color: hasPhone ? BaustColors.primaryArmyGreen : Colors.grey.shade400,
                                          ),
                                          foregroundColor:
                                              hasPhone ? BaustColors.primaryArmyGreen : Colors.grey.shade700,
                                        ),
                                        icon: Icon(hasPhone ? Icons.call : Icons.info_outline, size: 14),
                                        label: Text(hasPhone ? 'Contact' : 'Details', style: const TextStyle(fontSize: 12)),
                                        onPressed: () => _callDonor(donor),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: BaustColors.emergencyRed,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                        icon: const Icon(Icons.emergency_outlined, size: 14),
                                        label: const Text('SOS Request', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _sendEmergencyRequest(donor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
