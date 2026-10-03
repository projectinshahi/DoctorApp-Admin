/// Saving a file is a browser action. Nothing outside the web build calls it.
void downloadTextFile(String filename, String text) =>
    throw UnsupportedError('Downloading a file only works in the browser');
