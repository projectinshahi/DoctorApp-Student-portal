// lib/models/notification_model.dart
//
// A notification as the backend stored it.
//
// Push arrives once and is gone; this is the copy that survives a phone with
// notifications switched off, an app that was closed, or a device that had
// not registered yet.
import 'package:flutter/foundation.dart';

@immutable
class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;

  /// The same map a push carries, so a row routes exactly as a tap on the
  /// notification would. **Every value is a string** — FCM refuses a message
  /// with a number in it — so ids need parsing.
  final Map<String, String> data;

  final DateTime? createdAt;

  /// Already seen, by the single timestamp the server keeps per student.
  final bool read;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.createdAt,
    this.read = false,
  });

  /// The id [key] carries, or null when it is missing or not a number.
  int? idFrom(String key) => int.tryParse('${data[key] ?? ''}');

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return NotificationItem(
      id: _toInt(json['id']) ?? 0,
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      data: rawData is Map
          ? {
              for (final entry in rawData.entries)
                entry.key.toString(): '${entry.value}',
            }
          : const {},
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
      read: json['read'] == true,
    );
  }
}

/// One page of the list.
@immutable
class NotificationFeed {
  final List<NotificationItem> items;
  final int unreadCount;

  /// Pass back as `?before=` for the next page. Null on the last page —
  /// paging is by timestamp because rows arrive while a student scrolls, and
  /// a page number would show the same row twice.
  final String? nextBefore;

  const NotificationFeed({
    required this.items,
    required this.unreadCount,
    this.nextBefore,
  });

  factory NotificationFeed.fromJson(Map<String, dynamic> json) {
    final raw = json['notifications'];
    final before = json['nextBefore']?.toString();
    return NotificationFeed(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((n) => NotificationItem.fromJson(Map<String, dynamic>.from(n)))
              .toList()
          : const [],
      unreadCount: _toInt(json['unreadCount']) ?? 0,
      nextBefore: (before == null || before.isEmpty || before == 'null')
          ? null
          : before,
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}
