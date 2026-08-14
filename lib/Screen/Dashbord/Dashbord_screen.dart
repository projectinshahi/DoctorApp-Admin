import 'package:admin_drapp/Screen/Dashbord/student_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../provider/course_provider.dart';
import '../../provider/admin_student_provider.dart';
import 'add_course_screen.dart';
import 'course_list_screen.dart';

// ── Simple data models ──────────────────────────────────────────────
class StatCard {
  final String label;
  final String value;
  final String? delta;
  const StatCard({required this.label, required this.value, this.delta});
}

class QuizAttempt {
  final String title;
  final String attempts;
  const QuizAttempt({required this.title, required this.attempts});
}

class ModerationComment {
  final String author;
  final String snippet;
  const ModerationComment({required this.author, required this.snippet});
}

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

  final List<StatCard> _stats = const [
    StatCard(label: "Registered students", value: "18,204", delta: "+312 this week"),
    StatCard(label: "Active subscriptions", value: "6,540", delta: "+84 this week"),
    StatCard(label: "Courses / videos", value: "142 / 1,860"),
    StatCard(label: "Questions / quizzes", value: "4,920 / 316"),
  ];

  final List<QuizAttempt> _mostAttempted = const [
    QuizAttempt(title: "Algebra basics — chapter test", attempts: "2,140 attempts"),
    QuizAttempt(title: "Newton's laws quiz", attempts: "1,880 attempts"),
    QuizAttempt(title: "Cell biology — MCQ set 2", attempts: "1,502 attempts"),
    QuizAttempt(title: "English grammar — tenses", attempts: "1,190 attempts"),
  ];

  final List<ModerationComment> _comments = const [
    ModerationComment(author: "Riya S.", snippet: "This explanation doesn't match…"),
    ModerationComment(author: "Arjun K.", snippet: "reported, video: Ch 4 fractions"),
    ModerationComment(author: "Meera P.", snippet: "Can we get a part 2?"),
  ];

  static const List<NavSection> _sections = [
    NavSection("overview", [NavItem(Icons.grid_view_rounded, "Dashboard")]),
    NavSection("content", [
      NavItem(Icons.menu_book_outlined, "Courses"),
      NavItem(Icons.add_box_outlined, "Add course"),
      NavItem(Icons.videocam_outlined, "Videos"),
      NavItem(Icons.help_outline_rounded, "Question bank"),
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
          style: const TextStyle(fontWeight: FontWeight.w800, color: LmsColors.textDark),
        ),
      )
          : null,
      drawer: isMobile
          ? Drawer(child: _Sidebar(selected: _selected, sections: _sections, onSelect: _selectNav))
          : null,
      body: Row(
        children: [
          if (!isMobile) _Sidebar(selected: _selected, sections: _sections, onSelect: _selectNav),
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
                      horizontal: LmsResponsive.value(context, mobile: 16, tablet: 24, desktop: 32),
                      vertical: 20,
                    ),
                    child: _TopBar(title: _selected),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      LmsResponsive.value(context, mobile: 16, tablet: 24, desktop: 32),
                      isMobile ? 20 : 0,
                      LmsResponsive.value(context, mobile: 16, tablet: 24, desktop: 32),
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
      case "Add course":
        return ChangeNotifierProvider(
          create: (_) => CourseProvider(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CourseListAddForm(
              onCreated: () {
                setState(() => _selected = "Courses");
              },
            ),
          ),
        );
      case "Students":
        return ChangeNotifierProvider(
          create: (_) => AdminStudentProvider(),
          child: const AdminStudentListScreen(),
        );
      case "Dashboard":
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(stats: _stats),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 760;
            final quizzesCard = _MostAttemptedCard(items: _mostAttempted);
            final commentsCard = _ModerationCard(comments: _comments);

            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: quizzesCard),
                    const SizedBox(width: 20),
                    Expanded(child: commentsCard),
                  ],
                ),
              );
            }
            return Column(children: [quizzesCard, const SizedBox(height: 20), commentsCard]);
          },
        ),
      ],
    );
  }
}

// ── Sidebar (unchanged) ─────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final String selected;
  final List<NavSection> sections;
  final ValueChanged<String> onSelect;

  const _Sidebar({required this.selected, required this.sections, required this.onSelect});

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
                    decoration: BoxDecoration(color: LmsColors.primary, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "SAS LMS admin",
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: LmsColors.textDark),
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
                  _NavTile(item: item, isSelected: item.label == selected, onTap: () => onSelect(item.label)),
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

  const _NavTile({required this.item, required this.isSelected, required this.onTap});

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
                Icon(item.icon, size: 19, color: isSelected ? LmsColors.primary : LmsColors.textGrey),
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
              fontSize: LmsResponsive.value<double>(context, mobile: 24, tablet: 28, desktop: 32),
              fontWeight: FontWeight.w800,
              color: LmsColors.textDark,
            ),
          ),
        ),
        CircleAvatar(
          radius: 20,
          backgroundColor: LmsColors.border,
          child: const Text(
            "AD",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LmsColors.textDark),
          ),
        ),
      ],
    );
  }
}

// ── Stat cards row (unchanged) ────────────────────────────────────
class _StatRow extends StatelessWidget {
  final List<StatCard> stats;
  const _StatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width > 900 ? 4 : (width > 560 ? 2 : 1);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: stats.map((s) {
            final cardWidth = (width - (columns - 1) * 16) / columns;
            return SizedBox(width: cardWidth, child: _StatCardView(stat: s));
          }).toList(),
        );
      },
    );
  }
}

class _StatCardView extends StatelessWidget {
  final StatCard stat;
  const _StatCardView({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.label, style: const TextStyle(fontSize: 13.5, color: LmsColors.textGrey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Text(
            stat.value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: LmsColors.textDark, height: 1.1),
          ),
          if (stat.delta != null) ...[
            const SizedBox(height: 10),
            Text(stat.delta!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LmsColors.success)),
          ],
        ],
      ),
    );
  }
}

class _MostAttemptedCard extends StatelessWidget {
  final List<QuizAttempt> items;
  const _MostAttemptedCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Most-attempted quizzes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LmsColors.textDark)),
          const SizedBox(height: 16),
          for (int i = 0; i < items.length; i++) ...[
            _QuizRow(item: items[i]),
            if (i != items.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  final QuizAttempt item;
  const _QuizRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(item.title,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: LmsColors.textDark, height: 1.3)),
        ),
        const SizedBox(width: 12),
        Text(item.attempts,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, color: LmsColors.textGrey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ModerationCard extends StatelessWidget {
  final List<ModerationComment> comments;
  const _ModerationCard({required this.comments});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Comments awaiting review",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LmsColors.textDark)),
          const SizedBox(height: 16),
          for (int i = 0; i < comments.length; i++) ...[
            _CommentRow(comment: comments[i]),
            if (i != comments.length - 1) const SizedBox(height: 14),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: LmsColors.textDark,
                side: const BorderSide(color: LmsColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Go to moderation", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  final ModerationComment comment;
  const _CommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: LmsColors.textDark, height: 1.4),
        children: [
          TextSpan(text: "${comment.author} ", style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: "— \"${comment.snippet}\"", style: const TextStyle(fontWeight: FontWeight.w400, color: LmsColors.textDark)),
        ],
      ),
    );
  }
}