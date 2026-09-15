import 'package:admin_drapp/Screen/Dashbord/student_list_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../provider/admin_student_provider.dart';
import '../QuestionBank/course_quiz_screen.dart';
import '../../provider/course_get_provider.dart';
import 'course_list_screen.dart';
import 'dashboard_overview.dart';
import '../RapidRecall/rapid_recall_list_screen.dart';
import 'comment_moderation_screen.dart';
import 'lesson_video_screen.dart';
import 'plans_screen.dart';
import '../Test/test_list_screen.dart';
import '../Login/Login_screen.dart';
import '../../core/const/local_storegae.dart';
import '../../services/admin_account_service.dart';
import '../../services/admin_comment_service.dart';
import 'admin_settings_screen.dart';

// ── Simple data models ──────────────────────────────────────────────

/// A sidebar entry. [badgeOf] returns the red-dot count for this item, read
/// from the dashboard's state so a nav item can carry live news.
class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class NavSection {
  final String title;
  final List<NavItem> items;
  const NavSection(this.title, this.items);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selected = "Dashboard";

  static const List<NavSection> _sections = [
    NavSection("overview", [NavItem(Icons.grid_view_rounded, "Dashboard")]),
    NavSection("content", [
      NavItem(Icons.menu_book_outlined, "Courses"),
      NavItem(Icons.videocam_outlined, "Videos"),
      NavItem(Icons.help_outline_rounded, "Question Bank"),
      NavItem(Icons.style_outlined, "Rapid Recall"),
      NavItem(Icons.fact_check_outlined, "Tests"),
    ]),
    NavSection("people", [
      NavItem(Icons.people_outline_rounded, "Students"),
      NavItem(Icons.chat_bubble_outline_rounded, "Comments"),
    ]),
    NavSection("business", [
      NavItem(Icons.sell_outlined, "Plans"),
    ]),
  ];

  /// New or reported comments the moderator has not seen. Drives the red dot.
  int _reportedComments = 0;
  Timer? _badgeTimer;

