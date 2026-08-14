// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../../core/theam/theam_dart.dart';
// import '../../provider/lessoedit_provider.dart';
// import '../../provider/lesson_upload_provider.dart';
//
// /// Shows a confirmation dialog, then deletes the lesson via
// /// [LessonUpdateProvider] if confirmed. Returns true if the lesson was
// /// deleted, false/null otherwise — use the return value to remove the row
// /// from your list or trigger a refresh.
// Future<bool> confirmAndDeleteLesson(
//     BuildContext context, {
//       required int chapterId,
//       required int lessonId,
//       required String lessonTitle,
//     }) async {
//   final confirmed = await showDialog<bool>(
//     context: context,
//     builder: (ctx) => AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       title: const Text('Delete Lesson', style: TextStyle(fontWeight: FontWeight.w800)),
//       content: Text(
//         'Are you sure you want to delete "$lessonTitle"? '
//             'This will permanently remove the lesson along with its video and notes. '
//             'This action cannot be undone.',
//         style: const TextStyle(fontSize: 13.5),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(ctx, false),
//           child: const Text('Cancel'),
//         ),
//         TextButton(
//           onPressed: () => Navigator.pop(ctx, true),
//           style: TextButton.styleFrom(foregroundColor: LmsColors.error),
//           child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
//         ),
//       ],
//     ),
//   );
//
//   if (confirmed != true) return false;
//
//   // A short-lived provider just for this delete call — doesn't need to be
//   // the same instance used by the edit sheet.
//   final provider = LessonUpdateProvider();
//   final success = await provider.deleteLesson(chapterId: chapterId, lessonId: lessonId);
//
//   if (!context.mounted) return success;
//
//   if (success) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Lesson deleted successfully')),
//     );
//   } else {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(provider.errorMessage ?? 'Failed to delete lesson')),
//     );
//   }
//
//   return success;
// }
//
// /// Edit + Delete icon buttons for a lesson row in your listing UI.
// class LessonRowActions extends StatefulWidget {
//   final int chapterId;
//   final int lessonId;
//   final String title;
//   final LessonType type;
//   final String? videoUrl;
//   final String? videoPublicId;
//   final String? noteUrl;
//   final String? notePublicId;
//   final String? noteFileType;
//   final String? content;
//   final bool isFreePreview;
//   final LessonAccessType accessType;
//   final int displayOrder;
//
//   /// Called after a successful edit or delete so the parent list can refresh.
//   final VoidCallback onChanged;
//
//   const LessonRowActions({
//     super.key,
//     required this.chapterId,
//     required this.lessonId,
//     required this.title,
//     required this.type,
//     this.videoUrl,
//     this.videoPublicId,
//     this.noteUrl,
//     this.notePublicId,
//     this.noteFileType,
//     this.content,
//     required this.isFreePreview,
//     required this.accessType,
//     required this.displayOrder,
//     required this.onChanged,
//   });
//
//   @override
//   State<LessonRowActions> createState() => _LessonRowActionsState();
// }
//
// class _LessonRowActionsState extends State<LessonRowActions> {
//   bool _isDeleting = false;
//
//   Future<void> _handleEdit() async {
//     final result = await showAddEditLessonSheet(
//       context,
//       chapterId: widget.chapterId,
//       lessonId: widget.lessonId,
//       initialTitle: widget.title,
//       initialType: widget.type,
//       initialVideoUrl: widget.videoUrl,
//       initialVideoPublicId: widget.videoPublicId,
//       initialNoteUrl: widget.noteUrl,
//       initialNotePublicId: widget.notePublicId,
//       initialNoteFileType: widget.noteFileType,
//       initialContent: widget.content,
//       initialIsFreePreview: widget.isFreePreview,
//       initialAccessType: widget.accessType,
//       initialDisplayOrder: widget.displayOrder,
//     );
//     if (result == true) widget.onChanged();
//   }
//
//   Future<void> _handleDelete() async {
//     setState(() => _isDeleting = true);
//     final deleted = await confirmAndDeleteLesson(
//       context,
//       chapterId: widget.chapterId,
//       lessonId: widget.lessonId,
//       lessonTitle: widget.title,
//     );
//     if (!mounted) return;
//     setState(() => _isDeleting = false);
//     if (deleted) widget.onChanged();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: const Icon(Icons.edit_outlined, size: 19, color: LmsColors.textGrey),
//           onPressed: _isDeleting ? null : _handleEdit,
//           tooltip: 'Edit lesson',
//         ),
//         _isDeleting
//             ? const SizedBox(
//           width: 40,
//           height: 40,
//           child: Padding(
//             padding: EdgeInsets.all(11),
//             child: CircularProgressIndicator(strokeWidth: 2, color: LmsColors.error),
//           ),
//         )
//             : IconButton(
//           icon: const Icon(Icons.delete_outline_rounded, size: 19, color: LmsColors.error),
//           onPressed: _handleDelete,
//           tooltip: 'Delete lesson',
//         ),
//       ],
//     );
//   }
// }