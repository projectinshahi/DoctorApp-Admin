import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Screen/Dashbord/course_details_screen.dart';
import '../core/theam/theam_dart.dart';
import '../models/course_details_model.dart';

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final int chapterNumber;
  final VoidCallback onAddLesson;
  final void Function(Lesson lesson) onEditLesson;
  final void Function(Lesson lesson) onDeleteLesson;

  const ChapterCard({
    required this.chapter,
    required this.chapterNumber,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onDeleteLesson,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LmsColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: ChapterTile(
        chapter: chapter,
        chapterNumber: chapterNumber,
        onAddLesson: onAddLesson,
        onEditLesson: onEditLesson,
        onDeleteLesson: onDeleteLesson,
      ),
    );
  }
}


