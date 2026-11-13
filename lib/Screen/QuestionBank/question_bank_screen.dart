import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../Test/test_list_screen.dart';
import 'course_quiz_screen.dart';
import 'question_import_tab.dart';

/// The Question Bank section: everything a set of questions becomes, and the
/// ways questions get in.
///
/// Three tabs rather than one screen because they work at different scopes.
/// A quiz and a mock test belong to a course and an exam; a bank question
/// belongs to a subject and a topic and knows nothing about either.
///
/// Mock tests are the Tests screen itself, not a copy of it: the same course
/// and exam pickers, the same wizard behind them - details and instructions
/// PDF, then the questions CSV, then the review before anything publishes.
/// Two screens that drift apart would be two different answers to "what did
/// I upload".
///
/// **No TabBarView here, deliberately.** The dashboard puts this inside a
/// scroll view, so the height is unbounded, and a TabBarView in unbounded
/// height lays out nothing at all - which is exactly what it did. One child
/// at a time, sized by its own content, is what survives that.
class QuestionBankScreen extends StatefulWidget {
  final int? initialCourseId;
  final int? initialCourseTypeId;

  /// The three panels, injectable so the layout can be tested without the
  /// network behind the real ones.
  final Widget? quizzes;
  final Widget? mockTests;
  final Widget? import;

  const QuestionBankScreen({
    super.key,
    this.initialCourseId,
    this.initialCourseTypeId,
    this.quizzes,
    this.mockTests,
    this.import,
  });

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  int _tab = 0;

  static const _labels = ['Quizzes', 'Mock tests', 'Import from CSV'];
  static const _icons = [
    Icons.quiz_outlined,
    Icons.fact_check_outlined,
    Icons.upload_file_rounded,
  ];

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
        1 => widget.mockTests ?? const TestListScreen(),
        _ => widget.import ?? const QuestionImportTab(),
      };
}
