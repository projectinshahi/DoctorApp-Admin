import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_comment_model.dart';
import '../../core/const/local_storegae.dart';
import '../../services/admin_comment_service.dart';
import '../../services/lesson_detail_service.dart';
import '../../widget/lesson_player.dart';
import '../../widget/shimmer_loading.dart';
import 'comment_thread_screen.dart';

/// One video and the comments left on it - a post.
class _Post {
  final int lessonId;
  final String title;
  final String where;
  final bool commentsEnabled;

  /// Root comments only, each carrying its replies.
  final List<_Node> comments;

  const _Post({
    required this.lessonId,
    required this.title,
    required this.where,
    required this.commentsEnabled,
    required this.comments,
  });

  int get total => comments.fold(0, (sum, n) => sum + 1 + n.replies.length);

  int get reported => comments
      .expand((n) => [n.comment, ...n.replies])
      .where((c) => c.needsReview)
      .length;

  /// When this discussion last moved.
  DateTime? get latest {
    DateTime? newest;
    for (final c in comments.expand((n) => [n.comment, ...n.replies])) {
      final at = c.createdAt;
      if (at == null) continue;
      if (newest == null || at.isAfter(newest)) newest = at;
    }
    return newest;
  }
}

/// A root comment with the replies that hang off it.
class _Node {
  final AdminComment comment;
  final List<AdminComment> replies;

  const _Node(this.comment, this.replies);
}

/// Comment moderation, as a feed of posts.
///
/// Each video is a post: the media on top, then its comments beneath it in
/// one compact run. Moderation controls stay hidden until a comment is tapped,
/// so a page of discussions reads as a conversation rather than as a control
/// panel with text in it.
class CommentModerationScreen extends StatefulWidget {
  const CommentModerationScreen({super.key});

  @override
  State<CommentModerationScreen> createState() =>
      _CommentModerationScreenState();
}

class _CommentModerationScreenState extends State<CommentModerationScreen> {
  final _service = AdminCommentService();
  final _lessonService = LessonDetailsService();
  final _replyController = TextEditingController();

  List<AdminComment> _comments = const [];
  CommentCounts _counts = const CommentCounts();

  /// Video URL per lesson. Null once fetched means the lesson has no video.
  final Map<int, String?> _videoUrls = {};

  /// Posts showing every comment rather than the first few.
  final Set<int> _expandedPosts = {};

  /// The comment whose moderation row is open, and the one being replied to.
  int? _actionsForId;
  int? _replyingToId;
  bool _isSendingReply = false;

  bool _isLoading = false;
  String? _error;

  /// How many comments a post shows before "View all".
  static const _previewCount = 3;

