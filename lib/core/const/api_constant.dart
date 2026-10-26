/// Where the panel talks to.
///
/// Read at compile time, not runtime: a Flutter web build is static files, so
/// there is nothing to read a .env from once it is deployed. The value is
/// baked in by `--dart-define-from-file=env.json` (local) or
/// `--dart-define=API_ROOT=...` (CI), and falls back to production when
/// neither is given - a build with no flags must still point somewhere real
/// rather than at an empty string.
class ApiConstant {
  static const String root = String.fromEnvironment(
    'API_ROOT',
    defaultValue: 'https://doctorapp-backend-cl2h.onrender.com',
  );

  static const String baseUrl = '$root/api';
  static const String adminlogn = '$baseUrl/auth/admin/login';
}
