// lib/models/rapid_recall_model.dart
//
// Rapid Recall: decks of revision cards.
//
// A card is an image, a note, or both — never neither. A deck may also carry
// one handout (a PDF or DOC). Every classification on a deck is optional: it
// can belong to a chapter — the subject a student picks from — to a lesson
// inside one, or to neither.
import 'package:flutter/foundation.dart';

@immutable
class RapidRecallDeck {
  final int id;
  final String title;
  final String? description;

  /// The handout. Null on most decks.
  final String? noteUrl;

  /// "pdf" | "doc" | "docx" | null. Only meaningful with [noteUrl].
  final String? noteFileType;

  /// The chapter this deck belongs to: the subject a student browses by.
  ///
  /// Sent on every deck, filled in from the lesson when the admin gave only a
  /// lesson — so it is the one field that groups both a lesson's deck and a
  /// deck filed under the subject alone.
  final int? chapterId;
  final RecallChapter? chapter;
  final int? lessonId;

  /// Null means the deck is not filed under a subject.
  final RecallSubject? subject;

  /// Null on a deck filed under the chapter itself rather than one lesson.
  final RecallLesson? lesson;

  final int displayOrder;

  /// Sent on the list response, where [cards] is absent. Not derived from
  /// `cards.length`: on a list that would read zero for every deck.
  final int cardCount;

  /// Empty until the deck is opened — the list endpoint sends no cards.
  final List<RecallCard> cards;

  const RapidRecallDeck({
    required this.id,
    required this.title,
    this.description,
    this.noteUrl,
    this.noteFileType,
    this.chapterId,
    this.chapter,
    this.lessonId,
    this.subject,
    this.lesson,
    this.displayOrder = 0,
    this.cardCount = 0,
    this.cards = const [],
  });

  bool get hasHandout => (noteUrl ?? '').isNotEmpty;

  /// The first card's image, used as the deck's thumbnail.
  ///
  /// Null until the cards are loaded — the list response carries none — and
  /// for a deck that is notes only.
  String? get coverImageUrl {
    for (final card in cards) {
      if (card.hasImage) return card.imageUrl;
    }
    return null;
  }

  /// What a row says under the title. The subject, when there is one, plus
  /// the card count — a student choosing between two decks wants to know how
  /// much is in each.
  String get summary {
    final count = '$cardCount card${cardCount == 1 ? '' : 's'}';
    final name = subject?.name;
    return name == null || name.isEmpty ? count : '$name · $count';
  }

  factory RapidRecallDeck.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'];

    return RapidRecallDeck(
      id: _asInt(json['id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: _asText(json['description']),
      noteUrl: _asText(json['noteUrl']),
      noteFileType: _asText(json['noteFileType']),
      chapterId: _asInt(json['chapterId']),
      chapter: json['chapter'] is Map
          ? RecallChapter.fromJson(Map<String, dynamic>.from(json['chapter']))
          : null,
      lessonId: _asInt(json['lessonId']),
      subject: json['subject'] is Map
          ? RecallSubject.fromJson(Map<String, dynamic>.from(json['subject']))
          : null,
      lesson: json['lesson'] is Map
          ? RecallLesson.fromJson(Map<String, dynamic>.from(json['lesson']))
          : null,
      displayOrder: _asInt(json['displayOrder']) ?? 0,
      cardCount: _asInt(json['cardCount']) ??
          (rawCards is List ? rawCards.length : 0),
      // The list response has no `cards` key at all, which is not the same as
      // a deck with none.
      cards: rawCards is List
          ? rawCards
              .whereType<Map>()
              .map((c) => RecallCard.fromJson(Map<String, dynamic>.from(c)))
              .toList()
          : const [],
    );
  }
}

@immutable
class RecallSubject {
  final int id;
  final String name;

  const RecallSubject({required this.id, required this.name});

  factory RecallSubject.fromJson(Map<String, dynamic> json) => RecallSubject(
        id: _asInt(json['id']) ?? 0,
        name: (json['name'] ?? '').toString(),
      );
}

@immutable
class RecallLesson {
  final int id;
  final String title;

  /// Carried because lesson titles are not unique — two live lessons are both
  /// called "Obstetrics". Without the chapter a list of lessons shows two
  /// identical rows with different decks behind them.
  final RecallChapter? chapter;

  const RecallLesson({required this.id, required this.title, this.chapter});

  factory RecallLesson.fromJson(Map<String, dynamic> json) => RecallLesson(
        id: _asInt(json['id']) ?? 0,
        title: (json['title'] ?? '').toString(),
        chapter: json['chapter'] is Map
            ? RecallChapter.fromJson(Map<String, dynamic>.from(json['chapter']))
            : null,
      );
}

@immutable
class RecallChapter {
  final int id;
  final String title;

  const RecallChapter({required this.id, required this.title});

  factory RecallChapter.fromJson(Map<String, dynamic> json) => RecallChapter(
        id: _asInt(json['id']) ?? 0,
        title: (json['title'] ?? '').toString(),
      );
}

@immutable
class RecallCard {
  final int id;

  /// Image or note — both nullable, never both null.
  final String? imageUrl;
  final String? note;

  final int displayOrder;

  const RecallCard({
    required this.id,
    this.imageUrl,
    this.note,
    this.displayOrder = 0,
  });

  bool get hasImage => (imageUrl ?? '').isNotEmpty;
  bool get hasNote => (note ?? '').trim().isNotEmpty;

  factory RecallCard.fromJson(Map<String, dynamic> json) => RecallCard(
        id: _asInt(json['id']) ?? 0,
        imageUrl: _asText(json['imageUrl']),
        note: _asText(json['note']),
        displayOrder: _asInt(json['displayOrder']) ?? 0,
      );
}

/// Decks gathered under one heading — a chapter on the topics screen, a
/// lesson on the screen below it.
///
/// [id] is null for the catch-all group: decks with no lesson have no
/// chapter, and a deck filed against nothing at all belongs to the course.
@immutable
class RecallGroup {
  final int? id;
  final String title;

  final List<RapidRecallDeck> decks;

  const RecallGroup({
    required this.id,
    required this.title,
    required this.decks,
  });

  int get cardCount =>
      decks.fold(0, (total, deck) => total + deck.cardCount);

  String get summary {
    final deckPart = '${decks.length} deck${decks.length == 1 ? '' : 's'}';
    return '$deckPart · $cardCount card${cardCount == 1 ? '' : 's'}';
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

/// Null, "" and "null" all mean absent. The last one is what a JSON null
/// becomes if it is ever stringified on the way here.
String? _asText(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty || text == 'null') return null;
  return text;
}
