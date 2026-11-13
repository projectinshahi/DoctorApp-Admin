import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import 'course_quiz_screen.dart';
import 'quiz_import_tab.dart';

/// The Question Bank section: everything a set of questions becomes, and the
/// ways questions get in.
///
/// Two tabs: the quizzes that exist, and the way a new one is made - a CSV
/// of questions, reviewed before anything is written, the way a mock test is
/// uploaded. Timed papers stay in Tests; a quiz has no clock.
///
/// **No TabBarView here, deliberately.** The dashboard puts this inside a
/// scroll view, so the height is unbounded, and a TabBarView in unbounded
/// height lays out nothing at all - which is exactly what it did. One child
/// at a time, sized by its own content, is what survives that.
class QuestionBankScreen extends StatefulWidget {
  final int? initialCourseId;
  final int? initialCourseTypeId;

  /// Both panels, injectable so the layout can be tested without the network
  /// behind the real ones.
  final Widget? quizzes;
  final Widget? import;

  const QuestionBankScreen({
    super.key,
    this.initialCourseId,
    this.initialCourseTypeId,
    this.quizzes,
    this.import,
  });

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  int _tab = 0;

  static const _labels = ['Quizzes', 'Add quiz from CSV'];
  static const _icons = [Icons.quiz_outlined, Icons.upload_file_rounded];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: LmsColors.border)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _labels.length; i++) _tabButton(i),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(),
      ],
    );
  }

  Widget _tabButton(int index) {
    final selected = index == _tab;
    final colour = selected ? LmsColors.primary : LmsColors.textGrey;

    return InkWell(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? LmsColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[index], size: 16, color: colour),
            const SizedBox(width: 7),
            Text(
              _labels[index],
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel() => switch (_tab) {
        0 =>
          widget.quizzes ??
              CourseQuizScreen(
                initialCourseId: widget.initialCourseId,
                initialCourseTypeId: widget.initialCourseTypeId,
              ),
        _ => widget.import ?? const QuizImportTab(),
      };
}
