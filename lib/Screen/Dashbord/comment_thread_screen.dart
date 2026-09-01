import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_comment_model.dart';
import '../../services/admin_comment_service.dart';
import '../../services/lesson_detail_service.dart';
import '../../widget/lesson_player.dart';
import '../../widget/shimmer_loading.dart';

/// One conversation, under the video it happened on.
///
/// The video sits at the top and the thread nests beneath it, the way a
/// comment section reads anywhere else: the question, then the answers
/// indented under it.
///
/// The row that was opened is highlighted from `focusCommentId` - arriving at
/// a thread and having to hunt for the reply you came from would defeat the
/// point of opening it.
class CommentThreadScreen extends StatefulWidget {
  /// Any comment in the thread. The server returns the whole tree either way.
  final AdminComment comment;

  const CommentThreadScreen({super.key, required this.comment});

  @override
  State<CommentThreadScreen> createState() => _CommentThreadScreenState();
}

class _CommentThreadScreenState extends State<CommentThreadScreen> {
  final _service = AdminCommentService();
  final _lessonService = LessonDetailsService();
  final _replyController = TextEditingController();

  CommentThread? _thread;
  String? _videoUrl;
  bool _videoFetched = false;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  /// Which comment the reply box is attached to. Null means it is closed.
  int? _replyingToId;

  /// True once anything was hidden, deleted or replied to, so the feed behind
  /// knows to reload.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadVideo();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.getThread(widget.comment.id);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _thread = result.thread;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _loadVideo() async {
    final lesson = widget.comment.lesson;
    if (lesson == null) {
      setState(() => _videoFetched = true);
      return;
    }

    final result = await _lessonService.getLesson(lessonId: lesson.id);
    if (!mounted) return;
    setState(() {
      _videoFetched = true;
      // A failed fetch and a lesson with no video are the same outcome - there
      // is nothing to play, and the notice says so either way.
      _videoUrl = result.isSuccess ? result.lesson?.videoUrl : null;
    });
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? LmsColors.error : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────

  Future<void> _toggleHidden(AdminComment comment) async {
    final result = await _service.setStatus(
        comment.id, comment.isHidden ? 'published' : 'hidden');
    if (!mounted) return;

    if (result.isSuccess) {
      _changed = true;
      await _load();
      if (!mounted) return;
      _toast(result.count > 0
          ? '${result.message} (${result.count} '
              'repl${result.count == 1 ? 'y' : 'ies'} moved too)'
          : result.message);
    } else {
      _toast(result.message, isError: true);
    }
  }

  Future<void> _dismiss(AdminComment comment) async {
    final result = await _service.dismissReports(comment.id);
    if (!mounted) return;

    if (result.isSuccess) {
      _changed = true;
      await _load();
      if (!mounted) return;
      _toast(result.message);
    } else {
      _toast(result.message, isError: true);
    }
  }

