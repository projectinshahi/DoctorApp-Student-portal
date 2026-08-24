class SelectionCourse {
  final int id;
  final String title;
  final String? description;

  SelectionCourse({required this.id, required this.title, this.description});

  factory SelectionCourse.fromJson(Map<String, dynamic> json) {
    return SelectionCourse(
      id: json['id'],
      title: json['title'],
      description: json['description'],
    );
  }
}

class SelectionCourseType {
  final int id;
  final String title;
  final String? description;
  final int courseId;

  SelectionCourseType({
    required this.id,
    required this.title,
    this.description,
    required this.courseId,
  });

  factory SelectionCourseType.fromJson(Map<String, dynamic> json) {
    return SelectionCourseType(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      courseId: json['courseId'],
    );
  }
}

class SelectionResult {
  final SelectionCourse? selectedCourse;
  final SelectionCourseType? selectedCourseType;

  SelectionResult({this.selectedCourse, this.selectedCourseType});

  factory SelectionResult.fromJson(Map<String, dynamic> json) {
    return SelectionResult(
      selectedCourse: json['selectedCourse'] != null
          ? SelectionCourse.fromJson(json['selectedCourse'])
          : null,
      selectedCourseType: json['selectedCourseType'] != null
          ? SelectionCourseType.fromJson(json['selectedCourseType'])
          : null,
    );
  }
}