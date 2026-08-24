import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_details_model.dart';
import '../../models/course_get_model.dart';
import '../../provider/course_details_provider.dart';
import '../../provider/course_get_provider.dart';
import '../../widget/shimmer_loading.dart';

/// One lesson that actually has a video, flattened out of the course tree.
class _VideoLesson {
  final Lesson lesson;
  final String chapterTitle;
  final String? examTypeTitle;

  const _VideoLesson({
    required this.lesson,
    required this.chapterTitle,
    this.examTypeTitle,
  });

  String get url => lesson.videoUrl ?? '';

  String get location => [
        if (examTypeTitle != null) examTypeTitle!,
        chapterTitle,
      ].join(' · ');
}

/// The Videos tab: pick a course, see every lesson in it that has a video,
/// play any of them without leaving the page.
///
/// There is no "list all videos" endpoint - videos hang off lessons, which
/// hang off chapters, which hang off exam types. So the course tree is loaded
/// once per course and walked for lessons carrying a videoUrl.
class LessonVideoScreen extends StatefulWidget {
  const LessonVideoScreen({super.key});

  @override
  State<LessonVideoScreen> createState() => _LessonVideoScreenState();
}

class _LessonVideoScreenState extends State<LessonVideoScreen> {
  final _detailsProvider = CourseDetailsProvider();

  int? _courseId;
  _VideoLesson? _playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<CourseListGetProvider>();
      await provider.fetchCourses(limit: 100);
      // Every course is on screen now, so an empty pane behind a "pick one"
      // prompt is a step with nothing behind it.
      if (mounted && provider.courses.isNotEmpty && _courseId == null) {
        _selectCourse(provider.courses.first.id);
      }
    });
  }

  @override
  void dispose() {
    _detailsProvider.dispose();
    super.dispose();
  }

  Future<void> _selectCourse(int? courseId) async {
    if (courseId == null || courseId == _courseId) return;
    setState(() {
      _courseId = courseId;
      _playing = null;
    });
    await _detailsProvider.loadCourseDetails(courseId);
    if (mounted) setState(() {});
  }

  /// Walks course -> exam type -> chapter -> lesson, and the course's own
  /// chapters for courses that skip exam types.
  List<_VideoLesson> _videosOf(CourseDetails course) {
    final found = <_VideoLesson>[];

    void collect(Chapter chapter, String? examType) {
      for (final lesson in chapter.lessons) {
        if (lesson.videoUrl != null && lesson.videoUrl!.trim().isNotEmpty) {
          found.add(_VideoLesson(
            lesson: lesson,
            chapterTitle: chapter.title,
            examTypeTitle: examType,
          ));
        }
      }
    }

    for (final chapter in course.chapters) {
      collect(chapter, null);
    }
    for (final type in course.courseTypes) {
      for (final chapter in type.chapters) {
        collect(chapter, type.title);
      }
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseListGetProvider>();

    return ListenableBuilder(
      listenable: _detailsProvider,
      builder: (context, _) {
        final course = _detailsProvider.courseDetails;
        final videos = course == null ? <_VideoLesson>[] : _videosOf(course);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Videos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Every lesson with a video, by course.',
                style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
              ),
              const SizedBox(height: 16),

              _coursePicker(courseProvider),
              const SizedBox(height: 20),

              if (_courseId == null)
                const SizedBox.shrink()
              else if (_detailsProvider.isLoading)
                const ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero)
              else if (_detailsProvider.errorMessage != null)
                _Notice(
                  icon: Icons.error_outline_rounded,
                  color: LmsColors.error,
                  text: _detailsProvider.errorMessage!,
                )
              else if (videos.isEmpty)
                const _Notice(
                  icon: Icons.videocam_off_outlined,
                  text: 'No lesson in this course has a video yet.',
                )
              else ...[
                if (_playing != null) ...[
                  _Player(
                    key: ValueKey(_playing!.lesson.id),
                    video: _playing!,
                    onClose: () => setState(() => _playing = null),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  '${videos.length} video${videos.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LmsColors.textGrey,
                  ),
                ),
                const SizedBox(height: 10),
                for (final video in videos)
                  _VideoRow(
                    video: video,
                    isPlaying: _playing?.lesson.id == video.lesson.id,
                    onTap: () => setState(() => _playing = video),
                  ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// Courses as a chip rail rather than a dropdown.
  ///
  /// A dropdown hides every option behind a tap and shows one at a time, which
  /// is the wrong trade when there are only a handful of courses and switching
  /// between them is the whole point of this screen.
  Widget _coursePicker(CourseListGetProvider provider) {
    if (provider.isLoadingCourses && provider.courses.isEmpty) {
      return const LmsShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 140, height: 36, radius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 110, height: 36, radius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 128, height: 36, radius: 18),
          ],
        ),
      );
    }

    if (provider.courses.isEmpty) {
      return const _Notice(
        icon: Icons.menu_book_outlined,
        text: 'No courses yet, so there is nothing to show videos for.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final CourseListGetModel course in provider.courses)
          _CourseChip(
            title: course.title,
            isPremium: course.accessType == 'premium',
            selected: course.id == _courseId,
            onTap: () => _selectCourse(course.id),
          ),
      ],
    );
  }
}

