// import 'package:flutter/foundation.dart';
//
// import '../models/lesson_model.dart'; // adjust path to wherever Lesson lives
// import '../services/lesson_services.dart';
//
// class LessonUpdateProvider extends ChangeNotifier {
//   final LessonService _service;
//
//   LessonUpdateProvider({LessonService? service}) : _service = service ?? LessonService();
//
//   bool isUpdating = false;
//   bool isDeleting = false;
//   bool isLoadingList = false;
//   String? errorMessage;
//
//   List<Lesson> lessons = [];
//
//   Future<bool> createLesson({
//     required int chapterId,
//     required String title,
//     String? description,
//     required LessonType type,
//     String? videoUrl,
//     String? videoPublicId,
//     String? thumbnailUrl,
//     String? thumbnailPublicId,
//     String? noteUrl,
//     String? notePublicId,
//     String? noteFileType,
//     String? content,
//     int? displayOrder,
//     bool? isFreePreview,
//     LessonAccessType? accessType,
//   }) async {
//     isUpdating = true;
//     errorMessage = null;
//     notifyListeners();
//
//     final result = await _service.createLesson(
//       chapterId: chapterId,
//       title: title,
//       description: description,
//       type: type,
//       videoUrl: videoUrl,
//       videoPublicId: videoPublicId,
//       thumbnailUrl: thumbnailUrl,
//       thumbnailPublicId: thumbnailPublicId,
//       noteUrl: noteUrl,
//       notePublicId: notePublicId,
//       noteFileType: noteFileType,
//       content: content,
//       displayOrder: displayOrder,
//       isFreePreview: isFreePreview,
//       accessType: accessType,
//     );
//
//     isUpdating = false;
//     if (!result.isSuccess) errorMessage = result.errorMessage;
//     notifyListeners();
//     return result.isSuccess;
//   }
//
//   /// [removeDescription] / [removeVideo] / [removeThumbnail] / [removeNote]:
//   /// pass true when the user explicitly cleared that field in the edit
//   /// sheet, so the backend actually clears it (and cleans up the old
//   /// Cloudinary file for video/thumbnail/note) instead of silently leaving
//   /// it untouched.
//   Future<bool> updateLesson({
//     required int chapterId,
//     required int lessonId,
//     String? title,
//     String? description,
//     bool removeDescription = false,
//     LessonType? type,
//     String? videoUrl,
//     String? videoPublicId,
//     bool removeVideo = false,
//     String? thumbnailUrl,
//     String? thumbnailPublicId,
//     bool removeThumbnail = false,
//     String? noteUrl,
//     String? notePublicId,
//     String? noteFileType,
//     bool removeNote = false,
//     String? content,
//     int? displayOrder,
//     bool? isFreePreview,
//     LessonAccessType? accessType,
//   }) async {
//     isUpdating = true;
//     errorMessage = null;
//     notifyListeners();
//
//     final result = await _service.updateLesson(
//       chapterId: chapterId,
//       lessonId: lessonId,
//       title: title,
//       description: description,
//       removeDescription: removeDescription,
//       type: type,
//       videoUrl: videoUrl,
//       videoPublicId: videoPublicId,
//       removeVideo: removeVideo,
//       thumbnailUrl: thumbnailUrl,
//       thumbnailPublicId: thumbnailPublicId,
//       removeThumbnail: removeThumbnail,
//       noteUrl: noteUrl,
//       notePublicId: notePublicId,
//       noteFileType: noteFileType,
//       removeNote: removeNote,
//       content: content,
//       displayOrder: displayOrder,
//       isFreePreview: isFreePreview,
//       accessType: accessType,
//     );
//
//     isUpdating = false;
//     if (!result.isSuccess) errorMessage = result.errorMessage;
//     notifyListeners();
//     return result.isSuccess;
//   }
//
//   Future<bool> deleteLesson({required int chapterId, required int lessonId}) async {
//     isDeleting = true;
//     errorMessage = null;
//     notifyListeners();
//
//     final result = await _service.deleteLesson(chapterId: chapterId, lessonId: lessonId);
//
//     isDeleting = false;
//     if (!result.isSuccess) errorMessage = result.errorMessage;
//     notifyListeners();
//     return result.isSuccess;
//   }
//
//   /// Fetches all lessons for [chapterId] and stores them in [lessons].
//   /// Call this to populate your lesson listing UI.
//   Future<bool> fetchLessonsByChapter({required int chapterId}) async {
//     isLoadingList = true;
//     errorMessage = null;
//     notifyListeners();
//
//     final result = await _service.getLessonsByChapter(chapterId: chapterId);
//
//     isLoadingList = false;
//     if (result.isSuccess) {
//       lessons = (result.data ?? []).map(Lesson.fromJson).toList();
//     } else {
//       errorMessage = result.errorMessage;
//     }
//     notifyListeners();
//     return result.isSuccess;
//   }
//
//   void clearError() {
//     errorMessage = null;
//     notifyListeners();
//   }
// }



import 'package:flutter/foundation.dart';

import '../models/lesson_model.dart';
import '../services/lesson_services.dart';
import '../services/lesson_upload_service.dart';

class LessonUpdateProvider extends ChangeNotifier {
  final LessonService _service;
  final LessonUploadService _uploadService;

  LessonUpdateProvider({
    LessonService? service,
    LessonUploadService? uploadService,
  })  : _service = service ?? LessonService(),
        _uploadService = uploadService ?? LessonUploadService();

  bool isUpdating = false;
  bool isDeleting = false;
  bool isLoadingList = false;

