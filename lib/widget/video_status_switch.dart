import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';

/// Draft or published, for one video.
///
/// The lesson's status comes first: a draft lesson drafts every video in it,
/// server-side, so while [lockedByLesson] the switch shows Draft and refuses
/// to move rather than sending a change the server would overrule.
///
/// Lives here because three places set it - the lesson form, the Add video
/// sheet and the detail screen's playlist.
class VideoStatusSwitch extends StatelessWidget {
  final bool published;
  final ValueChanged<bool> onChanged;

  /// The lesson is a draft (or archived), so nothing in it is published.
  final bool lockedByLesson;

  final bool enabled;

  const VideoStatusSwitch({
    super.key,
    required this.published,
    required this.onChanged,
    this.lockedByLesson = false,
    this.enabled = true,
  });

  /// What a new row starts as: whatever the lesson is.
  static bool defaultPublished({required bool lessonPublished}) =>
      lessonPublished;

  @override
  Widget build(BuildContext context) {
    final live = published && !lockedByLesson;
    return Row(
      children: [
        _chip(isPublished: true, live: live),
        const SizedBox(width: 6),
        _chip(isPublished: false, live: live),
      ],
    );
  }

  Widget _chip({required bool isPublished, required bool live}) {
    final on = live == isPublished;
    final colour = isPublished ? LmsColors.success : LmsColors.textGrey;
    final canTap = enabled && !lockedByLesson;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: canTap ? () => onChanged(isPublished) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? colour : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? colour : LmsColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPublished
                  ? Icons.visibility_outlined
                  : Icons.edit_note_rounded,
              size: 12,
              color: on ? Colors.white : LmsColors.textGrey,
            ),
            const SizedBox(width: 4),
            Text(
              isPublished ? 'Published' : 'Draft',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : LmsColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
