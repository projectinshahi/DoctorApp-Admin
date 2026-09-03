import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';
import '../models/admin_student_model.dart';
import '../services/admin_student_service.dart';

/// Blocking and signing out, shared by the student list and the detail screen.
///
/// Both live here rather than on each screen because the two actions are easy
/// to confuse and the difference is carried entirely by their wording and
/// styling. Two copies would drift, and the copy that drifted would be the one
/// telling an admin that signing a student out is a punishment.
///
///   Block            a punishment. Destructive styling, names the student,
///                    revokes every session and refuses their next login.
///   Sign out         help. Plain styling, light confirm. This is the fix for
///                    a student locked out by the single-device rule after
///                    losing a phone - they sign straight back in.

const _blockedColor = Color(0xFFB42318);
const _unverifiedColor = Color(0xFFFF9F43);

Color statusColor(AdminStudentModel student) {
  switch (student.statusValue) {
    case StudentStatus.verified:
      return LmsColors.success;
    case StudentStatus.blocked:
      return _blockedColor;
    case StudentStatus.unverified:
      return _unverifiedColor;
    case null:
      return LmsColors.textGrey;
  }
}

IconData statusIcon(AdminStudentModel student) {
  switch (student.statusValue) {
    case StudentStatus.verified:
      return Icons.check_circle_rounded;
    case StudentStatus.blocked:
      return Icons.block_rounded;
    case StudentStatus.unverified:
      return Icons.mark_email_unread_outlined;
    case null:
      return Icons.help_outline_rounded;
  }
}

/// Active · Blocked · Unverified, in one place so a row and a header can never
/// disagree about what a status looks like.
class StudentStatusChip extends StatelessWidget {
  final AdminStudentModel student;

  /// Row-sized. The header wants the larger form.
  final bool dense;

  const StudentStatusChip({
    super.key,
    required this.student,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(student);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(student), size: dense ? 12 : 14, color: color),
          SizedBox(width: dense ? 6 : 7),
          Text(
            student.statusLabel,
            style: TextStyle(
              fontSize: dense ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: isError ? _blockedColor : null,
  ));
}

/// "1 device" / "3 devices" / the honest wording for none.
String _devices(int count) =>
    count == 1 ? '1 device' : '$count devices';

/// Blocks or unblocks, after a confirm that names the student.
///
/// Returns the student as the SERVER reports them, or null if nothing changed.
/// The caller must adopt that object rather than flipping a local flag - the
/// response is the only thing that knows the change actually landed.
Future<AdminStudentModel?> confirmSetBlocked(
  BuildContext context,
  AdminStudentModel student, {
  required bool blocked,
}) async {
  final name = student.name?.trim().isNotEmpty == true
      ? student.name!.trim()
      : student.email;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(blocked ? 'Block $name?' : 'Unblock $name?'),
      content: Text(
        blocked
            ? 'They are signed out of every device immediately and cannot '
                'sign in again until you unblock them.\n\n'
                'If they are only locked out after losing a phone, close this '
                'and use "Sign out all devices" instead.'
            : 'They can sign in again straight away.\n\n'
                'Their old session is not restored — blocking invalidated it, '
                'so they will log in fresh.',
        style: const TextStyle(fontSize: 13.5, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: blocked ? _blockedColor : LmsColors.primary,
          ),
          child: Text(blocked ? 'Block' : 'Unblock'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return null;

  try {
    final result = await AdminStudentService().setStatus(
      studentId: student.id,
      // Never "inactive" or "disabled" - the API takes exactly these three.
      status: blocked ? StudentStatus.blocked : StudentStatus.verified,
    );
    if (!context.mounted) return result.student;

    _toast(
      context,
      blocked
          // The count is how an admin sees the block took effect rather than
          // trusting that it did. Zero is normal, not a failure.
          ? (result.sessionsRevoked == 0
              ? 'Blocked. They were not signed in anywhere.'
              : 'Blocked. Signed out of ${_devices(result.sessionsRevoked)}.')
          : 'Unblocked. $name can sign in again.',
    );
    return result.student;
  } catch (e) {
    if (context.mounted) {
      _toast(context, '$e'.replaceFirst('Exception: ', ''), isError: true);
    }
    return null;
  }
}

/// Signs the student out of every device without touching their status.
///
/// Light confirm on purpose: nothing is lost and they can sign back in, so a
/// type-the-name step here would teach an admin to click through the one that
/// matters.
Future<bool> confirmSignOutEverywhere(
  BuildContext context,
  AdminStudentModel student,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Sign out all devices?'),
      content: const Text(
        'This clears their sessions so they can sign in on a new device. '
        'Their account is not blocked and they can sign back in immediately.',
        style: TextStyle(fontSize: 13.5, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  try {
    final result = await AdminStudentService().revokeSessions(student.id);
    if (context.mounted) {
      _toast(
        context,
        result.revoked == 0
            ? 'They were not signed in anywhere.'
            // The server's own sentence, which already says they can sign in
            // again straight away.
            : result.message,
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      _toast(context, '$e'.replaceFirst('Exception: ', ''), isError: true);
    }
    return false;
  }
}
