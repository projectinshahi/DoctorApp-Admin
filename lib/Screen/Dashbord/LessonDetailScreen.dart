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
import '../../services/lesson_services.dart';
import '../../provider/lesson_upload_provider.dart';
import '../../widget/note_web_viewer_stub.dart'
if (dart.library.html) '../../widget/note_web_viewer_web.dart';
import '../../models/panal_model.dart';
import '../../provider/admin_plan_provider.dart';
import '../../services/admin_plan_services.dart';
import 'add_edit_lesson_sheet.dart';
import 'add_edit_plan_sheet.dart';
import 'lesson_subscription_sheet.dart';
import 'lesson_badges.dart';
import '../../widget/breadcrumb_widget.dart';


class LessonDetailScreen extends StatelessWidget {
  final int lessonId;

  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LessonDetailsProvider()..loadLesson(lessonId, includeChapter: true)),
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

  /// Every plan sold on this lesson's course, so the subscription section can
  /// show the full ladder - not just the one plan attached to the lesson.
  List<AdminPlanModel> _coursePlans = [];
  bool _plansLoading = false;
  String? _plansError;
  int? _plansLoadedForCourseId;
  int? _deletingPlanId;

  void _ensureCoursePlans(int? courseId, {bool force = false}) {
    if (courseId == null) return;
    if (!force && _plansLoadedForCourseId == courseId) return;
    _plansLoadedForCourseId = courseId;

    // Called from build(), so never setState synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _plansLoading) return;
      setState(() {
        _plansLoading = true;
        _plansError = null;
      });
      AdminPlanService().getPlansForCourse(courseId).then((plans) {
        if (!mounted) return;
        setState(() {
          _coursePlans = plans;
          _plansLoading = false;
        });
      }).catchError((e) {
        if (!mounted) return;
        setState(() {
          _plansError = 'Could not load the course plans.';
          _plansLoading = false;
        });
      });
    });
  }

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
      courseId: lesson.chapter?.courseId, // NEW
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
      initialContent: lesson.content, // legacy reference, read-only
      initialQuizId: lesson.quizId,
      initialIsFreePreview: lesson.isFreePreview,
      initialAccessType: lesson.accessTypeEnum,
      initialStatus: lesson.statusEnum,
      initialPlanIds: lesson.planIds, // NEW
      initialPlans: lesson.plans, // NEW
      initialDisplayOrder: lesson.displayOrder,
    );

    if (updated == true && context.mounted) {
      setState(_resetVideoState);
      await context.read<LessonDetailsProvider>().loadLesson(lesson.id, includeChapter: true);
    }
  }

  /// Access + plans only. Same sheet the chapter lesson list opens, so the
  /// two screens can't drift apart.
  Future<void> _openSubscriptionSheet(BuildContext context, LessonDetail lesson) async {
    final courseId = lesson.chapter?.courseId;
    if (courseId == null) {
      _showSnack(context, 'Course not known for this lesson - use Edit lesson.', isError: true);
      return;
    }

    final saved = await showLessonSubscriptionSheet(
      context,
      courseId: courseId,
      chapterId: lesson.chapterId,
      lessonId: lesson.id,
      lessonTitle: lesson.title,
      accessType: lesson.accessTypeEnum,
      planIds: lesson.planIds,
      isFreePreview: lesson.isFreePreview,
      attachedPlans: lesson.plans,
    );

    if (saved != true || !context.mounted) return;
    _showSnack(context, 'Subscription updated');
    _ensureCoursePlans(courseId, force: true);
    await context.read<LessonDetailsProvider>().loadLesson(lesson.id, includeChapter: true);
  }

  /// Edit one plan in place from the subscription list.
  Future<void> _editPlan(BuildContext context, LessonDetail lesson, _PlanRow row) async {
    final courseId = lesson.chapter?.courseId;
    if (courseId == null) return;

    final saved = await showAddEditPlanSheet(
      context,
      courseId: courseId,
      existingPlan: AdminPlanModel(
        id: row.id,
        courseId: courseId,
        title: row.title,
        description: row.description,
        price: row.price,
        durationDays: row.durationDays,
        isActive: row.isActive,
      ),
    );
    if (saved == null || !context.mounted) return;
    _showSnack(context, 'Plan updated');
    _ensureCoursePlans(courseId, force: true);
    await context.read<LessonDetailsProvider>().loadLesson(lesson.id, includeChapter: true);
  }

  /// Delete a plan from the course. It disappears from every lesson that used
  /// it, so the confirmation says as much.
  Future<void> _deletePlan(BuildContext context, LessonDetail lesson, _PlanRow row) async {
    final courseId = lesson.chapter?.courseId;
    if (courseId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete plan?'),
        content: Text(
          row.isRequired
              ? '"${row.title}" unlocks this lesson. Deleting it removes the plan from the '
                  'whole course and students on it lose access. This cannot be undone.'
              : 'This permanently deletes "${row.title}" from the course. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _deletingPlanId = row.id);
    final provider = AdminPlanProvider();
    final ok = await provider.deletePlan(courseId: courseId, planId: row.id);
    if (!context.mounted) return;
    setState(() => _deletingPlanId = null);

    if (!ok) {
      _showSnack(context, provider.deleteErrorMessage ?? 'Failed to delete plan', isError: true);
      return;
    }
    _showSnack(context, 'Plan deleted');
    _ensureCoursePlans(courseId, force: true);
    await context.read<LessonDetailsProvider>().loadLesson(lesson.id, includeChapter: true);
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
      await context.read<LessonDetailsProvider>().loadLesson(lesson.id, includeChapter: true);
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
      await context.read<LessonDetailsProvider>().loadLesson(lesson.id, includeChapter: true);
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

  // ── Subscription & access ──────────────────────────────────────────
  // Replaces the old single amber card. A free lesson gets a one-line green
  // strip; a premium lesson gets the unlock rule plus every plan sold on the
  // course, with the ones that unlock this lesson marked.

  Widget _buildSubscriptionSection(BuildContext context, LessonDetail lesson) {
    final isPremium = lesson.accessTypeEnum == LessonAccessType.premium;

    if (!isPremium) return _buildFreeAccessStrip(context, lesson);

    final requiredIds = lesson.requiredPlanIds;

    // Course plans first (they carry the description); then any attached plan
    // the course list didn't return, so a stale/failed fetch never hides the
    // plan this lesson actually needs.
    final rows = <_PlanRow>[
      for (final p in _coursePlans)
        _PlanRow(
          id: p.id,
          title: p.title,
          description: p.description,
          price: p.price,
          durationDays: p.durationDays,
          isActive: p.isActive,
          isRequired: requiredIds.contains(p.id),
        ),
    ];
    for (final p in lesson.plans) {
      if (rows.any((r) => r.id == p.id)) continue;
      rows.add(_PlanRow(
        id: p.id,
        title: p.title,
        price: p.price,
        durationDays: p.durationDays,
        isActive: p.isActive,
        isRequired: true,
      ));
    }

    // Required plans on top, then cheapest first.
    rows.sort((a, b) => a.isRequired == b.isRequired
        ? a.price.compareTo(b.price)
        : (a.isRequired ? -1 : 1));

    final requiredCount = rows.where((r) => r.isRequired).length;
    final anySubscription = requiredIds.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 17,
                decoration: BoxDecoration(color: kPremiumColor, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 9),
              const Text(
                'Subscription & Access',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LmsColors.textDark),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openSubscriptionSheet(context, lesson),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text('Manage', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  foregroundColor: kPremiumColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        _buildUnlockRuleCard(
          anySubscription: anySubscription,
          rows: rows,
          requiredCount: requiredCount,
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Row(
            children: [
              Text(
                'PLANS ON THIS COURSE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: LmsColors.textGrey.withOpacity(0.9),
                ),
              ),
              const SizedBox(width: 8),
              if (rows.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: LmsColors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LmsColors.textGrey),
                  ),
                ),
              const Spacer(),
              if (_plansLoading)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: kPremiumColor),
                ),
            ],
          ),
        ),

        if (_plansError != null)
          _buildPlansError(lesson)
        else if (rows.isEmpty && !_plansLoading)
          _buildNoPlansCard(context, lesson)
        else
          ...rows.map(
            (r) => _buildPlanTile(
              context,
              lesson,
              r,
              unlockedByAny: anySubscription,
            ),
          ),
      ],
    );
  }

  /// Green one-liner: nothing to explain when the lesson is open to everyone,
  /// but it still needs a way in to switch the lesson to premium.
  Widget _buildFreeAccessStrip(BuildContext context, LessonDetail lesson) {
    final preview = lesson.isFreePreview;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: LmsColors.success.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.success.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: LmsColors.success.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              preview ? Icons.visibility_outlined : Icons.lock_open_rounded,
              size: 16,
              color: LmsColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              preview
                  ? 'Free preview - visible to every student, no subscription needed.'
                  : 'Free lesson - no subscription needed.',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: LmsColors.textDark,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _openSubscriptionSheet(context, lesson),
            style: TextButton.styleFrom(
              foregroundColor: LmsColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Change', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// The headline: what a student must hold to open this lesson.
  Widget _buildUnlockRuleCard({
    required bool anySubscription,
    required List<_PlanRow> rows,
    required int requiredCount,
  }) {
    final required = rows.where((r) => r.isRequired).toList();
    final headline = anySubscription
        ? 'Any active subscription'
        : required.isEmpty
            ? 'Loading plan...'
            : required.map((r) => r.title).join('  •  ');

    final subline = anySubscription
        ? rows.isEmpty
            ? 'Unlocked by any plan the student holds for this course.'
            : 'Unlocked by any of the ${rows.length} plans below.'
        : requiredCount > 1
            ? 'Unlocked by any one of these $requiredCount plans.'
            : 'Only this plan unlocks the lesson.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2F16), Color(0xFF1F1B12)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: kPremiumColor.withOpacity(0.20), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, size: 15, color: Color(0xFFF5C86B)),
              const SizedBox(width: 7),
              Text(
                'UNLOCK RULE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: const Color(0xFFF5C86B).withOpacity(0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subline,
            style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.62), height: 1.45),
          ),
        ],
      ),
    );
  }

  /// One plan in the course ladder. Amber and ticked when it unlocks this
  /// lesson, muted otherwise.
  Widget _buildPlanTile(
    BuildContext context,
    LessonDetail lesson,
    _PlanRow row, {
    required bool unlockedByAny,
  }) {
    final unlocks = row.isRequired || unlockedByAny;
    final isDeleting = _deletingPlanId == row.id;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocks ? const Color(0xFFFFFBF2) : LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocks ? kPremiumColor.withOpacity(0.35) : LmsColors.border,
          width: unlocks ? 1.3 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: unlocks ? kPremiumColor.withOpacity(0.14) : LmsColors.bg,
              shape: BoxShape.circle,
              border: unlocks ? null : Border.all(color: LmsColors.border),
            ),
            child: Icon(
              unlocks ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 16,
              color: unlocks ? kPremiumColor : LmsColors.textGrey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: unlocks ? LmsColors.textDark : LmsColors.textGrey,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (!row.isActive) ...[
                      const SizedBox(width: 8),
                      _tag('INACTIVE', LmsColors.error),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      'AED ${row.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: unlocks ? kPremiumColor : LmsColors.textGrey,
                      ),
                    ),
                    const Text('  ·  ', style: TextStyle(color: LmsColors.textGrey)),
                    Text(
                      '${row.durationDays} days',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LmsColors.textGrey,
                      ),
                    ),
                  ],
                ),
                if (row.description != null && row.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    row.description!.trim(),
                    style: const TextStyle(fontSize: 12, color: LmsColors.textGrey, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _tag(
                row.isRequired
                    ? 'REQUIRED'
                    : unlockedByAny
                        ? 'UNLOCKS'
                        : 'NOT LINKED',
                unlocks ? kPremiumColor : LmsColors.textGrey,
              ),
              const SizedBox(height: 2),
              if (isDeleting)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: LmsColors.error),
                  ),
                )
              else
                SizedBox(
                  height: 28,
                  width: 28,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded, size: 16, color: LmsColors.textGrey),
                    tooltip: 'Plan actions',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'edit') _editPlan(context, lesson, row);
                      if (v == 'delete') _deletePlan(context, lesson, row);
                      if (v == 'assign') _openSubscriptionSheet(context, lesson);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'assign',
                        child: Row(children: [
                          Icon(
                            row.isRequired ? Icons.link_off_rounded : Icons.link_rounded,
                            size: 16,
                            color: LmsColors.textDark,
                          ),
                          const SizedBox(width: 8),
                          Text(row.isRequired ? 'Detach from lesson' : 'Attach to lesson'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 16, color: LmsColors.textDark),
                          SizedBox(width: 8),
                          Text('Edit plan'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: LmsColors.error),
                          SizedBox(width: 8),
                          Text('Delete plan', style: TextStyle(color: LmsColors.error)),
                        ]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: color),
      ),
    );
  }

  Widget _buildPlansError(LessonDetail lesson) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.errorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 17, color: LmsColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _plansError!,
              style: const TextStyle(fontSize: 12.5, color: LmsColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _ensureCoursePlans(lesson.chapter?.courseId, force: true),
            style: TextButton.styleFrom(
              foregroundColor: LmsColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlansCard(BuildContext context, LessonDetail lesson) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_membership_outlined, size: 18, color: LmsColors.textGrey),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This course has no subscription plans yet, so nobody can buy access to this lesson.',
              style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey, height: 1.45),
            ),
          ),
          TextButton(
            onPressed: () => _openSubscriptionSheet(context, lesson),
            style: TextButton.styleFrom(
              foregroundColor: LmsColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Add', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// One label per plan that unlocks the lesson. Falls back to the fetched
  /// course list, then to the bare id, so a badge is never blank.
  List<String> _planLabels(LessonDetail lesson) {
    return [
      for (final id in lesson.planIds)
        lesson.plans.where((p) => p.id == id).map((p) => p.title).firstOrNull ??
            _coursePlans.where((p) => p.id == id).map((p) => p.title).firstOrNull ??
            'Plan #$id',
    ];
  }

  Widget _buildHeader(LessonDetail lesson) {
    final isPremium = lesson.accessTypeEnum == LessonAccessType.premium;
    _ensureCoursePlans(lesson.chapter?.courseId);

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
          LmsBreadcrumb(
            path: ['Courses', lesson.chapter?.title, 'Lesson'],
          ),
          const SizedBox(height: 8),
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
          LessonBadgeRow(
            type: lesson.type,
            status: lesson.status,
            accessType: lesson.accessType,
            isFreePreview: lesson.isFreePreview,
            // The API nests the plans on the lesson, so the badges name them
            // immediately instead of waiting on the course plan list.
            planLabels: _planLabels(lesson),
            hasVideo: lesson.hasVideo,
          ),
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

                _buildSubscriptionSection(context, lesson),

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

/// Flattened plan for the subscription list, so the course-plan list and the
/// plan nested on the lesson render through one widget.
class _PlanRow {
  final int id;
  final String title;
  final String? description;
  final double price;
  final int durationDays;
  final bool isActive;
  final bool isRequired;

  const _PlanRow({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.durationDays,
    required this.isActive,
    required this.isRequired,
  });
}
