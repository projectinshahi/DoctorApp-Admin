import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/lesson_detail_model.dart';
import '../../provider/lesson_details_provider.dart';
import '../../provider/lessoedit_provider.dart';
import '../../provider/lesson_upload_provider.dart';
import '../../services/lesson_services.dart' hide LessonAccessType, LessonType; // 👈 add this — defines LessonType, LessonAccessType, and the apiValue extension
import '../../widget/note_web_viewer_stub.dart'
if (dart.library.html) '../../widget/note_web_viewer_web.dart';
import 'add_edit_lesson_sheet.dart';


class LessonDetailScreen extends StatelessWidget {
  final int lessonId;

  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LessonDetailsProvider()..loadLesson(lessonId)),
        ChangeNotifierProvider(create: (_) => LessonUpdateProvider()),
      ],
      child: const _LessonDetailBody(),
    );
  }
}

class _LessonDetailBody extends StatefulWidget {
  const _LessonDetailBody();

  @override
  State<_LessonDetailBody> createState() => _LessonDetailBodyState();
}

class _LessonDetailBodyState extends State<_LessonDetailBody> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isVideoInitializing = false;
  bool _youtubeReady = false;
  bool _youtubeTimedOut = false;
  String? _videoError;
  int? _initializedForLessonId;
  Timer? _youtubeTimeoutTimer;
  bool _videoStarted = false; // NEW — controls when the thumbnail poster gets replaced

  bool _isYoutubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  Future<void> _initVideo(LessonDetail lesson) async {
    if (_initializedForLessonId == lesson.id) return;
    _initializedForLessonId = lesson.id;

    final url = lesson.videoUrl!;

    if (_isYoutubeUrl(url)) {
      final videoId = YoutubePlayerController.convertUrlToId(url);
      if (videoId == null) {
        setState(() => _videoError = 'Invalid YouTube link.');
        return;
      }

      setState(() {
        _youtubeReady = false;
        _youtubeTimedOut = false;
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: false,
          params: const YoutubePlayerParams(showFullscreenButton: true),
        );
      });

      _youtubeController!.listen((value) {
        if (!_youtubeReady && value.playerState != PlayerState.unknown) {
          if (!mounted) return;
          setState(() => _youtubeReady = true);
          _youtubeTimeoutTimer?.cancel();
        }
      });

      _youtubeTimeoutTimer?.cancel();
      _youtubeTimeoutTimer = Timer(const Duration(seconds: 20), () {
        if (!mounted || _youtubeReady) return;
        setState(() => _youtubeTimedOut = true);
      });

      return;
    }

    setState(() {
      _isVideoInitializing = true;
      _videoError = null;
    });

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _videoController = controller;
        _isVideoInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoError = 'Failed to load video. Please try again.';
        _isVideoInitializing = false;
      });
    }
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _resetVideoState() {
    _initializedForLessonId = null;
    _videoController?.dispose();
    _videoController = null;
    _youtubeController?.close();
    _youtubeController = null;
    _youtubeReady = false;
    _youtubeTimedOut = false;
    _videoError = null;
    _videoStarted = false;
    _youtubeTimeoutTimer?.cancel();
  }

  Future<void> _openEditSheet(BuildContext context, LessonDetail lesson) async {
    final updated = await showAddEditLessonSheet(
      context,
      chapterId: lesson.chapterId,
      lessonId: lesson.id,
      initialTitle: lesson.title,
      initialDescription: lesson.description,
      initialType: lesson.typeEnum,
      initialVideoUrl: lesson.videoUrl,
      initialVideoPublicId: lesson.videoPublicId,
      initialThumbnailUrl: lesson.thumbnailUrl,
      initialThumbnailPublicId: lesson.thumbnailPublicId,
      initialNoteUrl: lesson.noteUrl,
      initialNotePublicId: lesson.notePublicId,
      initialNoteFileType: lesson.noteFileType,
      initialContent: lesson.content,
      initialIsFreePreview: lesson.isFreePreview,
      initialAccessType: lesson.accessTypeEnum,
      initialDisplayOrder: lesson.displayOrder,
    );

    if (updated == true && context.mounted) {
      setState(_resetVideoState);
      await context.read<LessonDetailsProvider>().loadLesson(lesson.id);
    }
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? LmsColors.error : LmsColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
      ),
    );
  }

  Future<void> _confirmDeleteVideo(BuildContext context, LessonDetail lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove video?'),
        content: const Text('This permanently deletes the video from storage. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final updateProvider = context.read<LessonUpdateProvider>();

    if (lesson.videoPublicId != null && lesson.videoPublicId!.isNotEmpty) {
      final assetDeleted = await updateProvider.deleteVideoAsset(publicId: lesson.videoPublicId!);
      if (!assetDeleted) {
        if (context.mounted) _showSnack(context, updateProvider.errorMessage ?? 'Failed to remove video', isError: true);
        return;
      }
    }

    final updated = await updateProvider.updateLesson(
      chapterId: lesson.chapterId,
      lessonId: lesson.id,
      removeVideo: true,
    );

    if (!context.mounted) return;
    if (updated) {
      _showSnack(context, 'Video removed');
      setState(_resetVideoState);
      await context.read<LessonDetailsProvider>().loadLesson(lesson.id);
    } else {
      _showSnack(context, updateProvider.errorMessage ?? 'Failed to remove video', isError: true);
    }
  }

  Future<void> _confirmDeleteNote(BuildContext context, LessonDetail lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove note?'),
        content: const Text('This permanently deletes the note from storage. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final updateProvider = context.read<LessonUpdateProvider>();

    if (lesson.notePublicId != null && lesson.notePublicId!.isNotEmpty) {
      final assetDeleted = await updateProvider.deleteNoteAsset(publicId: lesson.notePublicId!);
      if (!assetDeleted) {
        if (context.mounted) _showSnack(context, updateProvider.errorMessage ?? 'Failed to remove note', isError: true);
        return;
      }
    }

    final updated = await updateProvider.updateLesson(
      chapterId: lesson.chapterId,
      lessonId: lesson.id,
      removeNote: true,
    );

    if (!context.mounted) return;
    if (updated) {
      _showSnack(context, 'Note removed');
      await context.read<LessonDetailsProvider>().loadLesson(lesson.id);
    } else {
      _showSnack(context, updateProvider.errorMessage ?? 'Failed to remove note', isError: true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.close();
    _youtubeTimeoutTimer?.cancel();
    super.dispose();
  }

  /// The hero area at the top: video player (with thumbnail poster while
  /// loading), or just the thumbnail as a static banner if there's no video.
  Widget _buildHero(LessonDetail lesson) {
    final hasThumbnail = lesson.thumbnailUrl != null && lesson.thumbnailUrl!.isNotEmpty;

    // ── No video at all: show the thumbnail as a simple banner, or a
    // placeholder icon block if there's no thumbnail either. ──
    if (!lesson.hasVideo) {
      if (!hasThumbnail) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          lesson.thumbnailUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => Container(color: LmsColors.bg),
        ),
      );
    }

    // ── Has a video: build the player, with a thumbnail poster layered
    // underneath until the video is actually ready and started. ──
    Widget playerLayer;

    if (_youtubeController != null) {
      playerLayer = Stack(
        fit: StackFit.expand,
        children: [
          YoutubePlayer(controller: _youtubeController!),
          if (!_youtubeReady && !_youtubeTimedOut) _posterOverlay(hasThumbnail ? lesson.thumbnailUrl : null, loading: true),
          if (_youtubeTimedOut && !_youtubeReady)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This video is taking longer than usual to load.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openExternally(lesson.videoUrl!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Watch on YouTube'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LmsColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (_videoError != null) {
      playerLayer = Stack(
        fit: StackFit.expand,
        children: [
          _posterOverlay(hasThumbnail ? lesson.thumbnailUrl : null, loading: false, dim: true),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 30),
                const SizedBox(height: 8),
                Text(_videoError!, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    _initializedForLessonId = null;
                    _initVideo(lesson);
                  },
                  style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_isVideoInitializing || _videoController == null || !_videoController!.value.isInitialized) {
      playerLayer = _posterOverlay(hasThumbnail ? lesson.thumbnailUrl : null, loading: true);
    } else {
      // Video ready — show a tappable poster until the user hits play,
      // then swap to the real player.
      if (!_videoStarted) {
        playerLayer = _posterOverlay(
          hasThumbnail ? lesson.thumbnailUrl : null,
          loading: false,
          showPlayButton: true,
          onPlayTap: () {
            setState(() => _videoStarted = true);
            _videoController!.play();
          },
        );
      } else {
        playerLayer = Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  ),
                ),
                padding: const EdgeInsets.only(top: 30),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        size: 32,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                        });
                      },
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        colors: VideoProgressColors(
                          playedColor: LmsColors.primary,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: LmsColors.primary.withOpacity(0.14), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: playerLayer,
    );
  }

  Widget _posterOverlay(
      String? thumbnailUrl, {
        required bool loading,
        bool dim = false,
        bool showPlayButton = false,
        VoidCallback? onPlayTap,
      }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailUrl != null)
          Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          )
        else
          Container(color: Colors.black),
        if (dim || loading || showPlayButton) Container(color: Colors.black.withOpacity(0.35)),
        if (loading)
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
        if (showPlayButton)
          Center(
            child: GestureDetector(
              onTap: onPlayTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: LmsColors.primary, size: 34),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoteViewer(LessonDetail lesson) {
    final fileType = (lesson.noteFileType ?? '').toLowerCase();
    final isPdf = fileType == 'pdf';
    final isDoc = fileType == 'doc' || fileType == 'docx';

    if (isPdf) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LmsColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: SfPdfViewer.network(
          lesson.noteUrl!,
          canShowScrollHead: true,
          canShowScrollStatus: true,
        ),
      );
    }

    if (isDoc && isOfficeViewerSupported) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LmsColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: buildInlineOfficeViewer(lesson.noteUrl!, 'office-viewer-${lesson.id}'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: LmsColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "This note can't be previewed inline on this platform.",
                  style: TextStyle(fontSize: 13, color: LmsColors.textGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openExternally(lesson.noteUrl!),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LmsColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LessonDetail lesson) {
    final isPremium = lesson.accessTypeEnum == LessonAccessType.premium;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPremium
              ? [const Color(0xFFFFF8E8), const Color(0xFFFFFDF7)]
              : [LmsColors.surface, LmsColors.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPremium ? Colors.amber.withOpacity(0.35) : LmsColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: LmsColors.textDark,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
              ),
              if (isPremium)
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.16), shape: BoxShape.circle),
                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 19),
                ),
            ],
          ),
          if (lesson.description != null && lesson.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              lesson.description!,
              style: const TextStyle(fontSize: 14, color: LmsColors.textGrey, height: 1.55),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(
                icon: isPremium ? Icons.workspace_premium_rounded : Icons.lock_open_rounded,
                label: isPremium ? 'Premium' : 'Free',
                color: isPremium ? Colors.amber.shade800 : LmsColors.success,
                bg: isPremium ? Colors.amber.withOpacity(0.16) : LmsColors.success.withOpacity(0.12),
              ),
              if (lesson.isFreePreview)
                _badge(
                  icon: Icons.visibility_outlined,
                  label: 'Free Preview',
                  color: LmsColors.primary,
                  bg: LmsColors.primary.withOpacity(0.1),
                ),
              _badge(
                icon: lesson.typeEnum == LessonType.video
                    ? Icons.play_circle_outline_rounded
                    : lesson.typeEnum == LessonType.quiz
                    ? Icons.quiz_outlined
                    : Icons.article_outlined,
                label: lesson.typeEnum.apiValue[0].toUpperCase() + lesson.typeEnum.apiValue.substring(1),
                color: LmsColors.textDark,
                bg: LmsColors.textDark.withOpacity(0.06),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge({required IconData icon, required String label, required Color color, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onDelete, bool isDeleting = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 17,
            decoration: BoxDecoration(color: LmsColors.primary, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LmsColors.textDark)),
          const Spacer(),
          if (onDelete != null)
            isDeleting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: LmsColors.error),
            )
                : TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: LmsColors.error),
              label: const Text('Remove', style: TextStyle(color: LmsColors.error, fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LessonDetailsProvider, LessonUpdateProvider>(
      builder: (context, detailsProvider, updateProvider, child) {
        if (detailsProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: LmsColors.primary)),
          );
        }

        if (detailsProvider.errorMessage != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lesson')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: LmsColors.error, size: 40),
                    const SizedBox(height: 12),
                    Text(detailsProvider.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: LmsColors.error)),
                  ],
                ),
              ),
            ),
          );
        }

        final lesson = detailsProvider.lesson;
        if (lesson == null) {
          return const Scaffold(body: Center(child: Text('Lesson not found.')));
        }

        if (lesson.hasVideo) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _initVideo(lesson));
        }

        return Scaffold(
          backgroundColor: LmsColors.bg,
          appBar: AppBar(
            backgroundColor: LmsColors.bg,
            elevation: 0,
            foregroundColor: LmsColors.textDark,
            title: const Text('Lesson', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit lesson',
                onPressed: () => _openEditSheet(context, lesson),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(lesson),

                if (lesson.hasVideo)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: updateProvider.isDeleting
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: LmsColors.error),
                      )
                          : TextButton.icon(
                        onPressed: () => _confirmDeleteVideo(context, lesson),
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: LmsColors.error),
                        label: const Text('Remove video', style: TextStyle(color: LmsColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                      ),
                    ),
                  ),

                _buildHeader(lesson),

                if (lesson.hasNote) ...[
                  _sectionHeader(
                    'Lesson Notes',
                    onDelete: () => _confirmDeleteNote(context, lesson),
                    isDeleting: updateProvider.isDeleting,
                  ),
                  _buildNoteViewer(lesson),
                  const SizedBox(height: 20),
                ],

                if (lesson.typeEnum == LessonType.quiz && lesson.content != null) ...[
                  _sectionHeader('Quiz'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LmsColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LmsColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.quiz_outlined, color: LmsColors.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Quiz reference: ${lesson.content}')),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}