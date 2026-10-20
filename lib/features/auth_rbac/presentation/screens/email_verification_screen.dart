import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../controllers/auth_controller.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    setState(() => _resendCooldown = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 1) {
          _resendCooldown--;
        } else {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleCheckVerification() async {
    setState(() => _isChecking = true);
    await ref.read(authControllerProvider.notifier).reloadUser();
    if (!mounted) return;
    setState(() => _isChecking = false);

    final user = ref.read(authControllerProvider.notifier).auth.currentUser;
    if (user != null && !user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('Email is not yet verified. Please click the link sent to your inbox.'),
        ),
      );
    }
  }

  Future<void> _handleResendEmail() async {
    if (_resendCooldown > 0) return;
    setState(() => _isResending = true);

    try {
      await ref.read(authControllerProvider.notifier).resendVerificationEmail();
      if (!mounted) return;
      _startCooldown(60);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: BaustColors.successGreen,
          content: Text('Verification link dispatched! Please check your inbox and spam folder.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: BaustColors.emergencyRed,
          content: Text('Failed to resend verification link: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final email = authState.userProfile?.email ??
        ref.read(authControllerProvider.notifier).auth.currentUser?.email ??
        'your registered email';

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BaustColors.primaryNavy.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          size: 48,
                          color: BaustColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Email Verification Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A confirmation link was sent to:\n$email\n\nPlease check your inbox and confirm your address before continuing to the university healthcare portal.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: BaustColors.textMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BaustColors.primaryNavy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: const Text(
                          "I'VE VERIFIED MY EMAIL",
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        onPressed: _isChecking ? null : _handleCheckVerification,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BaustColors.primaryNavy,
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(color: BaustColors.primaryNavy),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _resendCooldown > 0
                              ? 'RESEND EMAIL (${_resendCooldown}s)'
                              : 'RESEND VERIFICATION EMAIL',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        onPressed: (_resendCooldown > 0 || _isResending) ? null : _handleResendEmail,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                        icon: const Icon(Icons.logout, size: 16, color: BaustColors.textMuted),
                        label: const Text(
                          'Sign In with another account',
                          style: TextStyle(color: BaustColors.textMuted, fontSize: 12),
                        ),
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
