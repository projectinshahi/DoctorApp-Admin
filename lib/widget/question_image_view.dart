import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theam/theam_dart.dart';

/// Renders a question or option image from its hosted URL.
///
/// **Why this is not a plain Image.network.**
///
/// On the web Flutter draws into a canvas, so it must *fetch the bytes* of an
/// image - and a cross-origin fetch needs the image host to send
/// `Access-Control-Allow-Origin`. Most image hosts do not. The result was a
/// red box printing the URL back at the admin: the file was fine, the browser
/// simply refused to hand its pixels to the canvas.
///
/// [WebHtmlElementStrategy.prefer] renders through a real `<img>` element
/// instead, which the browser loads cross-origin without any CORS header at
/// all. Flutter documents this as the answer for "images hosted on a CDN or
/// from arbitrary URLs", which is exactly this case.
///
/// **SVG rides the same path, and is safer for it.** An `<img>` renders SVG
/// natively, and every browser disables script inside an SVG loaded that way -
/// a stronger guarantee than the old one, which rested on the file being
/// served from another origin. flutter_svg is kept only for non-web builds,
/// where `<img>` does not exist and CORS does not apply.
///
/// Never inline SVG source into the page. That defeats both guarantees.
class QuestionImageView extends StatelessWidget {
  final String url;
  final double maxHeight;

  const QuestionImageView({
    super.key,
    required this.url,
    this.maxHeight = 200,
  });

  /// Decided by the URL's extension, not by any `format` field: the question
  /// row stores only the URL, so the extension is all that travels with it.
  static bool isSvg(String url) =>
      (Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase())
          .endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 460),
          child: isSvg(trimmed) && !kIsWeb
              ? SvgPicture.network(
                  trimmed,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => _loading(),
                )
              : Image.network(
                  trimmed,
                  fit: BoxFit.contain,
                  // Bypasses the same-origin policy - see the class comment.
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : _loading(),
                  errorBuilder: (_, _, _) => _unavailable(),
                ),
        ),
      ),
    );
  }

  Widget _loading() => SizedBox(
        height: maxHeight * 0.5,
        width: 140,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  /// Deliberately quiet, and it does NOT print the URL.
  ///
  /// The old red banner shouted a full Cloudinary path across the row for
  /// something the admin usually cannot act on from here. A missing figure
  /// still has to be visible - a silently absent image reads as a question
  /// that never had one - so it leaves a mark, not an alarm.
  Widget _unavailable() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: LmsColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LmsColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 15, color: LmsColors.textGrey),
            SizedBox(width: 7),
            Text('Image unavailable',
                style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey)),
          ],
        ),
      );
}
