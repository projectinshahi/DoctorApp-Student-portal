// lib/models/public_course_model.dart
//
// The catalogue, as a visitor sees it before signing in.
//
// From GET /api/courses, which is the one content endpoint that needs no
// token. Titles and exam types only — chapters, lessons and questions all sit
// behind /users/me/ and answer 401, by design.
import 'package:flutter/foundation.dart';

@immutable
class PublicCourse {
  final int id;
  final String title;
  final String? description;
  final String accessType;
  final List<PublicCourseType> types;

  const PublicCourse({
    required this.id,
    required this.title,
    this.description,
    this.accessType = 'free',
    this.types = const [],
  });

  bool get isPremium => accessType.toLowerCase() == 'premium';

  factory PublicCourse.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['courseTypes'];
    return PublicCourse(
      id: int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? '').toString(),
      description: _text(json['description']),
      accessType: (json['accessType'] ?? 'free').toString(),
      types: rawTypes is List
          ? rawTypes
              .whereType<Map>()
              .map((t) => PublicCourseType.fromJson(
                  Map<String, dynamic>.from(t)))
              .toList()
          : const [],
    );
  }
}

/// One exam inside a course — "DHA Exam", "Kuwait Prometric Exam". What a
/// student picks after signing in, and what a visitor is really shopping for.
@immutable
class PublicCourseType {
  final int id;
  final String title;

  const PublicCourseType({required this.id, required this.title});

  factory PublicCourseType.fromJson(Map<String, dynamic> json) =>
      PublicCourseType(
        id: int.tryParse('${json['id']}') ?? 0,
        title: (json['title'] ?? '').toString(),
      );
}

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