  String? errorMessage;

  List<Lesson> lessons = [];

  // ─────────────────────────────────────────────────────────────
  // CREATE LESSON
  // ─────────────────────────────────────────────────────────────

  Future<bool> createLesson({
    required int chapterId,
    required String title,
    String? description,
    required LessonType type,
    String? videoUrl,
    String? videoPublicId,
    String? thumbnailUrl,
    String? thumbnailPublicId,
    String? noteUrl,
    String? notePublicId,
    String? noteFileType,
    String? content,
    int? displayOrder,
    bool? isFreePreview,
    LessonAccessType? accessType,
  }) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.createLesson(
      chapterId: chapterId,
      title: title,
      description: description,
      type: type,
      videoUrl: videoUrl,
      videoPublicId: videoPublicId,
      thumbnailUrl: thumbnailUrl,
      thumbnailPublicId: thumbnailPublicId,
      noteUrl: noteUrl,
      notePublicId: notePublicId,
      noteFileType: noteFileType,
      content: content,
      displayOrder: displayOrder,
      isFreePreview: isFreePreview,
      accessType: accessType,
    );

    isUpdating = false;

    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }

    notifyListeners();

    return result.isSuccess;
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE LESSON
  // ─────────────────────────────────────────────────────────────

  /// [removeDescription] / [removeVideo] / [removeThumbnail] / [removeNote]:
  /// pass true when the user explicitly cleared that field in the edit
  /// sheet, so the backend actually clears it (and cleans up the old
  /// Cloudinary file for video/thumbnail/note) instead of silently leaving
  /// it untouched.
  Future<bool> updateLesson({
    required int chapterId,
    required int lessonId,
    String? title,
    String? description,
    bool removeDescription = false,
    LessonType? type,
    String? videoUrl,
    String? videoPublicId,
    bool removeVideo = false,
    String? thumbnailUrl,
    String? thumbnailPublicId,
    bool removeThumbnail = false,
    String? noteUrl,
    String? notePublicId,
    String? noteFileType,
    bool removeNote = false,
    String? content,
    int? displayOrder,
    bool? isFreePreview,
    LessonAccessType? accessType,
  }) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.updateLesson(
      chapterId: chapterId,
      lessonId: lessonId,
      title: title,
      description: description,
      removeDescription: removeDescription,
      type: type,
      videoUrl: videoUrl,
      videoPublicId: videoPublicId,
      removeVideo: removeVideo,
      thumbnailUrl: thumbnailUrl,
      thumbnailPublicId: thumbnailPublicId,
      removeThumbnail: removeThumbnail,
      noteUrl: noteUrl,
      notePublicId: notePublicId,
      noteFileType: noteFileType,
      removeNote: removeNote,
      content: content,
      displayOrder: displayOrder,
      isFreePreview: isFreePreview,
      accessType: accessType,
    );

    isUpdating = false;

    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }

    notifyListeners();

    return result.isSuccess;
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE LESSON
  // ─────────────────────────────────────────────────────────────

  Future<bool> deleteLesson({
    required int chapterId,
    required int lessonId,
  }) async {
    isDeleting = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.deleteLesson(
      chapterId: chapterId,
      lessonId: lessonId,
    );

    isDeleting = false;

    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }

    notifyListeners();

    return result.isSuccess;
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE VIDEO FROM CLOUDINARY
  // ─────────────────────────────────────────────────────────────

  Future<bool> deleteVideoAsset({
    required String publicId,
  }) async {
    if (publicId.isEmpty) {
      errorMessage = 'Video public ID is missing.';
      notifyListeners();
      return false;
    }

    isDeleting = true;
    errorMessage = null;
    notifyListeners();

    final result = await _uploadService.deleteVideo(publicId);

    isDeleting = false;

    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE NOTE FROM CLOUDINARY
  // ─────────────────────────────────────────────────────────────

  Future<bool> deleteNoteAsset({
    required String publicId,
  }) async {
    if (publicId.isEmpty) {
      errorMessage = 'Note public ID is missing.';
      notifyListeners();
      return false;
    }

    isDeleting = true;
    errorMessage = null;
    notifyListeners();

    final result = await _uploadService.deleteNote(publicId);

    isDeleting = false;

    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE THUMBNAIL FROM CLOUDINARY
  // ─────────────────────────────────────────────────────────────

  Future<bool> deleteThumbnailAsset({
    required String publicId,
  }) async {
    if (publicId.isEmpty) {
      errorMessage = 'Thumbnail public ID is missing.';
      notifyListeners();
      return false;
    }

    isDeleting = true;
    errorMessage = null;
    notifyListeners();

    final result = await _uploadService.deleteThumbnail(publicId);

    isDeleting = false;

    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH LESSONS
  // ─────────────────────────────────────────────────────────────

  /// Fetches all lessons for [chapterId] and stores them in [lessons].
  /// Call this to populate your lesson listing UI.
  Future<bool> fetchLessonsByChapter({
    required int chapterId,
  }) async {
    isLoadingList = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.getLessonsByChapter(
      chapterId: chapterId,
    );

    isLoadingList = false;

    if (result.isSuccess) {
      lessons = (result.data ?? [])
          .map(Lesson.fromJson)
          .toList();
    } else {
      errorMessage = result.errorMessage;
    }

    notifyListeners();

    return result.isSuccess;
  }

  // ─────────────────────────────────────────────────────────────
  // CLEAR ERROR
  // ─────────────────────────────────────────────────────────────

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}