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
        ChangeNotifierProvider(create: (_) => LessonDetailsProvider())
      ],
      child: MaterialApp(
         debugShowCheckedModeBanner: false,
        home: AdminLoginScreen()
      ),
    );
  }
}
