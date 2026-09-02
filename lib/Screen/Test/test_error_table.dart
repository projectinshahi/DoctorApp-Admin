import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';

/// Everything a rejected CSV upload said, in one table.
///
/// Deliberately not truncated and not collapsed: the importer reports every
/// bad line at once precisely so a 200-row file can be fixed in one pass.
/// Showing "and 12 more" would put the admin back to one error per upload.
///
/// Errors and warnings are separated because they mean different things -
/// warnings did not block the import and must never block the next step.
class TestErrorTable extends StatelessWidget {
  final List<TestUploadIssue> issues;

  /// Shown above the blocking table. Nothing is saved on a blocking error, and
  /// an admin who assumes a partial import will upload a "fixed" file that
  /// duplicates nothing and imports nothing.
  final bool nothingWasSaved;

  const TestErrorTable({
    super.key,
    required this.issues,
    this.nothingWasSaved = true,
  });

  /// The server tells an admin to "upload the images first", which this panel
  /// has no button for. Left alone that sends them looking for one, so the two
  /// routes that do exist are named underneath it.
  static bool _isImageField(TestUploadIssue i) =>
      i.field.toLowerCase().contains('image');

  @override
  Widget build(BuildContext context) {
    final errors = issues.where((i) => !i.isWarning).toList();
    final warnings = issues.where((i) => i.isWarning).toList();
    final imageHint = errors.any(_isImageField)
        ? '\n\nA file name only resolves against images uploaded to this test. '
            'Either paste the full https://... address instead, or tick '
            '"Import now, add images later" to bring these rows in without '
            'their pictures.'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errors.isNotEmpty) ...[
          _Banner(
            color: LmsColors.error,
            icon: Icons.error_outline_rounded,
            title: '${errors.length} line${errors.length == 1 ? '' : 's'} '
                'could not be imported',
            body: nothingWasSaved
                ? 'Nothing was saved — fix these lines and re-upload the file.'
                    '$imageHint'
                : (imageHint.isEmpty ? null : imageHint.trimLeft()),
          ),
          const SizedBox(height: 12),
          _Table(issues: errors, color: LmsColors.error),
        ],

        if (warnings.isNotEmpty) ...[
          if (errors.isNotEmpty) const SizedBox(height: 20),
          const _Banner(
            color: Color(0xFFB8860B),
            icon: Icons.warning_amber_rounded,
            title: 'Warnings',
            body: 'These did not block the import. You can continue.',
          ),
          const SizedBox(height: 12),
          _Table(issues: warnings, color: const Color(0xFFB8860B)),
        ],
      ],
    );
  }
}

class _Table extends StatelessWidget {
  final List<TestUploadIssue> issues;
  final Color color;

  const _Table({required this.issues, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: color.withValues(alpha: 0.07),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: const [
                SizedBox(
                  width: 84,
                  child: Text('LINE', style: _headStyle),
                ),
                SizedBox(
                  width: 130,
                  child: Text('FIELD', style: _headStyle),
                ),
                Expanded(child: Text('MESSAGE', style: _headStyle)),
              ],
            ),
          ),
          // Capped in height, not in row count: every issue stays reachable by
          // scrolling, which truncation would not allow.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: Scrollbar(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: issues.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: LmsColors.border),
                itemBuilder: (_, index) {
                  final issue = issues[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 84,
                          // "Line 147" is the number the admin will search for
                          // in their spreadsheet - not "Row" and not "#".
                          child: Text(
                            'Line ${issue.row}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            issue.field,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              color: LmsColors.textDark,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            issue.message,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: LmsColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _headStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.8,
  color: LmsColors.textGrey,
);

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? body;

  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    this.body,
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    body!,
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
