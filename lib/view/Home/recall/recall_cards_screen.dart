// lib/view/Home/recall/recall_cards_screen.dart
//
// One deck, card by card.
//
// Each card is its own scrolling page: the image at its natural proportions
// with its position on it, then the note in full. Swipe sideways for the next
// card. The deck's bookmark and handout sit in the app bar, beside the title
// they belong to.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/rapid_recall_model.dart';
import '../../../repository/rapid_recall_provider.dart';
import '../../../services/app_analytics.dart';
import '../../../widget/app_bottom_nav.dart';
import '../../../widget/app_loading.dart';
import '../../../widget/app_snackbar.dart';
import '../../../widget/loading_wave.dart';
import '../lessons/videoplay/PdfViewerModal.dart';
import 'recall_decks_screen.dart' show RecallDeckTile;
import 'recall_lists_screen.dart';

class RecallCardsScreen extends StatefulWidget {
  /// The id rather than the deck: the list refreshes while this screen is
  /// open, and the cards arrive in a second response.
  final int deckId;

  const RecallCardsScreen({super.key, required this.deckId});

  @override
  State<RecallCardsScreen> createState() => _RecallCardsScreenState();
}

class _RecallCardsScreenState extends State<RecallCardsScreen> {
  final PageController _pages = PageController();

