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
import 'core/theam/theam_dart.dart';

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
        title: "dr.skm's academy",
        debugShowCheckedModeBanner: false,
        // Material 3 tints every dialog and sheet with
        // colorScheme.surfaceContainerHigh - a lilac-grey, not white. The panel
        // is white everywhere else, so it is pinned here once rather than
        // passing backgroundColor to each of the twenty-odd dialogs.
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: LmsColors.bg,
          dialogTheme: const DialogThemeData(
            backgroundColor: LmsColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: LmsColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          popupMenuTheme: const PopupMenuThemeData(
            color: LmsColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
        ),
        home: AdminLoginScreen(),
      ),
    );
  }
}
