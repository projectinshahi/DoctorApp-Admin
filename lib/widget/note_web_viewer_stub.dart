import 'package:flutter/material.dart';

/// Non-web platforms: inline Office viewing isn't available, so callers
/// should fall back to "Open externally" instead.
bool get isOfficeViewerSupported => false;

Widget buildInlineOfficeViewer(String url, String viewType) {
  return const SizedBox.shrink();
}