  @override
  void initState() {
    super.initState();
    // Not in build: both of these notify the provider, and notifying during
    // a build throws. A deck opened before paints from the provider's copy
    // first and refreshes under the cards already on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recall = context.read<RapidRecallProvider>()
        ..markOpened(widget.deckId);
      AppAnalytics.log('recall_deck_opened', {'deck_id': widget.deckId});

      // The deck the student tapped first, then the thumbnails for the decks
      // listed under it — never the other way round, or the list's images
      // would queue ahead of the cards the student is waiting to read.
      recall.loadDeck(widget.deckId).then((_) {
        if (!mounted) return;
        unawaited(recall.warmDecks(
          recall.siblingsOf(widget.deckId).map((deck) => deck.id),
        ));
      });
    });
  }

  /// Opens another deck in place of this one.
  ///
  /// Replace, not push: stepping through five decks and then pressing back
  /// should land on the list, not walk back through every deck on the way.
  void _openDeck(int deckId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RecallCardsScreen(deckId: deckId)),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openHandout(RapidRecallDeck deck) {
    final url = deck.noteUrl;
    if (url == null) return;

    // The app has a PDF viewer and nothing that can render a Word file.
    if ((deck.noteFileType ?? 'pdf').toLowerCase() != 'pdf') {
      showAppSnackBar(
        context,
        'This handout is a ${deck.noteFileType} file — open it from the website.',
        kind: AppMessage.failure,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PdfViewerModal(pdfUrl: url, title: deck.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recall = context.watch<RapidRecallProvider>();
    final deck = recall.deck(widget.deckId);
    final cards = deck?.cards ?? const <RecallCard>[];
    final others = recall.siblingsOf(widget.deckId);

    final error = recall.deckError(widget.deckId);

    // Only a deck never opened waits — and not once its fetch has failed,
    // which would leave a spinner turning above the error. One opened before
    // (or warmed by the list) shows its cards while the refetch runs.
    final showLoading =
        cards.isEmpty && !recall.hasCards(widget.deckId) && error == null;

    final Widget body;
    if (showLoading) {
      body = const AppLoading();
    } else if (cards.isEmpty || deck == null) {
      body = RecallMessage(text: error ?? 'This deck has no cards yet.');
    } else {
      body = PageView.builder(
        controller: _pages,
        itemCount: cards.length,
        itemBuilder: (context, i) => SingleChildScrollView(
          // One scroll for the whole card, clearing the floating nav at the
          // foot so the last line of a long note is never under it.
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, kRecallNavClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardPanel(
                card: cards[i],
                position: '${i + 1}/${cards.length}',
              ),
              if (cards[i].hasNote) ...[
                SizedBox(height: 14.h),
                _NoteBlock(text: cards[i].note!),
              ],
              // Where to go next, at the foot of the card — reached by
              // finishing it, which is exactly when the student wants it.
              if (others.isNotEmpty) ...[
                SizedBox(height: 28.h),
                _MoreDecks(
                  lessonTitle: deck.lesson?.title,
                  decks: others,
                  onOpen: _openDeck,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kRecallBg,
      extendBody: true,
      appBar: recallAppBar(
        context,
        title: deck?.title ?? 'Rapid Recall',
        // The row under the image used to carry these. The title it repeated
        // is already up here, so the buttons came up to join it rather than
        // leaving the handout with no way to open it.
        actions: deck == null
            ? null
            : [
                if (deck.hasHandout)
                  IconButton(
                    tooltip: 'Open handout',
                    onPressed: () => _openHandout(deck),
                    icon: Icon(Icons.description_outlined,
                        size: 23.sp, color: kRecallPrimary),
                  ),
                IconButton(
                  tooltip: recall.isBookmarked(deck.id)
                      ? 'Remove bookmark'
                      : 'Bookmark',
                  onPressed: () => context
                      .read<RapidRecallProvider>()
                      .toggleBookmark(deck.id),
                  icon: Icon(
                    recall.isBookmarked(deck.id)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 24.sp,
                    color: recall.isBookmarked(deck.id)
                        ? kRecallPrimary
                        : Colors.grey.shade700,
                  ),
                ),
                SizedBox(width: 6.w),
              ],
      ),
      body: body,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 4,
        onTap: (index) => openTabFromRecall(context, index),
      ),
    );
  }
}

/// The card itself: its image with the position on it, or — for a card that
/// is only a note — a plain panel carrying the position so the count never
/// disappears.
class _CardPanel extends StatelessWidget {
  final RecallCard card;

  /// "2/4".
  final String position;

  const _CardPanel({required this.card, required this.position});

  @override
  Widget build(BuildContext context) {
    if (!card.hasImage) {
      return Align(
        alignment: Alignment.centerRight,
        child: _Counter(text: position),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26.r),
      child: Stack(
        children: [
          _CardImage(url: card.imageUrl!),
          Positioned(
            right: 14.w,
            bottom: 14.h,
            child: _Counter(text: position),
          ),
        ],
      ),
    );
  }
}

/// The image on a card.
///
/// Drawn at the width of the page and whatever height its own proportions
/// ask for, rather than fitted into a box of a height we picked — a fixed box
/// letterboxes a tall ECG into a strip and pads a wide one with empty space.
/// The page scrolls, so a tall image is simply a taller page.
///
/// Tapping opens it full screen, where it can be pinched: the whole point of
/// a recall card is often one detail inside it.
class _CardImage extends StatelessWidget {
  final String url;

  const _CardImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (_) => _FullScreenImage(url: url),
      ),
      child: Container(
        // White behind it, so a diagram saved with a transparent background
        // is not read against the page tint.
        color: Colors.white,
        width: double.infinity,
        // Never shorter than the panel in the design, so a wide, short image
        // still reads as the card rather than a strip.
        constraints: BoxConstraints(minHeight: 240.h),
        alignment: Alignment.center,
        child: Image.network(
          url,
          width: double.infinity,
          // Width is tight and height is free, so the image keeps its own
          // aspect ratio instead of being cropped or letterboxed.
          fit: BoxFit.fitWidth,
          // Dots in a reserved height until the first frame: without the
          // height the page jumps when the image lands, and loadingBuilder
          // only fires once bytes are flowing, leaving the panel blank for
          // the connection before that.
          frameBuilder: (context, image, frame, loadedSync) {
            // In the image cache already — the deck list's thumbnail is this
            // same URL, so the first card usually lands here.
            if (loadedSync) return image;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: frame == null
                  ? SizedBox(
                      height: 240.h,
                      child: Center(child: LoadingDots(size: 10.w)),
                    )
                  : image,
            );
          },
          // Covers a dead link and an SVG alike: this app has no SVG renderer,
          // so one arriving here shows the fallback rather than a grey void.
          errorBuilder: (context, _, _) => Center(
            child: Icon(Icons.image_outlined,
                size: 40.sp, color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String text;

  const _Counter({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700),
        ),
      );
}

class _FullScreenImage extends StatelessWidget {
  final String url;

  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 12.h,
            right: 12.w,
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.close_rounded, size: 26.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final String text;

  const _NoteBlock({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 18.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 13.5.sp, height: 1.6, color: Colors.grey.shade800),
        ),
      );
}

/// The other decks in this lesson, drawn with the same row as the list the
/// student came from.
class _MoreDecks extends StatelessWidget {
  final String? lessonTitle;
  final List<RapidRecallDeck> decks;
  final ValueChanged<int> onOpen;

  const _MoreDecks({
    required this.lessonTitle,
    required this.decks,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    // Watched here as well as by the screen, so a thumbnail landing or a
    // bookmark toggled rebuilds these rows.
    final recall = context.watch<RapidRecallProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lessonTitle == null || lessonTitle!.isEmpty
                    ? 'More recall decks'
                    : 'More in $lessonTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '${decks.length} deck${decks.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        for (final deck in decks) ...[
          RecallDeckTile.wired(recall, deck, onTap: () => onOpen(deck.id)),
          SizedBox(height: 12.h),
        ],
      ],
    );
  }
}
