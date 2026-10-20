import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/baust_constants.dart';
import '../../../../core/config/auth_config.dart';
import '../controllers/auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _selectedDepartment = AuthConfig.academicDepartments.first;
  String _selectedHall = AuthConfig.residentialHalls.first;

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegistration() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authControllerProvider.notifier).signUpStudent(
            fullName: _nameController.text.trim(),
            studentRoll: _rollController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            department: _selectedDepartment,
            residentialHall: _selectedHall,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Listen for error messages
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BaustColors.emergencyRed,
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
      appBar: AppBar(
        title: const Text('Student Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: BaustColors.primaryNavy,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'BAUST Medical Center Student Portal',
                style: TextStyle(
                  fontSize: 14,
                  color: BaustColors.navyLight,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),

              // Registration Form Card
              Card(
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Full Name
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'e.g. Full Name',
                            prefixIcon: Icon(Icons.person_outline, color: BaustColors.primaryNavy),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Student ID / Roll
                        TextFormField(
                          controller: _rollController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Student ID / Roll',
                            hintText: 'e.g. Student ID',
                            prefixIcon: Icon(Icons.badge_outlined, color: BaustColors.primaryNavy),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your Student Roll';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            // Automatically suggest institutional email if email is empty
                            if (_emailController.text.isEmpty ||
                                _emailController.text.endsWith('@baust.edu.bd')) {
                              _emailController.text = '${val.trim()}@baust.edu.bd';
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Institutional Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Institutional Email',
                            hintText: 'student_id@baust.edu.bd',
                            prefixIcon: Icon(Icons.email_outlined, color: BaustColors.primaryNavy),
                          ),
                          validator: (val) {
                            if (val == null || !val.contains('@')) {
                              return 'Please provide a valid institutional email';
                            }
                            if (!AuthConfig.isEmailAllowed(val)) {
                              return 'Please sign in with your university email.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Department Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDepartment,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Academic Department',
                            prefixIcon: Icon(Icons.school_outlined, color: BaustColors.primaryNavy),
                          ),
                          items: AuthConfig.academicDepartments.map((dept) {
                            return DropdownMenuItem(
                              value: dept,
                              child: Text(dept, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDepartment = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Residential Hall Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedHall,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Residential Hall',
                            prefixIcon: Icon(Icons.apartment_outlined, color: BaustColors.primaryNavy),
                          ),
                          items: AuthConfig.residentialHalls.map((hall) {
                            return DropdownMenuItem(
                              value: hall,
                              child: Text(hall, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedHall = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, color: BaustColors.primaryNavy),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: BaustColors.textMuted,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_reset, color: BaustColors.primaryNavy),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: BaustColors.textMuted,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (val) {
                            if (val != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Register Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BaustColors.primaryNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isLoading ? null : _handleRegistration,
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
                                  'REGISTER STUDENT ACCOUNT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Already have an account row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: BaustColors.textMuted, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Log In',
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
      ),
    );
  }
}