  Future<void> _refreshBadge() async {
    final count = await AdminCommentService().unseenCount();
    if (!mounted || count == null) return;
    if (count != _reportedComments) {
      setState(() => _reportedComments = count);
    }
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshBadge();
    // Slow on purpose: a moderation queue is not a chat, and a tighter poll
    // would cost a request a minute for a number that rarely moves.
    _badgeTimer =
        Timer.periodic(const Duration(minutes: 2), (_) => _refreshBadge());
    // Checked at boot so a dead session sends the admin to login before they
    // lose work in a half-filled form. Only 401/403 end the session - a
    // network failure must not.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await AdminAccountService().getMe();
      if (mounted && result.mustReauthenticate) {
        _endSession(reason: result.errorMessage);
      }
    });
  }

  /// Clears the stored token and returns to login.
  void _endSession({String? reason}) async {
    await AdminLocalStorage.clearAdminData();
    if (!mounted) return;

    if (reason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: LmsColors.error),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _onAccountAction(String action) async {
    if (action == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              foregroundColor: LmsColors.textDark,
              title: const Text('Settings',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: AdminSettingsScreen(onSessionEnded: _endSession),
            ),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text(
          'You will need your email and password to sign back in.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) _endSession();
  }

  void _selectNav(String label) {
    // Leaving Comments usually means something was just acted on.
    if (_selected == "Comments" && label != "Comments") _refreshBadge();
    setState(() => _selected = label);
    if (LmsResponsive.isMobile(context) && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = LmsResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: isMobile
          ? AppBar(
              backgroundColor: LmsColors.surface,
              elevation: 0,
              foregroundColor: LmsColors.textDark,
              title: Text(
                _selected,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: LmsColors.textDark,
                ),
              ),
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: _Sidebar(
                selected: _selected,
                sections: _sections,
                onSelect: _selectNav,
                badges: {"Comments": _reportedComments},
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            _Sidebar(
              selected: _selected,
              sections: _sections,
              onSelect: _selectNav,
              badges: {"Comments": _reportedComments},
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Full-width header: title stays pinned to the left
                // edge next to the sidebar, independent of the content's
                // max-width centering below. This is what fixes the
                // "title looks centered on wide screens" issue.
                if (!isMobile)
                  Container(
                    width: double.infinity,
                    color: LmsColors.bg,
                    padding: EdgeInsets.symmetric(
                      horizontal: LmsResponsive.value(
                        context,
                        mobile: 16,
                        tablet: 24,
                        desktop: 32,
                      ),
                      vertical: 20,
                    ),
                    child: _TopBar(
                      title: _selected,
                      onAccountAction: _onAccountAction,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        LmsResponsive.value(
                          context,
                          mobile: 16,
                          tablet: 24,
                          desktop: 32,
                        ),
                        isMobile ? 20 : 0,
                        LmsResponsive.value(
                          context,
                          mobile: 16,
                          tablet: 24,
                          desktop: 32,
                        ),
                        40,
                      ),
                      child: LmsResponsiveCenter(
                        maxWidth: 1100,
                        child: _buildMainContent(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selected) {
      case "Courses":
        return const CourseListScreen();
      case "Videos":
        return ChangeNotifierProvider(
          create: (_) => CourseListGetProvider(),
          child: const LessonVideoScreen(),
        );
      case "Rapid Recall":
        return const RapidRecallListScreen();
      case "Plans":
        return ChangeNotifierProvider(
          create: (_) => CourseListGetProvider(),
          child: const PlansScreen(),
        );
      case "Tests":
        return ChangeNotifierProvider(
          create: (_) => CourseListGetProvider(),
          child: const TestListScreen(),
        );
      case "Question Bank":
        return ChangeNotifierProvider(
          create: (_) => CourseListGetProvider(),
          child: const CourseQuizScreen(),
        );
      case "Comments":
        return const CommentModerationScreen();
      case "Students":
        return ChangeNotifierProvider(
          create: (_) => AdminStudentProvider(),
          child: const AdminStudentListScreen(),
        );
      case "Dashboard":
      default:
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CourseListGetProvider()),
            ChangeNotifierProvider(create: (_) => AdminStudentProvider()),
          ],
          child: const DashboardOverview(),
        );
    }
  }
}

// ── Sidebar (unchanged) ─────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final String selected;
  final List<NavSection> sections;
  final ValueChanged<String> onSelect;

  /// Red-dot counts by nav label. Absent or zero means no dot.
  final Map<String, int> badges;

  const _Sidebar({
    required this.selected,
    required this.sections,
    required this.onSelect,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: LmsColors.surface,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: LmsColors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "dr.skm's academy",
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: LmsColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              for (final section in sections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 0, 8),
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: LmsColors.textGrey,
                    ),
                  ),
                ),
                for (final item in section.items)
                  _NavTile(
                    item: item,
                    isSelected: item.label == selected,
                    badge: badges[item.label] ?? 0,
                    onTap: () => onSelect(item.label),
                  ),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  /// Zero draws nothing - an empty queue should look empty, not like a zero
  /// someone still has to read.
  final int badge;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? LmsColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // The dot sits on the icon, the way an unread badge does -
                // it is news about the section, not part of its name.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      size: 19,
                      color:
                          isSelected ? LmsColors.primary : LmsColors.textGrey,
                    ),
                    if (badge > 0)
                      Positioned(
                        right: -7,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: LmsColors.error,
                            borderRadius: BorderRadius.circular(9),
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? LmsColors.primary : LmsColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top bar: title left, avatar right — pinned full-width above the
// centered content, so it never visually drifts to the middle. ──────
class _TopBar extends StatelessWidget {
  final ValueChanged<String> onAccountAction;
  final String title;
  const _TopBar({required this.title, required this.onAccountAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: LmsResponsive.value<double>(
                context,
                mobile: 24,
                tablet: 28,
                desktop: 32,
              ),
              fontWeight: FontWeight.w800,
              color: LmsColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Settings and Log out live on the avatar rather than in the nav.
        // Neither is a section of the app to browse - they are things you do
        // to your own account, which is what this control already represents.
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          onSelected: onAccountAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,
                      size: 17, color: LmsColors.textGrey),
                  SizedBox(width: 10),
                  Text('Account settings', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 17, color: LmsColors.error),
                  SizedBox(width: 10),
                  Text('Log out',
                      style:
                          TextStyle(fontSize: 13, color: LmsColors.error)),
                ],
              ),
            ),
          ],
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: LmsColors.border,
            child: Text(
              "AD",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LmsColors.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stat cards row (unchanged) ────────────────────────────────────