  @override
  void initState() {
    super.initState();
    _load();
    // Opening the screen is what "seen" means, so the badge clears on the way
    // in rather than on the way out.
    AdminLocalStorage.markCommentsSeen(DateTime.now());
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

    final result = await _service.list(status: 'all', limit: 50);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _counts = result.counts;
        _comments = result.comments.toList()
          ..sort((a, b) {
            final left = a.createdAt, right = b.createdAt;
            if (left == null && right == null) return 0;
            if (left == null) return 1;
            if (right == null) return -1;
            return right.compareTo(left);
          });
      } else {
        _error = result.errorMessage;
      }
    });

    if (result.isSuccess) _loadVideos();
  }

  /// Fetches each post's video once.
  ///
  /// One call per distinct video, not per comment, and only for videos not
  /// already known - a post's media is part of the post, so it loads with the
  /// feed rather than behind a tap.
  Future<void> _loadVideos() async {
    final ids = _posts.map((p) => p.lessonId).toSet()
      ..removeWhere(_videoUrls.containsKey);

    for (final id in ids) {
      final result = await _lessonService.getLesson(lessonId: id);
      if (!mounted) return;
      setState(() {
        // A failed fetch and a lesson with no video are the same outcome -
        // there is nothing to play, and the card says so either way.
        _videoUrls[id] = result.isSuccess ? result.lesson?.videoUrl : null;
      });
    }
  }

  /// Comments folded into their videos.
  ///
  /// Grouped here from the single feed read: a request per video would turn a
  /// page of ten discussions into eleven round trips.
  List<_Post> get _posts {
    final byLesson = <int, List<AdminComment>>{};
    final meta = <int, CommentLesson>{};

    for (final comment in _comments) {
      final lesson = comment.lesson;
      if (lesson == null) continue;
      meta[lesson.id] = lesson;
      byLesson.putIfAbsent(lesson.id, () => []).add(comment);
    }

    final posts = <_Post>[];

    for (final entry in byLesson.entries) {
      // The feed already contains the replies - they are comments with a
      // parentId - so the tree is built here rather than fetched per thread.
      // A request per comment would be dozens of round trips for data that
      // already arrived.
      final all = entry.value;
      final roots = all.where((c) => !c.isReply).toList();
      final repliesByParent = <int, List<AdminComment>>{};
      for (final c in all.where((c) => c.isReply)) {
        repliesByParent.putIfAbsent(c.parentId ?? -1, () => []).add(c);
      }

      final nodes = [
        for (final root in roots)
          _Node(
            root,
            // Oldest reply first: a conversation reads down, even though the
            // roots themselves are newest-first.
            (repliesByParent[root.id] ?? const <AdminComment>[]).toList()
              ..sort((a, b) {
                final left = a.createdAt, right = b.createdAt;
                if (left == null || right == null) return 0;
                return left.compareTo(right);
              }),
          ),
      ];

      // A reply whose parent is outside this page would otherwise vanish.
      final orphans = repliesByParent.entries
          .where((e) => !roots.any((r) => r.id == e.key))
          .expand((e) => e.value)
          .map((c) => _Node(c, const <AdminComment>[]));

      posts.add(
        _Post(
          lessonId: entry.key,
          title: meta[entry.key]!.title,
          where: meta[entry.key]!.whereLabel,
          commentsEnabled: meta[entry.key]!.commentsEnabled,
          comments: [...nodes, ...orphans],
        ),
      );
    }

    // Anything needing review first - that is what the screen is for - then
    // whichever discussion moved most recently.
    posts.sort((a, b) {
      if ((a.reported > 0) != (b.reported > 0)) return a.reported > 0 ? -1 : 1;
      final left = a.latest, right = b.latest;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });

    return posts;
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
      comment.id,
      comment.isHidden ? 'published' : 'hidden',
    );
    if (!mounted) return;

    if (result.isSuccess) {
      await _load();
      if (!mounted) return;
      // affectedReplies named outright: hiding one row and silently moving
      // three replies with it is the surprise to avoid.
      _toast(
        result.count > 0
            ? '${result.message} (${result.count} '
                  'repl${result.count == 1 ? 'y' : 'ies'} moved too)'
            : result.message,
      );
    } else {
      _toast(result.message, isError: true);
    }
  }

  Future<void> _dismiss(AdminComment comment) async {
    final result = await _service.dismissReports(comment.id);
    if (!mounted) return;

    if (result.isSuccess) {
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
      await _load();
      if (!mounted) return;
      _toast(result.message);
    } else {
      _toast(result.message, isError: true);
    }
  }

  Future<void> _sendReply(AdminComment parent) async {
    setState(() => _isSendingReply = true);
    final result = await _service.reply(parent.id, _replyController.text);
    if (!mounted) return;

    setState(() => _isSendingReply = false);

    if (result.isSuccess) {
      setState(() {
        _replyingToId = null;
        _replyController.clear();
        // Show the thread it landed in.
        _expandedPosts.add(parent.lesson?.id ?? -1);
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

  Future<void> _toggleComments(_Post post) async {
    final turningOff = post.commentsEnabled;

    if (turningOff) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Turn comments off for "${post.title}"?'),
          content: Text(
            'Students will not be able to post new comments.\n\n'
            'The ${post.comments.length} comment'
            '${post.comments.length == 1 ? '' : 's'} already here stay '
            'visible — turning the discussion off does not erase it.',
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
              child: const Text('Turn off'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await _service.setLessonComments(
      lessonId: post.lessonId,
      enabled: !turningOff,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      await _load();
      if (!mounted) return;
      _toast(
        result.existingComments > 0
            ? '${result.message} ${result.existingComments} existing '
                  'comment${result.existingComments == 1 ? '' : 's'} stay visible.'
            : result.message,
      );
    } else {
      _toast(result.errorMessage ?? 'That did not work', isError: true);
    }
  }

  Future<void> _openThread(AdminComment comment) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CommentThreadScreen(comment: comment)),
    );
    if (changed == true) await _load();
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          // Wide enough for a nested reply to still have room to read after
          // its indent, without a comment running edge to edge.
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _counts.reported == 0
                              ? 'Nothing is waiting on you.'
                              : '${_counts.reported} reported and still '
                                    'visible to students.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _counts.reported == 0
                                ? LmsColors.textGrey
                                : LmsColors.error,
                            fontWeight: _counts.reported == 0
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Reload',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_isLoading)
                const ShimmerListSkeleton(rowCount: 3, padding: EdgeInsets.zero)
              else if (_error != null)
                _Notice(
                  icon: Icons.error_outline_rounded,
                  color: LmsColors.error,
                  text: _error!,
                  action: TextButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              else if (_posts.isEmpty)
                const _Notice(
                  icon: Icons.chat_bubble_outline_rounded,
                  text: 'No student has commented yet.',
                )
              else
                for (final post in _posts)
                  _PostCard(
                    post: post,
                    videoUrl: _videoUrls[post.lessonId],
                    videoFetched: _videoUrls.containsKey(post.lessonId),
                    isExpanded: _expandedPosts.contains(post.lessonId),
                    previewCount: _previewCount,
                    actionsForId: _actionsForId,
                    replyingToId: _replyingToId,
                    replyController: _replyController,
                    isSendingReply: _isSendingReply,
                    onExpand: () =>
                        setState(() => _expandedPosts.add(post.lessonId)),
                    onToggleComments: () => _toggleComments(post),
                    onTapComment: (c) => setState(
                      () => _actionsForId = _actionsForId == c.id ? null : c.id,
                    ),
                    onReply: (c) => setState(() {
                      _replyingToId = _replyingToId == c.id ? null : c.id;
                      _replyController.clear();
                    }),
                    onSendReply: _sendReply,
                    onToggleHidden: _toggleHidden,
                    onDismiss: _dismiss,
                    onDelete: _confirmDelete,
                    onOpenThread: _openThread,
                  ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

/// One post: the video, then its comments.
class _PostCard extends StatelessWidget {
  final _Post post;
  final String? videoUrl;
  final bool videoFetched;
  final bool isExpanded;
  final int previewCount;
  final int? actionsForId;
  final int? replyingToId;
  final TextEditingController replyController;
  final bool isSendingReply;

  final VoidCallback onExpand;
  final VoidCallback onToggleComments;
  final ValueChanged<AdminComment> onTapComment;
  final ValueChanged<AdminComment> onReply;
  final ValueChanged<AdminComment> onSendReply;
  final ValueChanged<AdminComment> onToggleHidden;
  final ValueChanged<AdminComment> onDismiss;
  final ValueChanged<AdminComment> onDelete;
  final ValueChanged<AdminComment> onOpenThread;

  const _PostCard({
    required this.post,
    required this.videoUrl,
    required this.videoFetched,
    required this.isExpanded,
    required this.previewCount,
    required this.actionsForId,
    required this.replyingToId,
    required this.replyController,
    required this.isSendingReply,
    required this.onExpand,
    required this.onToggleComments,
    required this.onTapComment,
    required this.onReply,
    required this.onSendReply,
    required this.onToggleHidden,
    required this.onDismiss,
    required this.onDelete,
    required this.onOpenThread,
  });

  static String _ago(DateTime value) {
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 365) return '${diff.inDays ~/ 7}w';
    return '${diff.inDays ~/ 365}y';
  }

  Widget _line(AdminComment comment, {required int depth}) => Padding(
    padding: EdgeInsets.only(left: depth * 26.0),
    child: _CommentLine(
      comment: comment,
      isReply: depth > 0,
      showActions: actionsForId == comment.id,
      isReplying: replyingToId == comment.id,
      replyController: replyController,
      isSendingReply: isSendingReply,
      ago: comment.createdAt == null ? null : _ago(comment.createdAt!),
      onTap: () => onTapComment(comment),
      onReply: () => onReply(comment),
      onSendReply: () => onSendReply(comment),
      onToggleHidden: () => onToggleHidden(comment),
      onDismiss: () => onDismiss(comment),
      onDelete: () => onDelete(comment),
      onOpenThread: () => onOpenThread(comment),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shown = isExpanded
        ? post.comments
        : post.comments.take(previewCount).toList();
    final hiddenCount = post.comments.length - shown.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: post.reported > 0
              ? LmsColors.error.withValues(alpha: 0.35)
              : LmsColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: which video this is ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: LmsColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 19,
                    color: LmsColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (post.where.isNotEmpty)
                        Text(
                          post.where,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: LmsColors.textGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!post.commentsEnabled)
                  const _Tag('OFF', LmsColors.textGrey),
                IconButton(
                  onPressed: onToggleComments,
                  tooltip: post.commentsEnabled
                      ? 'Turn comments off for this video'
                      : 'Turn comments on for this video',
                  icon: Icon(
                    post.commentsEnabled
                        ? Icons.comments_disabled_outlined
                        : Icons.mode_comment_outlined,
                    size: 18,
                  ),
                  color: LmsColors.textGrey,
                ),
              ],
            ),
          ),

          // ── The media ────────────────────────────────────────────
          if (!videoFetched)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: LmsShimmer(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 300,
                  radius: 0,
                ),
              ),
            )
          else if ((videoUrl ?? '').trim().isEmpty)
            const Padding(padding: EdgeInsets.all(13), child: NoVideoNotice())
          else
            LessonPlayer(url: videoUrl!),

          // ── The comments ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${post.total} comment'
                      '${post.total == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (post.reported > 0) ...[
                      const SizedBox(width: 8),
                      _Tag('${post.reported} NEED REVIEW', LmsColors.error),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                if (hiddenCount > 0) ...[
                  InkWell(
                    onTap: onExpand,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'View all ${post.total} comments',
                        style: const TextStyle(
                          fontSize: 12,
                          color: LmsColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                ],

                // The student's comment, then whoever answered it directly
                // underneath - the order the conversation happened in.
                for (final node in shown) ...[
                  _line(node.comment, depth: 0),
                  for (final reply in node.replies) _line(reply, depth: 1),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One comment, written the way a caption is: name then text, on one run.
///
/// The moderation row stays folded until the line is tapped - a page of
/// discussions should read as a conversation, not as a control panel.
class _CommentLine extends StatelessWidget {
  final AdminComment comment;

  /// Indented under a parent, so it gets a spine rather than repeating the
  /// "reply to #N" text a reader can already see from the layout.
  final bool isReply;

  final bool showActions;
  final bool isReplying;
  final TextEditingController replyController;
  final bool isSendingReply;
  final String? ago;

  final VoidCallback onTap;
  final VoidCallback onReply;
  final VoidCallback onSendReply;
  final VoidCallback onToggleHidden;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;
  final VoidCallback onOpenThread;

  const _CommentLine({
    required this.comment,
    required this.isReply,
    required this.showActions,
    required this.isReplying,
    required this.replyController,
    required this.isSendingReply,
    required this.ago,
    required this.onTap,
    required this.onReply,
    required this.onSendReply,
    required this.onToggleHidden,
    required this.onDismiss,
    required this.onDelete,
    required this.onOpenThread,
  });

  @override
  Widget build(BuildContext context) {
    final author = comment.user;
    final instructor = comment.isInstructor || (author?.isAdmin ?? false);

    return Container(
      padding: isReply ? const EdgeInsets.only(left: 10) : EdgeInsets.zero,
      decoration: isReply
          ? BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: instructor ? LmsColors.primary : LmsColors.border,
                  width: 2,
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: comment.isHidden
                              ? LmsColors.textGrey
                              : LmsColors.textDark,
                          fontStyle: comment.isHidden
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        children: [
                          TextSpan(
                            text: '${author?.displayName ?? 'Unknown'}  ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: instructor
                                  ? LmsColors.primary
                                  : LmsColors.textDark,
                            ),
                          ),
                          if (instructor)
                            const TextSpan(
                              text: '✓ ',
                              style: TextStyle(color: LmsColors.primary),
                            ),
                          TextSpan(text: comment.body),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (comment.needsReview)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: LmsColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // The quiet second line: age, Reply, reply count, and why it is
          // flagged. Reply lives here rather than behind the tap - answering a
          // student is the common act, and hiding it behind a gesture makes the
          // rare moderation actions look like the point of the screen.
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 2),
            child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (ago != null)
                  Text(
                    ago!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: LmsColors.textGrey,
                    ),
                  ),
                if (comment.canReply)
                  InkWell(
                    onTap: onReply,
                    child: Text(
                      isReplying ? 'Cancel' : 'Reply',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        // The one action a tutor takes constantly, so it is the
                        // only coloured word on the line.
                        color: isReplying ? LmsColors.error : LmsColors.primary,
                      ),
                    ),
                  )
                else
                  const Tooltip(
                    message:
                        'Restore it first — a visible reply under a hidden '
                        'comment reads as a reply to nothing.',
                    child: Text(
                      'Reply',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: LmsColors.border,
                      ),
                    ),
                  ),
                if (comment.replyCount > 0)
                  InkWell(
                    onTap: onOpenThread,
                    child: Text(
                      'View ${comment.replyCount} repl'
                      '${comment.replyCount == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.textGrey,
                      ),
                    ),
                  ),
                if (comment.isHidden)
                  const Text(
                    'hidden',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: LmsColors.textGrey,
                    ),
                  ),
                for (final report in comment.openReports)
                  Text(
                    'reported: ${report.reason}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: LmsColors.error,
                    ),
                  ),
                // The moderation actions need a visible way in - a row that
                // only appears on an undocumented tap is a row nobody finds.
                InkWell(
                  onTap: onTap,
                  child: Text(
                    showActions ? 'Less' : 'More',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (showActions)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Wrap(
                spacing: 2,
                children: [
                  _MiniAction(
                    comment.isHidden ? 'Restore' : 'Hide',
                    comment.isHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onToggleHidden,
                  ),
                  if (comment.openReportCount > 0)
                    _MiniAction('Dismiss', Icons.done_all_rounded, onDismiss),
                  _MiniAction(
                    'Thread',
                    Icons.open_in_new_rounded,
                    onOpenThread,
                  ),
                  _MiniAction(
                    'Delete',
                    Icons.delete_outline_rounded,
                    onDelete,
                    danger: true,
                  ),
                ],
              ),
            ),

          if (isReplying)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 10, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText:
                            'Reply to ${author?.displayName ?? 'this student'}…',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: LmsColors.textGrey,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: LmsColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: LmsColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: LmsColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: isSendingReply ? null : onSendReply,
                    style: TextButton.styleFrom(
                      foregroundColor: LmsColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    child: isSendingReply
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Post',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
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
}

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  const _MiniAction(
    this.label,
    this.icon,
    this.onPressed, {
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: danger ? LmsColors.error : LmsColors.textGrey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: Icon(icon, size: 13),
    label: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
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
    child: Text(
      label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
    ),
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
    padding: const EdgeInsets.all(16),
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
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, height: 1.35, color: color),
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}
