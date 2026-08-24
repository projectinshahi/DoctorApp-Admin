import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';

/// Sweeps a highlight across whatever it wraps, so grey placeholder blocks read
/// as "loading" rather than as broken empty boxes.
///
/// Deliberately not a package: this is one animated gradient, and a dependency
/// for it would be more code to keep current than the effect itself.
///
/// Honours the platform's "reduce motion" setting - the sweep stops and the
/// placeholders render flat, which still communicates loading without motion.
class LmsShimmer extends StatefulWidget {
  final Widget child;

  const LmsShimmer({super.key, required this.child});

  @override
  State<LmsShimmer> createState() => _LmsShimmerState();
}

class _LmsShimmerState extends State<LmsShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // -1 .. 2 rather than 0 .. 1 so the band travels fully off both edges
        // instead of appearing to bounce at the ends.
        final t = _controller.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(t - 0.6, 0),
            end: Alignment(t + 0.6, 0),
            colors: const [
              Color(0x00FFFFFF),
              Color(0x99FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// One grey block standing in for a line of text or a chip.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({super.key, this.width, this.height = 12, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: LmsColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A card-shaped placeholder: title line, subtitle line, then a row of chips.
/// Matches the rough proportions of the list rows it stands in for, so the
/// layout doesn't jump when the real content arrives.
class ShimmerListSkeleton extends StatelessWidget {
  final int rowCount;
  final EdgeInsetsGeometry padding;

  const ShimmerListSkeleton({
    super.key,
    this.rowCount = 4,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return LmsShimmer(
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(rowCount, (index) {
            // Varying the title width keeps the block from reading as a table.
            final titleFraction = [0.82, 0.64, 0.74, 0.58][index % 4];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LmsColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LmsColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => ShimmerBox(
                      width: constraints.maxWidth * titleFraction,
                      height: 13,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const ShimmerBox(width: 160, height: 10),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      ShimmerBox(width: 68, height: 18, radius: 9),
                      SizedBox(width: 6),
                      ShimmerBox(width: 52, height: 18, radius: 9),
                      SizedBox(width: 6),
                      ShimmerBox(width: 84, height: 18, radius: 9),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Full-page placeholder for the lesson detail screen.
///
/// Shaped like the real page - media block, title, chips, then two content
/// sections - so the layout doesn't jump when the lesson lands. A centred
/// spinner gives no such hint, which is the whole reason for the swap.
class LessonDetailSkeleton extends StatelessWidget {
  const LessonDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LmsShimmer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App bar row: back arrow, title, edit action.
              Row(
                children: [
                  const ShimmerBox(width: 24, height: 24, radius: 12),
                  const SizedBox(width: 14),
                  const ShimmerBox(width: 92, height: 15),
                  const Spacer(),
                  const ShimmerBox(width: 24, height: 24, radius: 12),
                ],
              ),
              const SizedBox(height: 18),

              // Media block - 16:9, the tallest thing on the page.
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: LmsColors.border,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              LayoutBuilder(
                builder: (context, constraints) => ShimmerBox(
                  width: constraints.maxWidth * 0.62,
                  height: 18,
                ),
              ),
              const SizedBox(height: 10),
              const ShimmerBox(width: 220, height: 11),
              const SizedBox(height: 16),

              const Row(
                children: [
                  ShimmerBox(width: 70, height: 22, radius: 11),
                  SizedBox(width: 8),
                  ShimmerBox(width: 96, height: 22, radius: 11),
                  SizedBox(width: 8),
                  ShimmerBox(width: 78, height: 22, radius: 11),
                ],
              ),
              const SizedBox(height: 26),

              const ShimmerBox(width: 150, height: 14),
              const SizedBox(height: 12),
              const ShimmerListSkeleton(rowCount: 2, padding: EdgeInsets.zero),
              const SizedBox(height: 14),
              const ShimmerBox(width: 120, height: 14),
              const SizedBox(height: 12),
              const ShimmerListSkeleton(rowCount: 1, padding: EdgeInsets.zero),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for a row of stat tiles: icon square, big number, label.
class ShimmerStatTiles extends StatelessWidget {
  final int count;
  final int columns;

  const ShimmerStatTiles({super.key, this.count = 4, this.columns = 4});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final cols = columns.clamp(1, count);
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return LmsShimmer(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: List.generate(count, (_) {
              return SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LmsColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LmsColors.border),
                  ),
                  child: Row(
                    children: [
                      const ShimmerBox(width: 42, height: 42, radius: 12),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            ShimmerBox(width: 48, height: 20),
                            SizedBox(height: 7),
                            ShimmerBox(width: 90, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Placeholder for a grid of course cards: 16:7 image band, title, pills.
///
/// Sized by the same min-width rule the real grid uses, so the cards don't
/// reflow the instant the data lands.
class ShimmerCardGrid extends StatelessWidget {
  final int count;
  final double minCardWidth;

  const ShimmerCardGrid({super.key, this.count = 4, this.minCardWidth = 280});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columns =
            (constraints.maxWidth / (minCardWidth + gap)).floor().clamp(1, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return LmsShimmer(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: List.generate(count, (index) {
              // Varying the title width stops the block reading as a table.
              final titleFraction = [0.86, 0.62, 0.74, 0.55][index % 4];
              return SizedBox(
                width: width,
                child: Container(
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
                        aspectRatio: 16 / 7,
                        child: Container(color: LmsColors.border),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, inner) => ShimmerBox(
                                width: inner.maxWidth * titleFraction,
                                height: 13,
                              ),
                            ),
                            const SizedBox(height: 11),
                            const Row(
                              children: [
                                ShimmerBox(width: 66, height: 17, radius: 7),
                                SizedBox(width: 6),
                                ShimmerBox(width: 54, height: 17, radius: 7),
                              ],
                            ),
                            const SizedBox(height: 11),
                            const ShimmerBox(width: 130, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
