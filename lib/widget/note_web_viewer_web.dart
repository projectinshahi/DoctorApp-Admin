import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

bool get isOfficeViewerSupported => true;

final Set<String> _registeredViewTypes = {};

/// Embeds a DOC/DOCX file inline using Microsoft's Office Online viewer,
/// via a raw HTML iframe. Only works on Flutter web.
Widget buildInlineOfficeViewer(String url, String viewType) {
  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
      final iframe = html.IFrameElement()
        ..src = 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(url)}'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
    _registeredViewTypes.add(viewType);
  }
  return HtmlElementView(viewType: viewType);
}