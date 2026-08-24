class SelectedContent {
  final CourseBrief? course;
  final CourseTypeBrief? courseType;
  final bool hasPaid;
  final List<Chapter> chapters;

  SelectedContent({this.course, this.courseType, required this.hasPaid, required this.chapters});

  bool get hasSelection => course != null;

  factory SelectedContent.fromJson(Map<String, dynamic> j) => SelectedContent(
    course: j['course'] == null ? null : CourseBrief.fromJson(j['course']),
    courseType: j['courseType'] == null ? null : CourseTypeBrief.fromJson(j['courseType']),
    hasPaid: j['hasPaid'] ?? false,
    chapters: ((j['chapters'] ?? []) as List).map((c) => Chapter.fromJson(c)).toList(),
  );
}

class CourseBrief {
  final int id;
  final String title;
  final String? thumbnail;
  final String accessType;

  CourseBrief({required this.id, required this.title, this.thumbnail, required this.accessType});

  bool get isPremium => accessType == 'premium';

  factory CourseBrief.fromJson(Map<String, dynamic> j) => CourseBrief(
    id: j['id'],
    title: j['title'],
    thumbnail: j['thumbnail'],
    accessType: j['accessType'] ?? 'free',
  );
}

class CourseTypeBrief {
  final int id;
  final String title;
  final String? description;
  final String accessType;
  final int chapterCount; // only present on the course-types list endpoint

  CourseTypeBrief({
    required this.id,
    required this.title,
    this.description,
    required this.accessType,
    this.chapterCount = 0,
  });

  factory CourseTypeBrief.fromJson(Map<String, dynamic> j) => CourseTypeBrief(
    id: j['id'],
    title: j['title'],
    description: j['description'],
    accessType: j['accessType'] ?? 'free',
    chapterCount: j['chapterCount'] ?? 0,
  );
}

class Chapter {
  final int id;
  final String title;
  final int displayOrder;
  final List<Lesson> lessons;

  Chapter({required this.id, required this.title, required this.displayOrder, required this.lessons});

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
    id: j['id'],
    title: j['title'],
    displayOrder: j['displayOrder'] ?? 0,
    lessons: ((j['lessons'] ?? []) as List).map((l) => Lesson.fromJson(l)).toList(),
  );
}

class Lesson {
  final int id;
  final String title;
  final String? description;
  final String type; // video | text | quiz
  final String? content;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? noteUrl;
  final String? noteFileType;
  final int displayOrder;
  final bool isFreePreview;
  final String accessType;
  final bool locked;

  Lesson({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.content,
    this.videoUrl,
    this.thumbnailUrl,
    this.noteUrl,
    this.noteFileType,
    required this.displayOrder,
    required this.isFreePreview,
    required this.accessType,
    required this.locked,
  });

  bool get isVideo => type == 'video';
  bool get hasNote => noteUrl != null;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'],
    title: j['title'],
    description: j['description'],
    type: j['type'] ?? 'text',
    content: j['content'],
    videoUrl: j['videoUrl'],
    thumbnailUrl: j['thumbnailUrl'],
    noteUrl: j['noteUrl'],
    noteFileType: j['noteFileType'],
    displayOrder: j['displayOrder'] ?? 0,
    isFreePreview: j['isFreePreview'] ?? false,
    accessType: j['accessType'] ?? 'free',
    locked: j['locked'] ?? false,
  );
}
