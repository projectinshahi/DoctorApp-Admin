//
// // ── REDESIGNED: Subject card - cleaner header, numbered chapter list ──
// import 'package:admin_drapp/widget/phill_chip_widget.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../core/theam/theam_dart.dart';
// import '../models/course_details_model.dart';
// import '../models/lesson_model.dart';
// import 'chappter_tile_widget.dart';
// import 'empty_row.dart';
//
// class CourseTypeCard extends StatelessWidget {
//   final CourseType courseType;
//   final Color statusColor;
//   final VoidCallback onEdit;
//   final VoidCallback onDelete;
//   final VoidCallback onAddChapter;
//   final void Function(Chapter chapter) onEditChapter;
//   final void Function(Chapter chapter) onDeleteChapter;
//   final void Function(Chapter chapter) onAddLesson;
//   final void Function(Chapter chapter, Lesson lesson) onEditLesson;
//   final void Function(Chapter chapter, Lesson lesson) onDeleteLesson;
//
//   const CourseTypeCard({
//     required this.courseType,
//     required this.statusColor,
//     required this.onEdit,
//     required this.onDelete,
//     required this.onAddChapter,
//     required this.onEditChapter,
//     required this.onDeleteChapter,
//     required this.onAddLesson,
//     required this.onEditLesson,
//     required this.onDeleteLesson,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final lessonCount = courseType.chapters.fold<int>(0, (sum, ch) => sum + ch.lessons.length);
//     final isPremium = courseType.accessType.toLowerCase() == 'premium';
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       decoration: BoxDecoration(
//         color: LmsColors.surface,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: LmsColors.border),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 6))],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── Header row: subject name + status + overflow menu ──
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(color: LmsColors.primarySoft, borderRadius: BorderRadius.circular(12)),
//                   child: const Icon(Icons.assignment_outlined, color: LmsColors.primary, size: 20),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Flexible(
//                             child: Text(
//                               courseType.title,
//                               style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: LmsColors.textDark),
//                             ),
//                           ),
//                           if (isPremium) ...[
//                             const SizedBox(width: 6),
//                             const Icon(Icons.workspace_premium_rounded, size: 14, color: LmsColors.primary),
//                           ],
//                         ],
//                       ),
//                       const SizedBox(height: 3),
//                       Text(
//                         '${courseType.chapters.length} chapters · $lessonCount lessons',
//                         style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
//                       ),
//                     ],
//                   ),
//                 ),
//                 PillChip(icon: Icons.circle, iconSize: 8, label: courseType.status, color: statusColor),
//                 PopupMenuButton<String>(
//                   icon: const Icon(Icons.more_vert_rounded, color: LmsColors.textGrey, size: 20),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   onSelected: (value) {
//                     if (value == 'edit') onEdit();
//                     if (value == 'delete') onDelete();
//                   },
//                   itemBuilder: (ctx) => const [
//                     PopupMenuItem(value: 'edit', child: Text('Edit subject')),
//                     PopupMenuItem(value: 'delete', child: Text('Delete subject')),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//
//           if (courseType.description != null && courseType.description!.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
//               child: Text(courseType.description!, style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey, height: 1.4)),
//             ),
//
//           const Divider(height: 1, color: LmsColors.border),
//
//           // ── Numbered chapter list ──
//           if (courseType.chapters.isEmpty)
//             const EmptyRow(text: 'No syllabus added yet.')
//           else
//             ...List.generate(courseType.chapters.length, (index) {
//               final chapter = courseType.chapters[index];
//               return ChapterTile(
//                 chapter: chapter,
//                 chapterNumber: index + 1,
//                 onEdit: () => onEditChapter(chapter),
//                 onDelete: () => onDeleteChapter(chapter),
//                 onAddLesson: () => onAddLesson(chapter),
//                 onEditLesson: (lesson) => onEditLesson(chapter, lesson),
//                 onDeleteLesson: (lesson) => onDeleteLesson(chapter, lesson),
//               );
//             }),
//
//           // ── Full-width "add syllabus" button, not a buried icon ──
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
//             child: SizedBox(
//               width: double.infinity,
//               child: OutlinedButton.icon(
//                 onPressed: onAddChapter,
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: LmsColors.primary,
//                   side: const BorderSide(color: LmsColors.primary),
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 ),
//                 icon: const Icon(Icons.add_rounded, size: 18),
//                 label: const Text('Add Chapter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }