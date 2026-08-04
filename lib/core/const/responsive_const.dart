import 'package:flutter/material.dart';

/// ── Responsive breakpoints for the admin web app ────────────────
/// mobile:  < 600   (phones)
/// tablet:  600–1024 (tablets, small laptops, narrow browser windows)
/// desktop: >= 1024  (regular desktop/browser width)
class LmsBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

class LmsResponsive {
  static double widthOf(BuildContext context) => MediaQuery.of(context).size.width;

  static bool isMobile(BuildContext context) =>
      widthOf(context) < LmsBreakpoints.mobile;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= LmsBreakpoints.mobile && w < LmsBreakpoints.tablet;
  }

  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= LmsBreakpoints.tablet;

  /// Picks a value based on the current breakpoint. `tablet` falls back
  /// to `desktop` if not supplied, so callers only need mobile/desktop
  /// for most cases.
  static T value<T>(
      BuildContext context, {
        required T mobile,
        T? tablet,
        required T desktop,
      }) {
    final w = widthOf(context);
    if (w >= LmsBreakpoints.tablet) return desktop;
    if (w >= LmsBreakpoints.mobile) return tablet ?? desktop;
    return mobile;
  }

  /// Scales a base font size slightly down on very small phone widths so
  /// long labels/headings don't wrap awkwardly. Keeps desktop untouched.
  static double font(BuildContext context, double base) {
    final w = widthOf(context);
    if (w < 360) return base * 0.9;
    return base;
  }
}

/// Centers content and caps its width on large screens, while letting it
/// use the full width (minus side padding) on mobile — the same role
/// `ResponsiveCenter` plays in the mobile app's `app_responsive.dart`.
class LmsResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const LmsResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}