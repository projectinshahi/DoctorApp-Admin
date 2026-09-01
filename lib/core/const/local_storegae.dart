import 'package:shared_preferences/shared_preferences.dart';

class AdminLocalStorage {
  static const String _tokenKey = 'admin_access_token';
  static const String _adminIdKey = 'admin_id';
  static const String _adminEmailKey = 'admin_email';
  static const String _adminNameKey = 'admin_name';
  static const String _adminRoleKey = 'admin_role';

  /// When the moderator last opened the comments screen. Anything newer than
  /// this is "new" and drives the sidebar badge.
  static const String _commentsSeenKey = 'comments_last_seen_at';

  // Save admin token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Get admin token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Save admin profile info
  static Future<void> saveAdminInfo({
    required int id,
    required String email,
    String? name,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_adminIdKey, id);
    await prefs.setString(_adminEmailKey, email);
    if (name != null) await prefs.setString(_adminNameKey, name);
    await prefs.setString(_adminRoleKey, role);
  }

  // Get admin ID
  static Future<int?> getAdminId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_adminIdKey);
  }

  // Get admin email
  static Future<String?> getAdminEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminEmailKey);
  }

  // Get admin name
  static Future<String?> getAdminName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminNameKey);
  }

  // Get admin role
  static Future<String?> getAdminRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminRoleKey);
  }

  // Check if admin is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> markCommentsSeen(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_commentsSeenKey, at.toUtc().toIso8601String());
  }

  static Future<DateTime?> getCommentsSeenAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_commentsSeenKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  // Clear all admin data (logout)
  static Future<void> clearAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_adminIdKey);
    await prefs.remove(_adminEmailKey);
    await prefs.remove(_adminNameKey);
    await prefs.remove(_adminRoleKey);
    await prefs.remove(_commentsSeenKey);
  }
}