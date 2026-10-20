import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../controllers/auth_controller.dart';

class WaitingForApprovalScreen extends ConsumerStatefulWidget {
  const WaitingForApprovalScreen({super.key});

  @override
  ConsumerState<WaitingForApprovalScreen> createState() =>
      _WaitingForApprovalScreenState();
}

class _WaitingForApprovalScreenState
    extends ConsumerState<WaitingForApprovalScreen> {
  bool _isChecking = false;

  Future<void> _checkApprovalStatus() async {
    setState(() => _isChecking = true);
    try {
      await ref.read(authControllerProvider.notifier).reloadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.primaryArmyGreen,
          content: Text('Checking account verification status...'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).userProfile;
    final isRejected = user?.verificationStatus == 'rejected';

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: Text(isRejected ? 'Account Not Approved' : 'Account Pending Approval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Icon
                      Image.asset(
                        'assets/branding/smart_medi_icon_1024.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Smart Medi',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: BaustColors.primaryNavy,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'BAUST Medical Center',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BaustColors.navyLight,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isRejected ? 'Account Not Approved' : 'Waiting for Approval',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isRejected ? BaustColors.emergencyRed : BaustColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Account: ${user?.email ?? "User"}\nStatus: ${isRejected ? "Account Rejected" : "Verification Pending"}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BaustColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          isRejected
                              ? 'Your account was not approved. Please contact the BAUST Medical Center.'
                              : 'Your account is awaiting approval by the administrator.\n\n'
                                  'While pending, access to clinical medical histories, the blood donor directory, and campus SOS emergency services is restricted.',
                          style: const TextStyle(fontSize: 13, height: 1.45),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!isRejected) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BaustColors.primaryNavy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh, size: 20),
                            label: Text(
                              _isChecking ? 'Checking...' : 'Check Approval Status',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isChecking ? null : _checkApprovalStatus,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextButton.icon(
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign Out'),
                        style: TextButton.styleFrom(
                          foregroundColor: BaustColors.emergencyRed,
                        ),
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
