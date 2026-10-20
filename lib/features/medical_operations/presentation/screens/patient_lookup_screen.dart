import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../auth_rbac/presentation/controllers/auth_controller.dart';
import '../../../dashboard/presentation/screens/detailed_medical_history_screen.dart';
import '../widgets/student_department_directory.dart';

class PatientLookupScreen extends ConsumerStatefulWidget {
  final FirebaseFirestore? firestore;
  final String? initialQuery;
  final Future<List<Map<String, dynamic>>> Function(String query)? onSearchOverride;
  final bool showAppBar;

  const PatientLookupScreen({
    super.key,
    this.firestore,
    this.initialQuery,
    this.onSearchOverride,
    this.showAppBar = true,
  });

  @override
  ConsumerState<PatientLookupScreen> createState() => _PatientLookupScreenState();
}

class _PatientLookupScreenState extends ConsumerState<PatientLookupScreen> {
  late final TextEditingController _queryController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _notFound = false;
  Map<String, dynamic>? _foundData;
  String? _foundUid;
  String _searchedQuery = '';

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchStudent();
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _searchStudent() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _notFound = false;
      _foundData = null;
      _foundUid = null;
      _searchedQuery = query;
    });

    try {
      if (widget.onSearchOverride != null) {
        final list = await widget.onSearchOverride!(query);
        if (list.isEmpty) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _notFound = true;
            });
          }
          return;
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
            _foundData = list.first;
            _foundUid = list.first['uid']?.toString() ?? list.first['studentId']?.toString() ?? 'test_uid';
          });
        }
        return;
      }

      // 1. Strictly query students collection by studentId
      var snapshot = await _db
          .collection('students')
          .where('studentId', isEqualTo: query)
          .limit(1)
          .get();

      // 2. If not found, strictly query students collection by studentRoll
      if (snapshot.docs.isEmpty) {
        snapshot = await _db
            .collection('students')
            .where('studentRoll', isEqualTo: query)
            .limit(1)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _notFound = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _foundData = snapshot.docs.first.data();
          _foundUid = snapshot.docs.first.id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load student record. Please verify network connection or permissions.';
        });
      }
    }
  }

  Future<void> _viewPatientHistory(Map<String, dynamic> data, String studentUid) async {
    final authState = ref.read(authControllerProvider);
    final doctorUid = authState.userProfile?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'unknown_doctor';
    final doctorName = authState.userProfile?.displayName ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'Dr. BAUST Medical Center';
    final studentId = data['studentId'] ?? data['studentRoll'] ?? _searchedQuery;

    // Record audit access log
    try {
      await _db.collection('access_logs').add({
        'doctorUid': doctorUid,
        'doctorName': doctorName,
        'studentUid': studentUid,
        'studentId': studentId,
        'action': 'view_history',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PatientLookup] Notice recording access log: $e');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailedMedicalHistoryScreen(
          studentUid: studentUid,
          patientProfile: data,
          isDoctorView: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget scrollContent = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Search Input Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_search_outlined, color: BaustColors.primaryNavy, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'SEARCH STUDENT RECORD',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: BaustColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Search strictly by official Student ID or Roll number to open the clinical profile.',
                    style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Enter Student ID (e.g. 0802420205101137)',
                            prefixIcon: const Icon(Icons.badge_outlined, color: BaustColors.primaryNavy),
                            suffixIcon: _queryController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _queryController.clear();
                                      setState(() {
                                        _foundData = null;
                                        _foundUid = null;
                                        _notFound = false;
                                        _errorMessage = null;
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onSubmitted: (_) => _searchStudent(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BaustColors.primaryNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search, size: 20),
                          label: Text(_isLoading ? 'Searching...' : 'Search'),
                          onPressed: _isLoading ? null : _searchStudent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content Area based on state
            if (_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text(
                      'Searching student records...',
                      style: TextStyle(fontSize: 13, color: BaustColors.textMuted),
                    ),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 40, color: Colors.red.shade700),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                    ),
                  ],
                ),
              )
            else if (_notFound)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.search_off, size: 48, color: BaustColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'No student found with this ID',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BaustColors.textDark),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ensure the student roll number is entered correctly without letters or spaces.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                    ),
                  ],
                ),
              )
            else if (_foundData != null && _foundUid != null)
              _buildResultCard(_foundData!, _foundUid!)
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.person_pin, size: 44, color: BaustColors.primaryNavy),
                    SizedBox(height: 10),
                    Text(
                      'Ready for Patient Lookup',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: BaustColors.textDark),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Enter a Student ID or Roll number above to look up patient details and medical history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: BaustColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: const [
                  Icon(Icons.menu_book_outlined, size: 18, color: BaustColors.primaryNavy),
                  SizedBox(width: 8),
                  Text(
                    'STUDENT DIRECTORY BY DEPARTMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: BaustColors.primaryNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Explore registered students across academic faculties or tap any student to review their medical record.',
                style: TextStyle(fontSize: 11, color: BaustColors.textMuted),
              ),
              const SizedBox(height: 12),
              StudentDepartmentDirectory(
                firestore: widget.firestore,
                onStudentSelected: (student, uid) => _viewPatientHistory(student, uid),
              ),
            ],
          ],
        ),
      );

    if (!widget.showAppBar) {
      return Container(
        color: BaustColors.surfaceBg,
        child: scrollContent,
      );
    }

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Patient Lookup — BAUST Medical Center'),
      ),
      body: scrollContent,
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data, String uid) {

    final String name = (data['displayName']?.toString().trim().isNotEmpty ?? false)
        ? data['displayName'].toString().trim()
        : 'Not found - confirm with patient';

    final String studentId = (data['studentId']?.toString().trim().isNotEmpty ?? false)
        ? data['studentId'].toString().trim()
        : ((data['studentRoll']?.toString().trim().isNotEmpty ?? false)
            ? data['studentRoll'].toString().trim()
            : 'Not found - confirm with patient');

    final String department = (data['department']?.toString().trim().isNotEmpty ?? false)
        ? data['department'].toString().trim()
        : 'Not found - confirm with patient';

    final String level = (data['level']?.toString().trim().isNotEmpty ?? false)
        ? data['level'].toString().trim()
        : 'Not found - confirm with patient';

    final String term = (data['term']?.toString().trim().isNotEmpty ?? false)
        ? data['term'].toString().trim()
        : 'Not found - confirm with patient';

    final String hall = (data['residentialHall']?.toString().trim().isNotEmpty ?? false)
        ? data['residentialHall'].toString().trim()
        : 'Not found - confirm with patient';

    final String phone = (data['phone']?.toString().trim().isNotEmpty ?? false)
        ? data['phone'].toString().trim()
        : 'Not found - confirm with patient';

    final String bloodGroup = (data['bloodGroup']?.toString().trim().isNotEmpty ?? false)
        ? data['bloodGroup'].toString().trim()
        : 'Not found - confirm with patient';

    return InkWell(
      onTap: () => _viewPatientHistory(data, uid),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BaustColors.primaryArmyGreen.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: BaustColors.primaryArmyGreen.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & ID + Blood Group chips
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: BaustColors.primaryNavy.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: BaustColors.primaryNavy, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Student ID: $studentId',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BaustColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: bloodGroup != 'Not found - confirm with patient'
                            ? BaustColors.emergencyRed
                            : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bloodGroup,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Unverified',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // Metadata rows
            _buildMetaRow(Icons.school_outlined, 'Department', department),
            const SizedBox(height: 8),
            _buildMetaRow(Icons.calendar_today_outlined, 'Level / Term', '$level / $term'),
            const SizedBox(height: 8),
            _buildMetaRow(Icons.apartment_outlined, 'Residential Hall', hall),
            const SizedBox(height: 8),
            _buildMetaRow(Icons.phone_outlined, 'Phone', phone),

            const SizedBox(height: 18),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BaustColors.primaryArmyGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.history_edu, size: 20),
                label: const Text(
                  'View Patient Medical History',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _viewPatientHistory(data, uid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: BaustColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: BaustColors.textMuted),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 12, color: BaustColors.textMuted)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BaustColors.textDark),
          ),
        ),
      ],
    );
  }
}
