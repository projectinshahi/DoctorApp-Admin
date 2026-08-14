import 'package:flutter/material.dart';

import '../../services/lesson_services.dart';

/// Central place for how each lesson type looks across the app -
/// icon, color, display label, and the hint text shown in the content
/// field. Add a new lesson type's visuals here only, nowhere else.
class LessonTypeUI {
  final IconData icon;
  final Color color;
  final String label;        // shown in UI (chip, picker card)
  final String contentLabel; // field label above the content input
  final String contentHint;  // placeholder text in the content input

  const LessonTypeUI({
    required this.icon,
    required this.color,
    required this.label,
    required this.contentLabel,
    required this.contentHint,
  });

  static LessonTypeUI of(LessonType type) {
    switch (type) {
      case LessonType.video:
        return const LessonTypeUI(
          icon: Icons.play_circle_rounded,
          color: Color(0xFF4C6FFF),
          label: 'Video',
          contentLabel: 'Video URL',
          contentHint: 'https://...',
        );
      case LessonType.quiz:
        return const LessonTypeUI(
          icon: Icons.quiz_rounded,
          color: Color(0xFF9C5FFF),
          label: 'Quiz',
          contentLabel: 'Quiz Reference',
          contentHint: 'Question bank / quiz ID',
        );
      case LessonType.text:
        return const LessonTypeUI(
          icon: Icons.picture_as_pdf_rounded,
          color: Color(0xFFFF9F43),
          label: 'Notes / PDF',
          contentLabel: 'Notes or PDF link',
          contentHint: 'Paste notes text, or a PDF URL',
        );
    }
  }
}