import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/lesson_detail_model.dart';
import '../../provider/lesson_upload_provider.dart';
import 'lesson_videos_sheet.dart';

/// One video of a lesson, on a screen of its own.
///
/// The lesson page is a library - titles, stills and who can watch what. This
/// is where a part is actually watched, and where the two things an admin
/// does while watching live: changing its access, and editing the list.
class LessonVideoPlayerScreen extends StatefulWidget {
  final int lessonId;
  final int chapterId;
  final String lessonTitle;
  final List<LessonVideo> videos;
  final int initialIndex;
  final bool coursePremium;

  const LessonVideoPlayerScreen({
    super.key,
    required this.lessonId,
    required this.chapterId,
    required this.lessonTitle,
    required this.videos,
    required this.initialIndex,
    this.coursePremium = false,
  });

  @override
  State<LessonVideoPlayerScreen> createState() =>
      _LessonVideoPlayerScreenState();
}

class _LessonVideoPlayerScreenState extends State<LessonVideoPlayerScreen> {
  late List<LessonVideo> _videos = [...widget.videos];
  late int _index = widget.initialIndex;

  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  Timer? _youtubeTimeout;
  bool _youtubeReady = false;
  bool _youtubeTimedOut = false;
  bool _isInitializing = false;
  String? _videoError;

  bool _savingAccess = false;

  /// True when anything was saved here, so the lesson page knows to reload.
  bool _changed = false;

  LessonVideo get _video => _videos[_index];

