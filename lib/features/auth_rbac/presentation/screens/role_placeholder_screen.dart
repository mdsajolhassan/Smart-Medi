import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../controllers/auth_controller.dart';

class RolePlaceholderScreen extends ConsumerWidget {
  final String role;
  final String? title;

  const RolePlaceholderScreen({
    super.key,
    required this.role,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.userProfile;
    final displayRole = role.toUpperCase();

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      appBar: AppBar(
        title: Text(title ?? '$displayRole Dashboard'),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: BaustColors.primaryNavy.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.dashboard_customize_outlined,
                          size: 54,
                          color: BaustColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Role dashboard coming soon',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: BaustColors.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome, ${user?.displayName ?? "User"}.\nYou are signed in with the "$role" role. Dedicated management and clinical workflows for this role are scheduled for Phase 2.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: BaustColors.textMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BaustColors.emergencyRed,
                          side: const BorderSide(color: BaustColors.emergencyRed),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text(
                          'SIGN OUT',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
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
