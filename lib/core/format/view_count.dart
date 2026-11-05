/// "950", "1.2k", "18.4k", "1.2M" - what a view count looks like beside a
/// video title. Callers decide to hide it at zero; this only formats.
String formatViewCount(int views) {
  if (views < 1000) return '$views';
  if (views < 1000000) return '${_short(views / 1000)}k';
  return '${_short(views / 1000000)}M';
}

/// One decimal, unless it would be ".0" - "18.4k", but "2k" not "2.0k".
String _short(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()}'
      : rounded.toStringAsFixed(1);
}
