import 'package:flutter/material.dart';

import '../../../core/theam/theam_dart.dart';

/// Small presentational pieces shared by the full-tree and fallback views of
/// the course details screen.

class PillChip extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color color;

  const PillChip({
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onAdd;
  const SectionTitle(this.title, {required this.count, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LmsColors.textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: LmsColors.textDark.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: LmsColors.textDark,
            ),
          ),
        ),
        const Spacer(),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              foregroundColor: LmsColors.primary,
              backgroundColor: LmsColors.primarySoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add Exam Type',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

class EmptyRow extends StatelessWidget {
  final String text;
  const EmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: const TextStyle(color: LmsColors.textGrey, fontSize: 13)),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  const ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: LmsColors.error, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LmsColors.error)),
          ],
        ),
      ),
    );
  }
}

/// Shown when GET /api/courses/:id fails but the narrower routes still work.
///
/// The full tree is rebuilt one level at a time from three endpoints that
/// don't touch the broken one:
///   /api/courses/:id/course-types      (public)  -> exam types
///   /api/course-types/:id/chapters     (admin)   -> syllabus
///   /api/chapters/:id/lessons          (admin)   -> lessons
///
/// Each level loads only when its parent is expanded, so opening a course
/// costs one request, not one per chapter.
class LmsBadge extends StatelessWidget {
  final String text;
  final Color color;

  const LmsBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
