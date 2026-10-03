/// Hands the browser a file to save.
///
/// Conditional because `dart:html` only exists on the web, which is where the
/// panel runs; the stub keeps the other platforms compiling.
library;

export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
