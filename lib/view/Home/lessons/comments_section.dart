// lib/view/Home/lessons/comments_section.dart
//
// The comment thread under a lesson.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/comment_model.dart';
import '../../../repository/comment_provider.dart';
import '../../../services/comment_service.dart';
import '../../../widget/app_loading.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

/// Drop-in section for the lesson screen. Owns its own provider so the
/// lesson screen does not have to know comments exist beyond placing it.
class CommentsSection extends StatelessWidget {
  final int lessonId;

  const CommentsSection({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CommentProvider>(
      create: (_) => CommentProvider()..load(lessonId),
      child: _CommentsView(lessonId: lessonId),
    );
  }
}

class _CommentsView extends StatefulWidget {
  final int lessonId;

  const _CommentsView({required this.lessonId});

  @override
  State<_CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends State<_CommentsView> {
  final TextEditingController _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _post(CommentProvider provider, {int? parentId}) async {
    final ok =
        await provider.post(widget.lessonId, _composer.text, parentId: parentId);
    if (ok) _composer.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommentProvider>();

    if (provider.isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: AppLoading(height: 120.h),
      );
    }

    final failure = provider.failure;
    if (failure != null) {
      return _Notice(
        // There is no anonymous read, so a signed-out student gets a prompt
        // rather than an empty thread.
        icon: failure.kind == CommentErrorKind.signedOut
            ? Icons.lock_outline_rounded
            : Icons.chat_bubble_outline_rounded,
        text: failure.message,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 18.sp, color: Colors.black87),
              SizedBox(width: 8.w),
              Text(
                // totalComments, not the thread count: replies are comments
                // too, and pagination.total would undercount them.
                provider.totalComments == 1
                    ? '1 comment'
                    : '${provider.totalComments} comments',
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // A moderator can switch posting off per lesson. The thread stays;
          // only the box goes.
          if (provider.commentsEnabled)
            _Composer(
              controller: _composer,
              hint: 'Add a comment…',
              busy: provider.isPosting,
              onSend: () => _post(provider),
            )
          else
            _Notice(
              icon: Icons.do_not_disturb_on_outlined,
              text: 'Commenting is turned off for this lesson.',
              compact: true,
            ),

          if (provider.actionError != null) ...[
            SizedBox(height: 10.h),
            Text(provider.actionError!,
                style: TextStyle(fontSize: 11.5.sp, color: Colors.red.shade700)),
          ],

          SizedBox(height: 16.h),

          if (provider.isEmpty)
            _Notice(
              icon: Icons.forum_outlined,
              text: provider.commentsEnabled
                  ? 'No comments yet. Be the first.'
                  : 'No comments on this lesson.',
            )
          else
            for (final thread in provider.comments) ...[
              _Thread(
                thread: thread,
                lessonId: widget.lessonId,
                composer: _composer,
              ),
              SizedBox(height: 18.h),
            ],

          if (provider.hasMore)
            Center(
              child: TextButton(
                onPressed: provider.isLoadingMore
                    ? null
                    : () => provider.loadMore(widget.lessonId),
                child: Text(
                    provider.isLoadingMore ? 'Loading…' : 'Load more comments',
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  final CommentModel thread;
  final int lessonId;
  final TextEditingController composer;

  const _Thread({
    required this.thread,
    required this.lessonId,
    required this.composer,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommentProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(comment: thread, lessonId: lessonId, composer: composer),

        // Replies, indented once. There is no second level to indent to.
        for (final reply in thread.replies)
          Padding(
            padding: EdgeInsets.only(left: 40.w, top: 12.h),
            child: _CommentRow(
              comment: reply,
              lessonId: lessonId,
              composer: composer,
              isReply: true,
            ),
          ),

        if (provider.replyingTo == thread.id ||
            thread.replies.any((r) => r.id == provider.replyingTo)) ...[
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.only(left: 40.w),
            child: _Composer(
              controller: composer,
              hint: 'Write a reply…',
              busy: provider.isPosting,
              onCancel: provider.cancelComposing,
              onSend: () async {
                // Whatever the student tapped Reply on — the server flattens
                // it and the response says where it landed.
                final ok = await provider.post(lessonId, composer.text,
                    parentId: provider.replyingTo);
                if (ok) composer.clear();
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  final CommentModel comment;
  final int lessonId;
  final TextEditingController composer;
  final bool isReply;

  const _CommentRow({
    required this.comment,
    required this.lessonId,
    required this.composer,
    this.isReply = false,
  });

  Future<void> _confirmDelete(
      BuildContext context, CommentProvider provider) async {
    final replies = comment.replyCount;

    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this comment?'),
        content: Text(
          replies == 0
              ? 'This cannot be undone.'
              // Other students wrote those, and they go too.
              : 'This will also delete $replies '
                  '${replies == 1 ? 'reply' : 'replies'} from other students. '
                  'This cannot be undone.',
          style: TextStyle(fontSize: 13.sp, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );

    if (go != true) return;
    await provider.delete(comment.id);
  }

  Future<void> _edit(BuildContext context, CommentProvider provider) async {
    final controller = TextEditingController(text: comment.body);

    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          maxLength: 2000,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save')),
        ],
      ),
    );

    if (body == null || !context.mounted) return;
    await provider.edit(comment.id, body);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommentProvider>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(author: comment.author, size: isReply ? 26 : 32),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(comment.author.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                  ),
                  SizedBox(width: 6.w),
                  Text(_relative(comment.createdAt),
                      style: TextStyle(
                          fontSize: 10.5.sp, color: Colors.grey.shade600)),
                  if (comment.edited) ...[
                    SizedBox(width: 5.w),
                    Text('· edited',
                        style: TextStyle(
                            fontSize: 10.5.sp, color: Colors.grey.shade500)),
                  ],
                ],
              ),
              SizedBox(height: 4.h),
              Text(comment.body,
                  style: TextStyle(
                      fontSize: 13.sp, height: 1.4, color: Colors.black87)),
              SizedBox(height: 6.h),
              Row(
                children: [
                  if (provider.commentsEnabled)
                    _Action(
                        label: 'Reply',
                        onTap: () => provider.startReply(comment.id)),
                  // isMine and reportedByMe come from the server, which has
                  // already worked out whose comment this is. Edit/Delete on
                  // your own, Report on everyone else's — never both.
                  if (comment.isMine) ...[
                    _Action(
                        label: 'Edit',
                        onTap: () => _edit(context, provider)),
                    _Action(
                        label: 'Delete',
                        danger: true,
                        onTap: () => _confirmDelete(context, provider)),
                  ] else
                    _Action(
                      label: comment.reportedByMe ? 'Reported' : 'Report',
                      // Already reported: nothing more to do, and the comment
                      // stays visible either way.
                      onTap: comment.reportedByMe
                          ? null
                          : () => provider.report(comment.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _relative(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _Avatar extends StatelessWidget {
  final CommentAuthor author;
  final double size;

  const _Avatar({required this.author, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = author.avatarUrl;

    return Container(
      width: size.w,
      height: size.w,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _kPrimary,
        shape: BoxShape.circle,
      ),
      // Both name and avatar are nullable, and the email is never sent — so
      // the fallback is an initial, not an address.
      child: url == null || url.isEmpty
          ? Text(author.initial,
              style: TextStyle(
                  fontSize: (size * 0.42).sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white))
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: size.w,
              height: size.w,
              errorBuilder: (context, _, __) => Text(author.initial,
                  style: TextStyle(
                      fontSize: (size * 0.42).sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback? onCancel;

  const _Composer({
    required this.controller,
    required this.hint,
    required this.busy,
    required this.onSend,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          // The server rejects anything longer, so the field stops first.
          maxLength: 2000,
          style: TextStyle(fontSize: 13.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
            counterText: '',
            filled: true,
            fillColor: _kBg,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (onCancel != null)
              TextButton(
                onPressed: busy ? null : onCancel,
                child: Text('Cancel',
                    style: TextStyle(
                        fontSize: 12.5.sp, color: Colors.grey.shade700)),
              ),
            SizedBox(width: 6.w),
            ElevatedButton(
              onPressed: busy ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22.r)),
              ),
              child: busy
                  ? SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Post',
                      style: TextStyle(
                          fontSize: 12.5.sp, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const _Action({required this.label, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: onTap == null
                  ? Colors.grey.shade500
                  : danger
                      ? Colors.red.shade600
                      : _kPrimary)),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool compact;

  const _Notice({required this.icon, required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: 16.w, vertical: compact ? 12.h : 24.h),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          if (!compact) ...[
            Icon(icon, size: 26.sp, color: Colors.grey.shade500),
            SizedBox(height: 8.h),
          ],
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5.sp, height: 1.4, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
