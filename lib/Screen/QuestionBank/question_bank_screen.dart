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
      length: 3,
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
                    icon: Icon(Icons.fact_check_outlined, size: 17),
                    iconMargin: EdgeInsets.zero,
                    text: 'Mock tests'),
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
                const TestListScreen(),
                const QuestionImportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
