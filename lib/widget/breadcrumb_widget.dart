import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';

/// Shows where you are in one of the two content trees:
///
///   Course > Exam Type > Syllabus > Lesson
///   Question Bank > Subject > Topic
///
/// The model names are easy to mix up (CourseType vs Chapter vs Subject),
/// so every nested screen states its own level rather than leaving the admin
/// to infer it from the page title.
class LmsBreadcrumb extends StatelessWidget {
  /// Root first, current level last. Empty segments are dropped, so callers
  /// can pass a nullable name straight through.
  final List<String?> path;

  const LmsBreadcrumb({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final parts = path
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim())
        .toList();

    if (parts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right_rounded, size: 15, color: LmsColors.textGrey),
            ),
          Text(
            parts[i],
            style: TextStyle(
              fontSize: 12.5,
              // The level you're actually on is the one that matters.
              fontWeight: i == parts.length - 1 ? FontWeight.w800 : FontWeight.w600,
              color: i == parts.length - 1 ? LmsColors.textDark : LmsColors.textGrey,
            ),
          ),
        ],
      ],
    );
  }
}
