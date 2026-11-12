import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import 'course_quiz_screen.dart';
import 'question_import_tab.dart';

/// The Question Bank section: the quizzes built from the bank, and the way
/// questions get into it.
///
/// Two tabs rather than one screen because the two work at different scopes.
/// A quiz belongs to a course and an exam; a bank question belongs to a
/// subject and a topic and knows nothing about either.
class QuestionBankScreen extends StatelessWidget {
  final int? initialCourseId;
  final int? initialCourseTypeId;

  const QuestionBankScreen({
    super.key,
    this.initialCourseId,
    this.initialCourseTypeId,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: LmsColors.border)),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: LmsColors.primary,
              unselectedLabelColor: LmsColors.textGrey,
              indicatorColor: LmsColors.primary,
              labelStyle:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              unselectedLabelStyle:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                    height: 46,
                    icon: Icon(Icons.quiz_outlined, size: 17),
                    iconMargin: EdgeInsets.zero,
                    text: 'Quizzes'),
                Tab(
                    height: 46,
                    icon: Icon(Icons.upload_file_rounded, size: 17),
                    iconMargin: EdgeInsets.zero,
                    text: 'Import from CSV'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                CourseQuizScreen(
                  initialCourseId: initialCourseId,
                  initialCourseTypeId: initialCourseTypeId,
                ),
                const QuestionImportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
