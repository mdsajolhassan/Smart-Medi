import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../controllers/auth_controller.dart';
import 'signup_screen.dart';
import '../../../blood_bank/presentation/screens/blood_donor_directory.dart';
import '../../../medical_onboarding_ai/presentation/screens/medical_onboarding_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Student Form Controllers
  final _studentIdController = TextEditingController();
  final _studentPasswordController = TextEditingController();
  bool _obscureStudentPassword = true;

  // Staff Form Controllers
  final _staffEmailController = TextEditingController();
  final _staffPasswordController = TextEditingController();
  bool _obscureStaffPassword = true;

  final _formKeyStudent = GlobalKey<FormState>();
  final _formKeyStaff = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(authControllerProvider);
      if (current.status == AuthStatus.error && current.errorMessage != null) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(current.errorMessage!)),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentIdController.dispose();
    _studentPasswordController.dispose();
    _staffEmailController.dispose();
    _staffPasswordController.dispose();
    super.dispose();
  }

  void _handleStudentLogin() {
    if (_formKeyStudent.currentState?.validate() ?? false) {
      ref.read(authControllerProvider.notifier).signInStudent(
            studentIdentifier: _studentIdController.text,
            password: _studentPasswordController.text,
          );
    }
  }

  void _handleStaffLogin() {
    if (_formKeyStaff.currentState?.validate() ?? false) {
      ref.read(authControllerProvider.notifier).signInStaffOrAdmin(
            email: _staffEmailController.text,
            password: _staffPasswordController.text,
          );
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _studentIdController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Student ID or institutional email to receive a password reset link.',
              style: TextStyle(fontSize: 13, color: BaustColors.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(
                labelText: 'Student ID or Email',
                hintText: 'e.g. Student ID',
                prefixIcon: Icon(Icons.email_outlined, color: BaustColors.primaryNavy),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BaustColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BaustColors.primaryNavy,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(ctx);
                final sent = await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: sent ? BaustColors.successGreen : BaustColors.emergencyRed,
                    content: Text(
                      sent
                          ? 'Password reset link sent to your registered institutional email.'
                          : 'Failed to dispatch reset link. Please check the ID/Email.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Listen for auth errors
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: BaustColors.surfaceBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Icon
                Image.asset(
                  'assets/branding/smart_medi_icon_1024.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),

                // Primary Brand Title: "Smart Medi"
                const Text(
                  'Smart Medi',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: BaustColors.primaryNavy,
                    letterSpacing: -0.8,
                  ),
                ),

                // Secondary Subtitle: "BAUST Medical Center"
                const SizedBox(height: 2),
                const Text(
                  'BAUST Medical Center',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BaustColors.navyLight,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Campus Healthcare & Emergency Management System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: BaustColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                // Card Container with TabBar
                Card(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Custom Tab Bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: BaustColors.primaryNavy,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: BaustColors.textMuted,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            tabs: const [
                              Tab(text: 'Student Access'),
                              Tab(text: 'Faculty / Staff'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // TabBar Views
                        SizedBox(
                          height: 405,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // 1. Student Login Form
                              Form(
                                key: _formKeyStudent,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _studentIdController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Student ID or BAUST Email',
                                        hintText: 'e.g. Student ID',
                                        prefixIcon: Icon(
                                          Icons.badge_outlined,
                                          color: BaustColors.primaryNavy,
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Please enter your Student ID or Email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _studentPasswordController,
                                      obscureText: _obscureStudentPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: BaustColors.primaryNavy,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureStudentPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: BaustColors.textMuted,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureStudentPassword =
                                                  !_obscureStudentPassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),

                                    // Forgot Password Action
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: _showForgotPasswordDialog,
                                        child: const Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: BaustColors.navyLight,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: BaustColors.primaryNavy,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: isLoading ? null : _handleStudentLogin,
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'LOG IN AS STUDENT',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                    ),

                                    const SizedBox(height: 12),

                                    // OR Divider
                                    Row(
                                      children: [
                                        Expanded(child: Divider(color: Colors.grey.shade300)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Text(
                                            'OR',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                        Expanded(child: Divider(color: Colors.grey.shade300)),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Prominent "Continue with Google" Button
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: BaustColors.textDark,
                                        minimumSize: const Size(double.infinity, 48),
                                        side: BorderSide(color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: Image.network(
                                        'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                                        height: 20,
                                        width: 20,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.g_mobiledata,
                                          size: 24,
                                          color: Colors.red,
                                        ),
                                      ),
                                      label: const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      onPressed: isLoading
                                          ? null
                                          : () => ref
                                              .read(authControllerProvider.notifier)
                                              .signInWithGoogle(),
                                    ),

                                    const SizedBox(height: 12),

                                    // Don't have an account? Sign Up Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "Don't have an account?",
                                          style: TextStyle(
                                            color: BaustColors.textMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.only(left: 6),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const SignupScreen(),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Sign Up',
                                            style: TextStyle(
                                              color: BaustColors.primaryNavy,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Staff / Faculty Form
                              Form(
                                key: _formKeyStaff,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _staffEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Official Faculty Email',
                                        hintText: 'advisor@baust.edu.bd',
                                        prefixIcon: Icon(
                                          Icons.alternate_email,
                                          color: BaustColors.primaryNavy,
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Please enter your official university email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _staffPasswordController,
                                      obscureText: _obscureStaffPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: BaustColors.primaryNavy,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureStaffPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: BaustColors.textMuted,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureStaffPassword =
                                                  !_obscureStaffPassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: BaustColors.navyDark,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: isLoading ? null : _handleStaffLogin,
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'LOG IN AS FACULTY / STAFF',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No account? Contact IT / SuperAdmin for credentials.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: BaustColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sandbox Demo: strictly gated behind SHOW_DEV_SANDBOX (hidden in default builds)
                if (const bool.fromEnvironment('SHOW_DEV_SANDBOX', defaultValue: false)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.developer_mode, size: 14, color: BaustColors.navyLight),
                            SizedBox(width: 6),
                            Text(
                              'Dev Sandbox (Debug Mode Only):',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: BaustColors.navyDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Student', style: TextStyle(fontSize: 11)),
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .switchDemoRoleForTesting('student'),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Doctor', style: TextStyle(fontSize: 11)),
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .switchDemoRoleForTesting('doctor'),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Pharmacist', style: TextStyle(fontSize: 11)),
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .switchDemoRoleForTesting('pharmacist'),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Faculty', style: TextStyle(fontSize: 11)),
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .switchDemoRoleForTesting('staff'),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('SuperAdmin', style: TextStyle(fontSize: 11)),
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .switchDemoRoleForTesting('superadmin'),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.volunteer_activism, size: 13, color: BaustColors.emergencyRed),
                              label: const Text('Blood Bank', style: TextStyle(fontSize: 11)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BloodDonorDirectoryScreen(),
                                ),
                              ),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.smart_toy_outlined, size: 13, color: BaustColors.primaryNavy),
                              label: const Text('🤖 AI Test', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MedicalOnboardingScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Institutional Security Footnote
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: BaustColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Bangladesh Army University of Science & Technology',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
