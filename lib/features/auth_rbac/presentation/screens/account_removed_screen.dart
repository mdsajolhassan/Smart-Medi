import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/baust_constants.dart';
import '../controllers/auth_controller.dart';

/// Shown to accounts an admin has removed. They can only sign out.
class AccountRemovedScreen extends ConsumerWidget {
  const AccountRemovedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.shade50),
                  child: const Icon(Icons.person_off_rounded, size: 44, color: BaustColors.emergencyRed),
                ),
                const SizedBox(height: 18),
                const Text('Account deactivated', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'An administrator has removed this account from Smart Medi. If you think this is a mistake, '
                  'please contact the BAUST Medical Center or ICT Cell.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BaustColors.textMuted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
