// lib/view/Home/recall/recall_decks_screen.dart
//
// The decks inside one lesson.
//
// Reads the list the provider already holds — no fetch of its own, so this
// opens instantly from the screen above it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/rapid_recall_model.dart';
import '../../../repository/rapid_recall_provider.dart';
import '../../../widget/app_bottom_nav.dart';
import '../../../widget/loading_wave.dart';
import 'recall_cards_screen.dart';
import 'recall_lists_screen.dart';

class RecallDecksScreen extends StatefulWidget {
  final int? chapterId;
  final int? lessonId;
  final String title;

  const RecallDecksScreen({
    super.key,
    required this.chapterId,
    required this.lessonId,
    required this.title,
  });

  /// Rows shown before "View all". Enough to fill a phone; a long lesson
  /// otherwise opens on a wall of decks.
  static const int preview = 4;

  @override
  State<RecallDecksScreen> createState() => _RecallDecksScreenState();
}

class _RecallDecksScreenState extends State<RecallDecksScreen> {
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: warming notifies the provider, and notifying
    // during a build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmShown());
  }

  /// Loads the cards behind the rows on screen, for their thumbnails. Only
  /// the rows actually shown — the rest wait for View all.
  void _warmShown() {
    if (!mounted) return;
    final recall = context.read<RapidRecallProvider>();
    final decks = recall.decksIn(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
    );
    final shown =
        _showAll ? decks : decks.take(RecallDecksScreen.preview);
    unawaited(recall.warmDecks(shown.map((deck) => deck.id)));
  }

  @override
  Widget build(BuildContext context) {
    final recall = context.watch<RapidRecallProvider>();
    final decks = recall.decksIn(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
    );
    final collapsed = !_showAll && decks.length > RecallDecksScreen.preview;
    final visible =
        collapsed ? decks.take(RecallDecksScreen.preview).toList() : decks;

    return Scaffold(
      backgroundColor: kRecallBg,
      extendBody: true,
      appBar: recallAppBar(
        context,
        title: widget.title,
        subtitle: 'Rapid Recall',
      ),
      body: decks.isEmpty
          ? const RecallMessage(text: 'No recall cards here yet.')
          : ListView(
              padding:
                  EdgeInsets.fromLTRB(20.w, 8.h, 20.w, kRecallNavClearance),
              children: [
                for (final deck in visible) ...[
                  RecallDeckTile.wired(
                    recall,
                    deck,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecallCardsScreen(deckId: deck.id),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
                if (collapsed)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() => _showAll = true);
                        _warmShown();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                      ),
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 4,
        onTap: (index) => openTabFromRecall(context, index),
      ),
    );
  }
}

/// One deck. Thumbnail, title, what is in it, and the bookmark.
class RecallDeckTile extends StatelessWidget {
  final RapidRecallDeck deck;

  /// The deck's first card image. A deck has no cover of its own and the
  /// list sends no cards, so this arrives once the screen has warmed the
  /// deck — until then, and for a notes-only deck, the tile shows an icon.
  final String? coverUrl;

  /// The deck's cards have not arrived yet, so whether it has an image at
  /// all is still unknown. The tile animates rather than showing an icon it
  /// may be about to replace.
  final bool coverLoading;
  final bool bookmarked;

  /// Not opened on this phone yet. Marked with the accent down the left
  /// edge, so a student coming back to revise sees what they have not
  /// covered.
  final bool isNew;

  final VoidCallback onBookmark;
  final VoidCallback onTap;

  /// A row for [deck], with every state read from the provider.
  ///
  /// Two lists draw deck rows — the decks screen, and the "more in this
  /// lesson" list under an open deck — and wiring the thumbnail, the new
  /// marker and the bookmark by hand in both is how one of them ends up
  /// showing a stale bookmark. Called from a build that already watches
  /// [recall], so the row updates with it.
  static RecallDeckTile wired(
    RapidRecallProvider recall,
    RapidRecallDeck deck, {
    required VoidCallback onTap,
  }) {
    return RecallDeckTile(
      deck: deck,
      // The loaded copy's first image. Null until its cards land.
      coverUrl: recall.deck(deck.id)?.coverImageUrl,
      // Its cards are still on the way. Not once the fetch has failed — that
      // would animate forever over nothing.
      coverLoading:
          !recall.hasCards(deck.id) && recall.deckError(deck.id) == null,
      bookmarked: recall.isBookmarked(deck.id),
      isNew: !recall.isOpened(deck.id),
      onBookmark: () => recall.toggleBookmark(deck.id),
      onTap: onTap,
    );
  }

  const RecallDeckTile({
    super.key,
    required this.deck,
    required this.bookmarked,
    required this.onBookmark,
    required this.onTap,
    this.coverUrl,
    this.coverLoading = false,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 8.w, 14.h),
                child: Row(
                  children: [
                    _Thumbnail(
                      url: coverUrl,
                      loading: coverLoading,
                      hasHandout: deck.hasHandout,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14.sp,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            deck.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.sp, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // Its own hit target inside a tappable row, so a bookmark
                    // never opens the deck by accident.
                    IconButton(
                      onPressed: onBookmark,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 24.sp,
                        color: bookmarked
                            ? kRecallPrimary
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // A stripe rather than a left border: a border of one colour on
              // one side cannot share a rounded box with none on the others.
              if (isNew)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 5.w, color: kRecallPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three states: the image, the dots while it is on its way, or an icon for a
/// deck with no image (and for one that failed).
///
/// The wait has two parts and the dots cover both — the deck's cards being
/// fetched, then the image itself downloading.
class _Thumbnail extends StatelessWidget {
  final String? url;
  final bool loading;
  final bool hasHandout;

  const _Thumbnail({
    required this.url,
    required this.loading,
    required this.hasHandout,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      hasHandout ? Icons.description_outlined : Icons.image_outlined,
      size: 22.sp,
      color: kRecallPrimary,
    );
    final dots = LoadingDots(size: 7.w);

    final Widget child;
    if (url != null) {
      child = Image.network(
        url!,
        width: double.infinity,
        height: double.infinity,
        // Cover, not contain: a thumbnail is a glimpse, and letterbox bars at
        // this size read as a broken image.
        fit: BoxFit.cover,
        // frameBuilder rather than loadingBuilder: loadingBuilder only fires
        // once bytes are flowing, which left the tile blank for the whole
        // connection before that. frame stays null until there is a picture.
        frameBuilder: (context, image, frame, loadedSync) {
          // Already in the image cache — no wait to show.
          if (loadedSync) return image;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: frame == null ? dots : image,
          );
        },
        errorBuilder: (context, _, _) => placeholder,
      );
    } else if (loading) {
      child = dots;
    } else {
      child = placeholder;
    }

    return Container(
      width: 96.w,
      height: 62.h,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kRecallBg,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: child,
    );
  }
}
