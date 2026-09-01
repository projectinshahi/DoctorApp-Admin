import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/theam/theam_dart.dart';

/// Plays a lesson video from its URL.
///
/// YouTube links go through the iframe player and everything else through
/// video_player - the two cannot share a controller, and a lesson's videoUrl
/// can be either.
class LessonPlayer extends StatefulWidget {
  final String url;

  const LessonPlayer({super.key, required this.url});

  @override
  State<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends State<LessonPlayer> {
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
  void didUpdateWidget(LessonPlayer old) {
    super.didUpdateWidget(old);
    // A different video means a different controller - reusing the old one
    // would keep playing the previous lesson behind the new title.
    if (old.url != widget.url) {
      _file?.dispose();
      _youtube?.close();
      _file = null;
      _youtube = null;
      _error = null;
      _open();
    }
  }

  @override
  void dispose() {
    _file?.dispose();
    _youtube?.close();
    super.dispose();
  }

  Future<void> _open() async {
    final url = widget.url.trim();
    if (url.isEmpty) {
      setState(() => _error = 'This lesson has no video URL.');
      return;
    }

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
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: Colors.black, child: _surface()),
      );

  Widget _surface() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  color: Colors.white54, size: 28),
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ],
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

/// A thin banner for a lesson that is marked as a video but has no URL.
class NoVideoNotice extends StatelessWidget {
  const NoVideoNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LmsColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LmsColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.videocam_off_outlined,
                size: 18, color: LmsColors.textGrey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This lesson has no video uploaded — only the comments below.',
                style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
              ),
            ),
          ],
        ),
      );
}
