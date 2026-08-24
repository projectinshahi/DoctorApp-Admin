import 'package:admin_drapp/Screen/Dashbord/student_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../provider/admin_student_provider.dart';
import '../QuestionBank/question_bank_screen.dart';
import '../../provider/course_get_provider.dart';
import 'course_list_screen.dart';
import 'dashboard_overview.dart';
import 'coming_soon_view.dart';
import 'lesson_video_screen.dart';
import 'subscription_plans_screen.dart';

// ── Simple data models ──────────────────────────────────────────────

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
      NavItem(Icons.assignment_outlined, "Quizzes"),
    ]),
    NavSection("people", [
      NavItem(Icons.people_outline_rounded, "Students"),
      NavItem(Icons.chat_bubble_outline_rounded, "Comments"),
    ]),
    NavSection("business", [
      NavItem(Icons.credit_card_outlined, "Subscriptions"),
    ]),
  ];

  void _selectNav(String label) {
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
                    child: _TopBar(title: _selected),
                  ),
                if (_selected == "Question Bank")
                  const Expanded(child: QuestionBankScreen())
                else
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
      case "Subscriptions":
        return ChangeNotifierProvider(
          create: (_) => CourseListGetProvider(),
          child: const SubscriptionPlansScreen(),
        );
      case "Question Bank":
        return const ComingSoonView(
          title: 'Question Bank',
          icon: Icons.help_outline_rounded,
          description:
              'Browsing, creating and editing questions is being rebuilt and '
              'will land here.',
          insteadHint:
              'Quiz lessons still pick their questions in the lesson sheet, '
              'under Courses.',
        );
      case "Quizzes":
        return const ComingSoonView(
          title: 'Quizzes',
          icon: Icons.assignment_outlined,
          description:
              'The quiz health report - orphaned, underfilled and healthy '
              'quizzes - is being rebuilt and will land here.',
          insteadHint:
              'A lesson\'s quiz and its questions are on the lesson detail '
              'screen today.',
        );
      case "Comments":
        return const ComingSoonView(
          title: 'Comments',
          icon: Icons.chat_bubble_outline_rounded,
          description: 'Student comments and moderation will land here.',
        );
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

  const _Sidebar({
    required this.selected,
    required this.sections,
    required this.onSelect,
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

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
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
                Icon(
                  item.icon,
                  size: 19,
                  color: isSelected ? LmsColors.primary : LmsColors.textGrey,
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
  final String title;
  const _TopBar({required this.title});

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
        CircleAvatar(
          radius: 20,
          backgroundColor: LmsColors.border,
          child: const Text(
            "AD",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: LmsColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stat cards row (unchanged) ────────────────────────────────────
