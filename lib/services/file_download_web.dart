import 'dart:html' as html;

/// Saves [text] as [filename] through a click on an anchor nobody sees.
///
/// A blob rather than a `data:` URI: a long CSV in a URI hits the browser's
/// address-length limit, and the file arrives truncated with no error.
void downloadTextFile(String filename, String text) {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob(<Object>[text], 'text/csv;charset=utf-8'),
  );
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
