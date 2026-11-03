import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';

/// Free or premium, for one video.
///
/// The video's own setting decides what a student without a subscription can
/// play - a free part inside a premium lesson, or a premium course, is the
/// sample. The lesson's own access covers only its quiz, notes and text.
///
/// Lives here because two forms set it - the Add video sheet and the lesson
/// form's video list - and a switch that drifts between them is a switch that
/// means two things.
class VideoAccessSwitch extends StatelessWidget {
  final bool free;

  /// On a premium course a free video is the sample students see before
  /// paying, which is worth naming.
  final bool coursePremium;

  final ValueChanged<bool> onChanged;
  final bool enabled;

  const VideoAccessSwitch({
    super.key,
    required this.free,
    required this.onChanged,
    this.coursePremium = false,
    this.enabled = true,
  });

  /// What a new row starts as: premium on a paid course, free on a free one.
  static bool defaultFree({required bool coursePremium}) => !coursePremium;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(isFree: true),
        const SizedBox(width: 6),
        _chip(isFree: false),
      ],
    );
  }

  Widget _chip({required bool isFree}) {
    final on = free == isFree;
    final colour = isFree ? const Color(0xFF14A38B) : LmsColors.primary;
    final label = isFree
        ? (coursePremium ? 'Free sample' : 'Free')
        : 'Premium';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? () => onChanged(isFree) : null,
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
              isFree
                  ? Icons.lock_open_rounded
                  : Icons.workspace_premium_rounded,
              size: 12,
              color: on ? Colors.white : LmsColors.textGrey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
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
