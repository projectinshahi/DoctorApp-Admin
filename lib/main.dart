import 'package:admin_drapp/provider/admin_auth_provider.dart';
import 'package:admin_drapp/provider/admin_plan_provider.dart';
import 'package:admin_drapp/provider/admin_student_provider.dart';
import 'package:admin_drapp/provider/chapter_provider.dart';
import 'package:admin_drapp/provider/course_details_provider.dart';
import 'package:admin_drapp/provider/course_get_provider.dart';
import 'package:admin_drapp/provider/course_provider.dart';
import 'package:admin_drapp/provider/course_type_provider.dart';
import 'package:admin_drapp/provider/lesson_details_provider.dart';
import 'package:admin_drapp/provider/lesson_upload_provider.dart';
import 'package:admin_drapp/provider/question_bank_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Screen/Login/Login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminAuthProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => CourseListGetProvider()),
        ChangeNotifierProvider(create: (_) => CourseDetailsProvider()),
        ChangeNotifierProvider(create: (_) => CourseTypeUpdateProvider()),
        ChangeNotifierProvider(create: (_) => ChapterUpdateProvider()),
        ChangeNotifierProvider(create: (_) => AdminStudentProvider()),
        ChangeNotifierProvider(create: (_) => AdminPlanProvider()),
        ChangeNotifierProvider(create: (_) => LessonUpdateProvider()),
        ChangeNotifierProvider(create: (_) => LessonDetailsProvider()),
        // Question bank. The add/edit sheet builds its own
        // QuestionUpdateProvider / SubjectTopicProvider, the same way the
        // lesson sheet does, so these two are only the list screen's state.
        ChangeNotifierProvider(create: (_) => QuestionListProvider()),
        ChangeNotifierProvider(create: (_) => SubjectTopicProvider()),
      ],
      child: MaterialApp(
         debugShowCheckedModeBanner: false,
        home: AdminLoginScreen()
      ),
    );
  }
}