class _CourseChip extends StatelessWidget {
  final String title;
  final bool isPremium;
  final bool selected;
  final VoidCallback onTap;

  const _CourseChip({
    required this.title,
    required this.isPremium,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LmsColors.primary : LmsColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? LmsColors.primary : LmsColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPremium) ...[
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 14,
                  color: selected ? Colors.white : const Color(0xFFB8860B),
                ),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : LmsColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays whichever lesson was tapped. YouTube links and uploaded files need
/// different players, so the URL decides which one is built.
class _Player extends StatefulWidget {
  final _VideoLesson video;
  final VoidCallback onClose;

  const _Player({super.key, required this.video, required this.onClose});

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  VideoPlayerController? _file;
  YoutubePlayerController? _youtube;
  String? _error;
  bool _initializing = false;

  static bool _isYoutube(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _file?.dispose();
    _youtube?.close();
    super.dispose();
  }

  Future<void> _open() async {
    final url = widget.video.url;

    if (_isYoutube(url)) {
      final id = YoutubePlayerController.convertUrlToId(url);
      if (id == null) {
        setState(() => _error = 'That YouTube link could not be read.');
        return;
      }
      setState(() {
        _youtube = YoutubePlayerController.fromVideoId(
          videoId: id,
          autoPlay: false,
          params: const YoutubePlayerParams(showFullscreenButton: true),
        );
      });
      return;
    }

    setState(() => _initializing = true);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _initializing = false;
        _file = controller;
      });
      controller.play();
    } catch (e) {
      controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Could not play this video: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: Colors.black, child: _surface()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.lesson.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.video.location,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: LmsColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close player',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 19),
                  color: LmsColors.textGrey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _surface() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ),
      );
    }
    if (_youtube != null) {
      return YoutubePlayer(controller: _youtube!, aspectRatio: 16 / 9);
    }
    if (_initializing || _file == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _file!.value.aspectRatio,
            child: VideoPlayer(_file!),
          ),
        ),
        VideoProgressIndicator(_file!, allowScrubbing: true),
        Center(
          child: IconButton(
            iconSize: 46,
            icon: Icon(
              _file!.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: Colors.white70,
            ),
            onPressed: () => setState(
              () => _file!.value.isPlaying ? _file!.pause() : _file!.play(),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoRow extends StatelessWidget {
  final _VideoLesson video;
  final bool isPlaying;
  final VoidCallback onTap;

  const _VideoRow({
    required this.video,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPlaying ? LmsColors.primarySoft : LmsColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying ? LmsColors.primary : LmsColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C6FFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    size: 19,
                    color: const Color(0xFF4C6FFF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.lesson.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.location,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: LmsColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: LmsColors.textGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Notice({
    required this.icon,
    required this.text,
    this.color = LmsColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
