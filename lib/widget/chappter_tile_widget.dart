//
//
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../core/theam/theam_dart.dart';
// import '../models/course_details_model.dart';
// import '../models/lesson_model.dart' hide Lesson;
// import 'empty_row.dart';
//
// class ChapterTile extends StatelessWidget {
//   final Chapter chapter;
//   final int chapterNumber;
//   final VoidCallback? onEdit;
//   final VoidCallback? onDelete;
//   final VoidCallback? onAddLesson;
//   final void Function(Lesson lesson)? onEditLesson;
//   final void Function(Lesson lesson)? onDeleteLesson;
//
//   const ChapterTile({
//     required this.chapter,
//     required this.chapterNumber,
//     this.onEdit,
//     this.onDelete,
//     this.onAddLesson,
//     this.onEditLesson,
//     this.onDeleteLesson,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final bool showChapterActions = onEdit != null || onDelete != null;
//     final bool showLessonActions = onEditLesson != null || onDeleteLesson != null;
//
//     return Theme(
//       data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//       child: ExpansionTile(
//         tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
//         childrenPadding: const EdgeInsets.only(bottom: 8),
//         // Numbered badge instead of a generic folder icon.
//         leading: Container(
//           width: 30,
//           height: 30,
//           alignment: Alignment.center,
//           decoration: BoxDecoration(color: LmsColors.textDark.withOpacity(0.06), borderRadius: BorderRadius.circular(9)),
//           child: Text(
//             '$chapterNumber',
//             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: LmsColors.textDark),
//           ),
//         ),
//         title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
//         subtitle: Text('${chapter.lessons.length} lessons', style: const TextStyle(fontSize: 12, color: LmsColors.textGrey)),
//         trailing: showChapterActions
//             ? PopupMenuButton<String>(
//           icon: const Icon(Icons.more_vert_rounded, size: 18, color: LmsColors.textGrey),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           onSelected: (value) {
//             if (value == 'edit') onEdit?.call();
//             if (value == 'delete') onDelete?.call();
//           },
//           itemBuilder: (ctx) => const [
//             PopupMenuItem(value: 'edit', child: Text('Rename chapter')),
//             PopupMenuItem(value: 'delete', child: Text('Delete chapter')),
//           ],
//         )
//             : const Icon(Icons.expand_more_rounded, color: LmsColors.textGrey),
//         children: [
//           if (chapter.lessons.isEmpty)
//             const EmptyRow(text: 'No lessons added yet.')
//           else
//             ...List.generate(chapter.lessons.length, (index) {
//               final lesson = chapter.lessons[index];
//               final ui = LessonTypeUI.of(LessonTypeX.fromApiValue(lesson.type));
//
//               return Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: LmsColors.bg,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border(left: BorderSide(color: ui.color, width: 3)),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 26,
//                       height: 26,
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(color: ui.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
//                       child: Text(
//                         _letterLabel(index),
//                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ui.color),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(lesson.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
//                           const SizedBox(height: 2),
//
//
//                           Row(
//                             children: [
//                               if (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) ...[
//                                 const Icon(Icons.play_circle_outline_rounded, size: 12, color: Color(0xFF4C6FFF)),
//                                 const SizedBox(width: 3),
//                                 const Text('Video', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4C6FFF))),
//                                 const SizedBox(width: 8),
//                               ],
//                               if (lesson.noteUrl != null && lesson.noteUrl!.isNotEmpty) ...[
//                                 const Icon(Icons.picture_as_pdf_outlined, size: 12, color: Color(0xFFFF9F43)),
//                                 const SizedBox(width: 3),
//                                 const Text('Notes', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFFF9F43))),
//                               ],
//                             ],
//                           ),
//                           // ),
//                         ],
//                       ),
//                     ),
//                     if (showLessonActions) ...[
//                       IconButton(
//                         icon: const Icon(Icons.edit_rounded, size: 15, color: LmsColors.textDark),
//                         tooltip: 'Edit lesson',
//                         onPressed: onEditLesson != null ? () => onEditLesson!(lesson) : null,
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.delete_outline_rounded, size: 15, color: LmsColors.error),
//                         tooltip: 'Delete lesson',
//                         onPressed: onDeleteLesson != null ? () => onDeleteLesson!(lesson) : null,
//                       ),
//                     ],
//                   ],
//                 ),
//               );
//             }),
//           if (onAddLesson != null)
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
//               child: SizedBox(
//                 width: double.infinity,
//                 child: TextButton.icon(
//                   onPressed: onAddLesson,
//                   style: TextButton.styleFrom(
//                     foregroundColor: LmsColors.primary,
//                     backgroundColor: LmsColors.primarySoft,
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   icon: const Icon(Icons.add_rounded, size: 16),
//                   label: const Text('Add Lesson', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Converts 0,1,2... into A,B,C... (then AA,AB... past 25) ──────────────
// String _letterLabel(int index) {
//   String label = '';
//   int n = index;
//   do {
//     label = String.fromCharCode(65 + (n % 26)) + label;
//     n = (n ~/ 26) - 1;
//   } while (n >= 0);
//   return label;
// }
