import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';

/// Placeholder for a nav destination that isn't built yet.
///
/// Exists because the router's `default` case used to catch these and quietly
/// render the dashboard - so clicking "Quizzes" looked like the app had
/// ignored you. Saying "not yet" is a better answer than showing the wrong
/// screen.
class ComingSoonView extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  /// What the admin can do in the meantime, if anything.
  final String? insteadHint;

  const ComingSoonView({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.insteadHint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 34, 30, 30),
          decoration: BoxDecoration(
            color: LmsColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: LmsColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      LmsColors.primary.withValues(alpha: 0.16),
                      LmsColors.primary.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 30, color: LmsColors.primary),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LmsColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'COMING SOON',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: LmsColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: LmsColors.textGrey,
                ),
              ),
              if (insteadHint != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LmsColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LmsColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          size: 16, color: LmsColors.textGrey),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          insteadHint!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: LmsColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
