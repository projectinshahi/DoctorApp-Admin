import 'package:flutter/material.dart';

import '../core/format/view_count.dart';
import '../core/theam/theam_dart.dart';

/// The pieces a video row needs in both forms - the Add video sheet and the
/// lesson form's video list - so the two cannot drift apart.

/// Past this many characters the app's two lines run out. Not a hard limit:
/// a long title is allowed, it is just warned about.
const int kVideoTitleSoftLimit = 60;

/// The warning under a video title, or null while it still fits.
String? videoTitleWarning(String title) =>
    title.trim().characters.length > kVideoTitleSoftLimit
        ? 'Students see 2 lines.'
        : null;

/// The warning under a video link the admin has just changed.
///
/// The server keeps a video's identity only while its link is unchanged, so
/// a new link means a new video: views back to zero, bookmarks gone. Worth
/// saying only when there is something to lose.
String? videoLinkChangeWarning({
  required String? savedUrl,
  required String currentUrl,
  required int viewCount,
}) {
  if (savedUrl == null || savedUrl.trim().isEmpty) return null;
  if (viewCount <= 0) return null;
  if (currentUrl.trim() == savedUrl.trim()) return null;
  return 'Changing the link makes this a new video: its '
      '${formatViewCount(viewCount)} views and students\' bookmarks start '
      'again.';
}

/// A line of small print under a field - the title's counter, the link's
/// warning.
class VideoFieldNote extends StatelessWidget {
  final String text;
  final bool warning;

  const VideoFieldNote(this.text, {super.key, this.warning = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warning) ...[
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: Color(0xFFB4690E)),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: warning ? FontWeight.w700 : FontWeight.w500,
                  color: warning
                      ? const Color(0xFFB4690E)
                      : LmsColors.textGrey,
                ),
              ),
            ),
          ],
        ),
      );
}

/// A video's thumbnail: the 16:9 still students see before they press play,
/// with the upload that fills it and the link it resolves to.
///
/// The preview is the point - a row with no thumbnail looks empty here the
/// way it looks empty in the app.
class VideoThumbnailField extends StatelessWidget {
  /// Holds the `thumbnailUrl` that gets saved; typing a link works too.
  final TextEditingController controller;

  final bool uploading;
  final bool enabled;
  final VoidCallback onUpload;

  /// Rebuild the preview as the link changes.
  final VoidCallback onChanged;

  final InputDecoration Function(String hint) decoration;

  const VideoThumbnailField({
    super.key,
    required this.controller,
    required this.uploading,
    required this.enabled,
    required this.onUpload,
    required this.onChanged,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final url = controller.text.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 136,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: url.isEmpty ? LmsColors.border : LmsColors.primary),
              ),
              clipBehavior: Clip.antiAlias,
              child: uploading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : url.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_outlined,
                                  size: 20, color: LmsColors.textGrey),
                              SizedBox(height: 3),
                              Text('No thumbnail',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: LmsColors.textGrey)),
                            ],
                          ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          // Through an <img> element, so a host with no CORS
                          // headers still shows the picture.
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined,
                                size: 18, color: LmsColors.textGrey),
                          ),
                        ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 34,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: enabled && !uploading ? onUpload : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      size: 16),
                  label: Text(
                    url.isEmpty ? 'Upload thumbnail' : 'Replace thumbnail',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LmsColors.primary,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: LmsColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                enabled: enabled,
                onChanged: (_) => onChanged(),
                style: const TextStyle(fontSize: 12),
                decoration: decoration('or paste a thumbnail link'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
