class ApiConstant {
  /// The deployed backend. Also the default, so a plain `flutter run` keeps
  /// pointing at production.
  static const String _production = 'https://doctorapp-backend-30gd.onrender.com';

  /// Server root, no path.
  ///
  /// Override at launch to hit a local backend instead:
  ///
  ///   flutter run -d chrome --dart-define=API_ROOT=http://localhost:3000
  ///
  /// It's a compile-time constant, so it can still be used as a default
  /// constructor argument in every service - and switching it needs a
  /// restart, not a hot reload.
  static const String root = String.fromEnvironment(
    'API_ROOT',
    defaultValue: _production,
  );

  /// Root + '/api'. Services that build paths like '/courses/:id' use this.
  static const String baseUrl = '$root/api';

  static const String adminlogn = '$baseUrl/auth/admin/login';

  /// False whenever a non-production root was passed in. Drives the banner
  /// that stops you filing a bug against data that came from your laptop.
  static bool get isProduction => root == _production;

  /// Short label for that banner, e.g. "localhost:3000".
  static String get environmentLabel {
    if (isProduction) return 'Render';
    final uri = Uri.tryParse(root);
    if (uri == null) return root;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }
}