  @override
  void initState() {
    super.initState();
    _open(_index);
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  void _teardown() {
    _youtubeTimeout?.cancel();
    _videoController?.dispose();
    _videoController = null;
    _youtubeController?.close();
    _youtubeController = null;
    _youtubeReady = false;
    _youtubeTimedOut = false;
    _videoError = null;
  }

  bool _isYoutube(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  /// Tears the old player down before building the next one - two players on
  /// one screen would both be holding the sound.
  Future<void> _open(int index) async {
    _teardown();
    setState(() {
      _index = index;
      _isInitializing = false;
    });

    final url = _videos[index].videoUrl.trim();
    if (url.isEmpty) return;

    if (_isYoutube(url)) {
      final videoId = YoutubePlayerController.convertUrlToId(url);
      if (videoId == null) {
        setState(() => _videoError = 'That is not a link YouTube recognises.');
        return;
      }
      setState(() {
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
          _youtubeTimeout?.cancel();
        }
      });
      _youtubeTimeout = Timer(const Duration(seconds: 20), () {
        if (!mounted || _youtubeReady) return;
        setState(() => _youtubeTimedOut = true);
      });
      return;
    }

    setState(() => _isInitializing = true);
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _videoController = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoError = 'That video could not be loaded.';
        _isInitializing = false;
      });
    }
  }

  /// Flips this part between free and premium and saves it at once.
  ///
  /// The list is replace-all, so every row goes up with everything it holds.
  Future<void> _toggleAccess() async {
    final makingFree = !_video.isFree;

    if (makingFree) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Make this video free?'),
          content: Text(
            '${_title(_index)} will play for everyone, including students '
            'without a subscription.',
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Make it free')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _savingAccess = true);

    final payload = [
      for (var i = 0; i < _videos.length; i++)
        {
          ..._videos[i].toJson(),
          'accessType': i == _index
              ? (makingFree ? 'free' : 'premium')
              : _videos[i].accessType,
        }
    ];

    final provider = LessonUpdateProvider();
    final ok = await provider.updateLesson(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
      videos: payload,
    );

    if (!mounted) return;
    setState(() => _savingAccess = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: LmsColors.error,
          content: Text(provider.errorMessage ?? 'That did not save'),
        ),
      );
      return;
    }

    setState(() {
      _changed = true;
      _videos[_index] = LessonVideo(
        id: _video.id,
        title: _video.title,
        videoUrl: _video.videoUrl,
        videoPublicId: _video.videoPublicId,
        thumbnailUrl: _video.thumbnailUrl,
        description: _video.description,
        durationSeconds: _video.durationSeconds,
        displayOrder: _video.displayOrder,
        accessType: makingFree ? 'free' : 'premium',
      );
    });
  }

  Future<void> _edit() async {
    final saved = await showLessonVideosSheet(
      context,
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
      lessonTitle: widget.lessonTitle,
      initialVideos: _videos,
      coursePremium: widget.coursePremium,
    );
    if (saved != true || !mounted) return;
    // The list may have changed under this screen - order, titles, even the
    // part being watched. The lesson page reloads it properly.
    setState(() => _changed = true);
    Navigator.pop(context, true);
  }

  String _title(int index) {
    final title = (_videos[index].title ?? '').trim();
    return title.isEmpty ? 'Part ${index + 1}' : title;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: LmsColors.textDark,
          title: Text('Part ${_index + 1}',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit videos',
              onPressed: _edit,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _player(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.lessonTitle,
                        style: const TextStyle(
                            fontSize: 12.5, color: LmsColors.textGrey)),
                    const SizedBox(height: 4),
                    Text(_title(_index),
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1.25)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _accessControl(),
                        if (_video.lengthLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(_video.lengthLabel!,
                              style: const TextStyle(
                                  fontSize: 12, color: LmsColors.textGrey)),
                        ],
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            final uri = Uri.tryParse(_video.videoUrl.trim());
                            if (uri != null) {
                              launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Open',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    if ((_video.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_video.description!.trim(),
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: LmsColors.textDark)),
                    ],
                    if (_videos.length > 1) ...[
                      const SizedBox(height: 22),
                      const Text('Other parts',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _videos.length; i++)
                        if (i != _index) _otherPart(i),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _player() {
    Widget inner;

    if (_videoError != null) {
      inner = Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_videoError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      );
    } else if (_youtubeController != null) {
      inner = Stack(
        fit: StackFit.expand,
        children: [
          YoutubePlayer(controller: _youtubeController!),
          if (!_youtubeReady && !_youtubeTimedOut)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      );
    } else if (_videoController != null) {
      inner = Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_videoController!),
          IconButton(
            iconSize: 54,
            icon: Icon(
              _videoController!.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            }),
          ),
        ],
      );
    } else {
      inner = Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: _isInitializing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.videocam_off_outlined,
                color: Colors.white54, size: 34),
      );
    }

    return AspectRatio(aspectRatio: 16 / 9, child: inner);
  }

  /// The access control, which is also the badge.
  Widget _accessControl() {
    final free = _video.isFree;
    final colour = free ? const Color(0xFF14A38B) : const Color(0xFFB7791F);

    return Tooltip(
      message: free ? 'Tap to make it premium' : 'Tap to make it free',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _savingAccess ? null : _toggleAccess,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: colour.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colour.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_savingAccess)
                SizedBox(
                  width: 13,
                  height: 13,
                  child:
                      CircularProgressIndicator(strokeWidth: 1.8, color: colour),
                )
              else
                Icon(
                    free
                        ? Icons.lock_open_rounded
                        : Icons.workspace_premium_rounded,
                    size: 14,
                    color: colour),
              const SizedBox(width: 5),
              Text(free ? 'Free' : 'Premium',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colour)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otherPart(int index) {
    final video = _videos[index];
    final still = (video.thumbnailUrl ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(index),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 38,
                child: still.isEmpty
                    ? Container(
                        color: LmsColors.bg,
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 18, color: LmsColors.textGrey))
                    : Image.network(still,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                        errorBuilder: (_, _, _) =>
                            Container(color: LmsColors.bg)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title(index),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(
                    '${video.isFree ? 'Free' : 'Premium'}'
                    '${video.lengthLabel == null ? '' : ' · ${video.lengthLabel}'}',
                    style: const TextStyle(
                        fontSize: 11, color: LmsColors.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
