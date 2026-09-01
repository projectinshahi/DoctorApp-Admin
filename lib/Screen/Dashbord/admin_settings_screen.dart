import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_account_model.dart';
import '../../services/admin_account_service.dart';
import '../../widget/shimmer_loading.dart';

/// The admin's own account: name, email, password.
///
/// It exists because the only previous way to change an admin password was a
/// script against the database - which is how the account got locked out once
/// already.
///
/// Deliberately absent: a "sign out everywhere" button. Admin auth is
/// stateless, so tokens minted before a password change stay valid until they
/// expire. A button that quietly did nothing would be worse than no button,
/// so the limitation is written on the screen instead.
class AdminSettingsScreen extends StatefulWidget {
  /// Called when the server says this session is over - a 401 (the account is
  /// gone) or a 403 (it is disabled).
  final VoidCallback? onSessionEnded;

  const AdminSettingsScreen({super.key, this.onSessionEnded});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _service = AdminAccountService();

  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AdminAccount? _admin;
  bool _isLoading = false;
  String? _loadError;

  bool _isSavingProfile = false;
  String? _profileError;
  String? _profileSuccess;

  bool _isSavingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;

  /// Set when the server blamed one specific password field, so the message
  /// renders under that input rather than in a banner above both.
  String? _passwordErrorField;

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await _service.getMe();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess && result.admin != null) {
        _admin = result.admin;
        _nameController.text = result.admin!.name ?? '';
        _emailController.text = result.admin!.email;
      } else {
        _loadError = result.errorMessage;
      }
    });

    if (result.mustReauthenticate) widget.onSessionEnded?.call();
  }

  // ── Profile ──────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final current = _admin;
    if (current == null) return;

    final nameChanged = name != (current.name ?? '');
    final emailChanged = email.toLowerCase() != current.email.toLowerCase();

    if (!nameChanged && !emailChanged) {
      setState(() {
        _profileError = 'Nothing to update — change a field first.';
        _profileSuccess = null;
      });
      return;
    }

    // The email is the login. Nothing signs out at this moment, so the
    // consequence lands hours later at the next login - which is exactly why
    // it has to be said before the request, not after.
    if (emailChanged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change your login email?'),
          content: Text(
            'You sign in with this address. From your next login you must use '
            '"$email" — the old one will not work.\n\n'
            'You stay signed in right now, so nothing will look different '
            'until then.',
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
              child: const Text('Change email'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isSavingProfile = true;
      _profileError = null;
      _profileSuccess = null;
    });

    final result = await _service.updateProfile(
      name: nameChanged ? name : null,
      email: emailChanged ? email : null,
    );

    if (!mounted) return;
    setState(() {
      _isSavingProfile = false;
      if (result.isSuccess && result.admin != null) {
        _admin = result.admin;
        _nameController.text = result.admin!.name ?? '';
        _emailController.text = result.admin!.email;
        _profileSuccess = result.emailChanged
            ? 'Saved. Sign in with "${result.admin!.email}" from now on.'
            : 'Saved.';
      } else {
        _profileError = result.errorMessage;
      }
    });

    if (result.mustReauthenticate) widget.onSessionEnded?.call();
  }

  // ── Password ─────────────────────────────────────────────────────

  Future<void> _savePassword() async {
    if (!_passwordKey.currentState!.validate()) return;

    setState(() {
      _isSavingPassword = true;
      _passwordError = null;
      _passwordErrorField = null;
      _passwordSuccess = null;
    });

    final result = await _service.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() {
      _isSavingPassword = false;
      if (result.isSuccess) {
        // The service already stored the fresh token, so this session keeps
        // working - no bounce to login mid-task.
        _passwordSuccess = '${result.message} — you are still signed in.';
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _passwordError = result.message;
        _passwordErrorField = result.fieldError;
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero);
    }

    if (_loadError != null) {
      // A 404 is the endpoint not being deployed, not a broken account.
      final notDeployed = _loadError!.contains('404');
      return _Banner(
        color: notDeployed ? const Color(0xFFB8860B) : LmsColors.error,
        icon: notDeployed
            ? Icons.cloud_off_rounded
            : Icons.error_outline_rounded,
        title: notDeployed
            ? 'Account settings are not deployed yet'
            : 'Could not load your account',
        body: notDeployed
            ? 'This server does not have /admin/me yet. Your sign-in is '
                'unaffected — only this screen needs the newer build.'
            : _loadError,
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }

    final admin = _admin;
    if (admin == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Your own admin account. Changes here affect how you sign in.',
              style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
            ),
            const SizedBox(height: 22),

            _profileCard(admin),
            const SizedBox(height: 18),
            _passwordCard(),
            const SizedBox(height: 18),
            _tokenNotice(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(AdminAccount admin) {
    return _Card(
      title: 'Profile',
      child: Form(
        key: _profileKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_nameController, 'Name'),
            const SizedBox(height: 14),
            _field(
              _emailController,
              'Email (your login)',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'An email is required';
                // Deliberately loose: the server is the authority on what it
                // accepts, and a strict client regex rejects valid addresses.
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Read-only on purpose: role and status decide what this account
            // may do, so a stolen token must not be able to promote itself.
            Row(
              children: [
                Expanded(child: _readOnly('Role', admin.role)),
                const SizedBox(width: 12),
                Expanded(
                  child: _readOnly(
                    'Status',
                    admin.status,
                    color: admin.isActive ? LmsColors.success : LmsColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Role and status are set by the server and cannot be edited here.',
              style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
            ),

            if (_profileError != null) ...[
              const SizedBox(height: 14),
              _Banner(
                color: LmsColors.error,
                icon: Icons.error_outline_rounded,
                title: _profileError!,
              ),
            ],
            if (_profileSuccess != null) ...[
              const SizedBox(height: 14),
              _Banner(
                color: LmsColors.success,
                icon: Icons.check_circle_rounded,
                title: _profileSuccess!,
              ),
            ],

            const SizedBox(height: 18),
            _button('Save changes', _isSavingProfile, _saveProfile),
          ],
        ),
      ),
    );
  }

  Widget _passwordCard() {
    return _Card(
      title: 'Password',
      child: Form(
        key: _passwordKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              _currentPasswordController,
              'Current password',
              obscure: !_showCurrent,
              onToggleObscure: () => setState(() => _showCurrent = !_showCurrent),
              // Shown under this field because the server names it: "invalid
              // credentials" tells a signed-in admin nothing.
              errorText: _passwordErrorField == PasswordChangeResult.fieldCurrent
                  ? _passwordError
                  : null,
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 4),
            const Text(
              'Required even though you are signed in — it guards a session '
              'left open on a shared machine.',
              style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
            ),
            const SizedBox(height: 14),

            _field(
              _newPasswordController,
              'New password',
              obscure: !_showNew,
              onToggleObscure: () => setState(() => _showNew = !_showNew),
              errorText: _passwordErrorField == PasswordChangeResult.fieldNew
                  ? _passwordError
                  : null,
              validator: (v) {
                final value = v ?? '';
                if (value.length < 8) {
                  return 'New password must be at least 8 characters';
                }
                if (value == _currentPasswordController.text) {
                  return 'The new password must be different from the current one';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),
            // Checked here only - the API takes two fields, so a mismatch is
            // a slip to catch in the browser rather than a round trip.
            _field(
              _confirmPasswordController,
              'Confirm new password',
              obscure: !_showConfirm,
              onToggleObscure: () =>
                  setState(() => _showConfirm = !_showConfirm),
              validator: (v) => (v ?? '') == _newPasswordController.text
                  ? null
                  : 'The two new passwords do not match',
            ),

            if (_passwordError != null && _passwordErrorField == null) ...[
              const SizedBox(height: 14),
              _Banner(
                color: LmsColors.error,
                icon: Icons.error_outline_rounded,
                title: _passwordError!,
              ),
            ],
            if (_passwordSuccess != null) ...[
              const SizedBox(height: 14),
              _Banner(
                color: LmsColors.success,
                icon: Icons.check_circle_rounded,
                title: _passwordSuccess!,
              ),
            ],

            const SizedBox(height: 18),
            _button('Change password', _isSavingPassword, _savePassword),
          ],
        ),
      ),
    );
  }

  /// The limitation, written down instead of hidden behind a button that
  /// would not work.
  Widget _tokenNotice() => const _Banner(
        color: LmsColors.textGrey,
        icon: Icons.info_outline_rounded,
        title: 'Other sessions stay signed in',
        body: 'Admin sign-in is stateless, so a token issued before a password '
            'change keeps working until it expires — up to 8 hours. Changing '
            'your password is enough for "I want a better one", but not for '
            '"my password leaked".',
      );

  // ── Small pieces ─────────────────────────────────────────────────

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: LmsColors.bg,
            errorText: errorText,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: LmsColors.textGrey,
                    ),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: LmsColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: LmsColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: LmsColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _readOnly(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: LmsColors.bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: LmsColors.border),
          ),
          child: Row(
            children: [
              Text(
                value.isEmpty ? 'Unknown' : value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color ?? LmsColors.textDark,
                ),
              ),
              const Spacer(),
              const Icon(Icons.lock_outline_rounded,
                  size: 15, color: LmsColors.textGrey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _button(String label, bool busy, VoidCallback onPressed) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: LmsColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LmsColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color)),
                if (body != null) ...[
                  const SizedBox(height: 3),
                  Text(body!,
                      style: TextStyle(
                          fontSize: 12.5, height: 1.4, color: color)),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