  Future<void> _confirmDelete(AdminComment comment) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this comment permanently?'),
        content: Text(
          comment.replyCount > 0
              ? 'This also deletes ${comment.replyCount} '
                  'repl${comment.replyCount == 1 ? 'y' : 'ies'} written by '
                  'other students. There is no undo and no archive.\n\n'
                  'Hiding removes it from students just as well, and can be '
                  'reversed.'
              : 'There is no undo and no archive.\n\n'
                  'Hiding removes it from students just as well, and can be '
                  'reversed.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete permanently'),
          ),
          if (!comment.isHidden)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'hide'),
              style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
              child: const Text('Hide instead'),
            ),
        ],
      ),
    );

    if (choice == null || !mounted) return;
    if (choice == 'hide') return _toggleHidden(comment);

    final result = await _service.delete(comment.id);
    if (!mounted) return;

    if (result.isSuccess) {
      _changed = true;
      _toast(result.message);
      // The thread root is gone, so there is nothing left to show.
      if (comment.id == _thread?.root?.id) {
        Navigator.pop(context, true);
      } else {
        await _load();
      }
    } else {
      _toast(result.message, isError: true);
    }
  }

  Future<void> _send(AdminComment parent) async {
    setState(() => _isSending = true);
    final result = await _service.reply(parent.id, _replyController.text);
    if (!mounted) return;

    setState(() => _isSending = false);

    if (result.isSuccess) {
      _changed = true;
      setState(() {
        _replyingToId = null;
        _replyController.clear();
      });
      await _load();
      if (!mounted) return;
      _toast(result.message);
    } else {
      // The draft stays in the box: a rejected reply should not also cost the
      // admin what they wrote.
      _toast(result.message, isError: true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lesson = widget.comment.lesson;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: LmsColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          foregroundColor: LmsColors.textDark,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(lesson?.title ?? 'Thread',
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
              if (lesson != null && lesson.whereLabel.isNotEmpty)
                Text(lesson.whereLabel,
                    style: const TextStyle(
                        fontSize: 11.5, color: LmsColors.textGrey),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Reload',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _videoCard(),
                  const SizedBox(height: 26),
                  _threadBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoCard() {
    final lesson = widget.comment.lesson;

    return Center(
      child: ConstrainedBox(
        // Narrower than the thread on purpose. The video is context, not the
        // subject - a full-width player pushes the conversation off the fold,
        // which is what the reader actually came for.
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: LmsColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_videoFetched)
                const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LmsShimmer(
                      child: ShimmerBox(
                          width: double.infinity, height: 260, radius: 0)),
                )
              else if ((_videoUrl ?? '').trim().isEmpty)
                const Padding(
                    padding: EdgeInsets.all(14), child: NoVideoNotice())
              else
                LessonPlayer(url: _videoUrl!),

              if (lesson != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lesson.whereLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          lesson.whereLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: LmsColors.textGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _threadBody() {
    if (_isLoading) {
      return const ShimmerListSkeleton(rowCount: 3, padding: EdgeInsets.zero);
    }

    if (_error != null) {
      return _Notice(
        icon: Icons.error_outline_rounded,
        color: LmsColors.error,
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }

    final root = _thread?.root;
    if (root == null) {
      return const _Notice(
        icon: Icons.forum_outlined,
        text: 'This thread could not be loaded.',
      );
    }

    final focus = _thread?.focusCommentId ?? widget.comment.id;
    final replies = root.replies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          replies.isEmpty
              ? 'CONVERSATION'
              : 'CONVERSATION · ${replies.length + 1}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: LmsColors.textGrey,
          ),
        ),
        const SizedBox(height: 12),

        _node(root, focus, depth: 0),

        // One level of nesting, which is all the model allows: every reply
        // hangs off the root, so a reply to a reply is still a sibling here.
        for (final reply in replies) _node(reply, focus, depth: 1),
      ],
    );
  }

  Widget _node(AdminComment comment, int focus, {required int depth}) {
    final isFocus = comment.id == focus;
    final author = comment.user;
    final instructor = comment.isInstructor || (author?.isAdmin ?? false);
    final openReports = comment.openReports;
    final isReplying = _replyingToId == comment.id;

    return Container(
      margin: EdgeInsets.only(bottom: 12, left: depth * 26.0),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocus
              ? LmsColors.primary
              : comment.needsReview
                  ? LmsColors.error.withValues(alpha: 0.4)
                  : LmsColors.border,
          width: isFocus ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            // The focused row lifts a little further, so the eye lands on it
            // without needing a second colour to say so.
            color: Colors.black.withValues(alpha: isFocus ? 0.07 : 0.03),
            blurRadius: isFocus ? 16 : 8,
            offset: Offset(0, isFocus ? 5 : 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depth > 0)
            Container(
              height: 3,
              color: instructor
                  ? LmsColors.primary
                  : LmsColors.border,
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: instructor
                            ? LmsColors.primary
                            : LmsColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(author?.initial ?? '?',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: instructor
                                  ? Colors.white
                                  : LmsColors.primary)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 7,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(author?.displayName ?? 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              if (instructor)
                                const _Tag('INSTRUCTOR', LmsColors.primary),
                              if (comment.isHidden)
                                const _Tag('HIDDEN', LmsColors.textGrey),
                              if (comment.needsReview)
                                _Tag(
                                    '${comment.openReportCount} REPORT'
                                    '${comment.openReportCount == 1 ? '' : 'S'}',
                                    LmsColors.error),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (comment.createdAt != null)
                                _ago(comment.createdAt!),
                              if (comment.isEdited) 'edited',
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 11, color: LmsColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  comment.body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: comment.isHidden
                        ? LmsColors.textGrey
                        : LmsColors.textDark,
                    fontStyle:
                        comment.isHidden ? FontStyle.italic : FontStyle.normal,
                  ),
                ),

                if (openReports.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: LmsColors.errorBg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: LmsColors.errorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final report in openReports)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '"${report.reason}"'
                              '${report.user == null ? '' : ' — ${report.user!.displayName}'}',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: LmsColors.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: LmsColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Wrap(
              spacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (comment.canReply)
                  _Action('Reply', Icons.reply_rounded,
                      () => setState(() {
                            _replyingToId = isReplying ? null : comment.id;
                            _replyController.clear();
                          }),
                      primary: true)
                else
                  const Tooltip(
                    message: 'Restore it first — a visible reply under a '
                        'hidden comment reads as a reply to nothing.',
                    child: _Action('Reply', Icons.reply_rounded, null,
                        primary: true),
                  ),
                _Action(
                  comment.isHidden ? 'Restore' : 'Hide',
                  comment.isHidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  () => _toggleHidden(comment),
                ),
                if (comment.openReportCount > 0)
                  _Action('Dismiss', Icons.done_all_rounded,
                      () => _dismiss(comment)),
                _Action('Delete', Icons.delete_outline_rounded,
                    () => _confirmDelete(comment),
                    danger: true),
              ],
            ),
          ),

          if (isReplying)
            Container(
              color: LmsColors.bg,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _replyController,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Reply to ${author?.displayName ?? 'this student'}…',
                      hintStyle: const TextStyle(
                          fontSize: 12.5, color: LmsColors.textGrey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: LmsColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: LmsColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Students will see this under their comment.',
                          style: TextStyle(
                              fontSize: 11, color: LmsColors.textGrey),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSending
                            ? null
                            : () => setState(() => _replyingToId = null),
                        child:
                            const Text('Cancel', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: _isSending ? null : () => _send(comment),
                        style: FilledButton.styleFrom(
                          backgroundColor: LmsColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Send reply',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _ago(DateTime value) {
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    final months = diff.inDays ~/ 30;
    return months < 12 ? '${months}mo ago' : '${months ~/ 12}y ago';
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;
  final bool primary;

  const _Action(
    this.label,
    this.icon,
    this.onPressed, {
    this.danger = false,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: danger
              ? LmsColors.error
              : primary
                  ? LmsColors.primary
                  : LmsColors.textGrey,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w600)),
      );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, color: color)),
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.text,
    this.color = LmsColors.primary,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style:
                      TextStyle(fontSize: 12.5, height: 1.35, color: color)),
            ),
            if (action != null) action!,
          ],
        ),
      );
}
