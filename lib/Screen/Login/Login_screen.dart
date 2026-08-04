import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../provider/admin_auth_provider.dart';
import '../Dashbord/Dashbord_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(AdminAuthProvider adminProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await adminProvider.adminLogin(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome, ${adminProvider.authResult?.admin.name ?? "Admin"}!',
          ),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(adminProvider.errorMessage ?? 'Login failed'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Card width: full-bleed-ish on phones, a fixed comfortable width on
    // tablet/desktop so the form doesn't stretch edge-to-edge on wide screens.
    final cardMaxWidth = LmsResponsive.value<double>(
      context,
      mobile: double.infinity,
      tablet: 460,
      desktop: 420,
    );

    final cardPadding = LmsResponsive.value<double>(
      context,
      mobile: 22,
      tablet: 30,
      desktop: 32,
    );

    final outerHPadding = LmsResponsive.value<double>(
      context,
      mobile: 16,
      desktop: 20,
    );

    final brandFontSize = LmsResponsive.font(
      context,
      LmsResponsive.value<double>(context, mobile: 18, desktop: 20),
    );

    return Scaffold(
      backgroundColor: LmsColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 40, horizontal: outerHPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Brand mark, matches the sidebar header ─────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: LmsColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "SAS LMS admin",
                      style: TextStyle(
                        fontSize: brandFontSize,
                        fontWeight: FontWeight.w800,
                        color: LmsColors.textDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ── Card ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: LmsColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LmsColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Consumer<AdminAuthProvider>(
                      builder: (context, adminProvider, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Welcome back",
                              style: TextStyle(
                                fontSize: LmsResponsive.font(context, 24),
                                fontWeight: FontWeight.w800,
                                color: LmsColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Sign in to manage courses, students and quizzes.",
                              style: TextStyle(
                                fontSize: 13.5,
                                color: LmsColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 28),

                            if (adminProvider.errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: LmsColors.errorBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: LmsColors.errorBorder),
                                ),
                                child: Text(
                                  adminProvider.errorMessage!,
                                  style: const TextStyle(
                                    color: LmsColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            _fieldLabel("Email"),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !adminProvider.isLoading,
                              decoration: _inputDecoration(
                                hint: "you@school.edu",
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return "Email is required";
                                }
                                if (!v.contains("@")) {
                                  return "Enter a valid email";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            _fieldLabel("Password"),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              enabled: !adminProvider.isLoading,
                              decoration: _inputDecoration(
                                hint: "••••••••",
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: LmsColors.textGrey,
                                  ),
                                  onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return "Password is required";
                                }
                                return null;
                              },
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    color: LmsColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: adminProvider.isLoading
                                    ? null
                                    : () => _handleLogin(adminProvider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LmsColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: adminProvider.isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  'Admin Login',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  "Admin access only · contact IT for an account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: LmsColors.textGrey.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: LmsColors.textDark,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: LmsColors.textGrey, fontSize: 14),
      prefixIcon: Icon(icon, size: 19, color: LmsColors.textGrey),
      suffixIcon: suffix,
      filled: true,
      fillColor: LmsColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LmsColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LmsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LmsColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD92D20)),
      ),
    );
  }
}