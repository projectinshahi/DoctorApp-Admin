import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../services/lesson_services.dart';
import 'lesson_type_ui.dart';

/// One place for how a lesson's status, access, plan and media read across the
/// app, so the chapter list and the detail screen can't drift apart.
/// Same rule as [LessonTypeUI]: change the visuals here, nowhere else.

Color lessonStatusColor(String status) {
  switch (status) {
    case 'published':
      return LmsColors.success;
    case 'archived':
      return LmsColors.textGrey;
    default: // draft
      return LmsColors.primary;
  }
}

IconData lessonStatusIcon(String status) {
  switch (status) {
    case 'published':
      return Icons.check_circle_outline_rounded;
    case 'archived':
      return Icons.inventory_2_outlined;
    default: // draft
      return Icons.edit_note_rounded;
  }
}

const Color kPremiumColor = Color(0xFFB7791F); // amber.shade800
const Color kVideoColor = Color(0xFF4C6FFF);
const Color kMissingColor = Color(0xFFB7791F); // "typed video, nothing attached"

/// A single pill. [compact] is the size used inside dense list rows.
class LessonBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  const LessonBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10.5 : 13, color: color),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The full badge set for one lesson: type, status, access (+ which plan),
/// whether a video is attached, and the free-preview flag.
///
/// [planLabels] is resolved by the caller from the course's plan list - one
/// entry per plan that unlocks the lesson. Empty on a premium lesson reads
/// "Any subscription". [maxPlanBadges] keeps a dense list row from wrapping
/// into a wall of pills; the overflow collapses into a "+N" badge.
class LessonBadgeRow extends StatelessWidget {
  final String type;
  final String status;
  final String accessType;
  final bool isFreePreview;
  final List<String> planLabels;
  final int maxPlanBadges;
  /// null  -> API didn't say, so claim nothing
  /// true  -> a video is attached
  /// false -> no video, even if the lesson is typed 'video'
  final bool? hasVideo;
  final bool compact;

  /// Hide the type badge where the row already shows the type another way.
  final bool showType;

  const LessonBadgeRow({
    super.key,
    required this.type,
    required this.status,
    required this.accessType,
    required this.isFreePreview,
    this.planLabels = const [],
    this.maxPlanBadges = 2,
    this.hasVideo,
    this.compact = false,
    this.showType = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPremium = accessType == 'premium';
    final ui = LessonTypeUI.of(LessonTypeX.fromApiValue(type));

    // For video lessons the type badge doubles as the media indicator, so a
    // play icon is only ever shown when a video really is attached.
    final bool isVideoType = LessonTypeX.fromApiValue(type) == LessonType.video;
    final bool videoMissing = isVideoType && hasVideo == false;

    return Wrap(
      spacing: compact ? 5 : 8,
      runSpacing: compact ? 4 : 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showType)
          if (videoMissing)
            LessonBadge(
              icon: Icons.videocam_off_rounded,
              label: 'No video',
              color: kMissingColor,
              compact: compact,
            )
          else
            LessonBadge(
              icon: ui.icon,
              label: ui.label,
              // Grey until the API confirms a video exists - a blue play icon
              // on an empty lesson is what made the list misleading.
              color: isVideoType && hasVideo != true ? LmsColors.textGrey : ui.color,
              compact: compact,
            ),

        LessonBadge(
          icon: lessonStatusIcon(status),
          label: status.toUpperCase(),
          color: lessonStatusColor(status),
          compact: compact,
        ),

        LessonBadge(
          icon: isPremium ? Icons.workspace_premium_rounded : Icons.lock_open_rounded,
          label: isPremium ? 'Premium' : 'Free',
          color: isPremium ? kPremiumColor : LmsColors.success,
          compact: compact,
        ),

        // Which plans unlock it - only meaningful for premium lessons.
        if (isPremium)
          if (planLabels.isEmpty)
            LessonBadge(
              icon: Icons.card_membership_rounded,
              label: 'Any subscription',
              color: kPremiumColor,
              compact: compact,
            )
          else ...[
            ...planLabels.take(maxPlanBadges).map(
                  (label) => LessonBadge(
                    icon: Icons.card_membership_rounded,
                    label: label,
                    color: kPremiumColor,
                    compact: compact,
                  ),
                ),
            if (planLabels.length > maxPlanBadges)
              LessonBadge(
                icon: Icons.more_horiz_rounded,
                label: '+${planLabels.length - maxPlanBadges}',
                color: kPremiumColor,
                compact: compact,
              ),
          ],

        // A non-video lesson that still carries a video is worth flagging.
        if (hasVideo == true && !isVideoType)
          LessonBadge(
            icon: Icons.play_circle_outline_rounded,
            label: 'Video',
            color: kVideoColor,
            compact: compact,
          ),

        if (isFreePreview)
          LessonBadge(
            icon: Icons.visibility_outlined,
            label: 'Free preview',
            color: LmsColors.primary,
            compact: compact,
          ),
      ],
    );
  }
}
