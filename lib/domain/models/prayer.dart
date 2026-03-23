import 'package:cloud_firestore/cloud_firestore.dart';

/// 표시 순서: praying → waiting → answered → refocused → resting
enum PrayerStatus {
  praying,
  waiting,
  answered,
  refocused,
  resting,
}

PrayerStatus prayerStatusFromString(String? value) {
  switch (value) {
    case 'praying':
      return PrayerStatus.praying;
    case 'answered':
      return PrayerStatus.answered;
    case 'waiting':
      return PrayerStatus.waiting;
    case 'refocused':
      return PrayerStatus.refocused;
    case 'resting':
      return PrayerStatus.resting;
    case 'in_progress':
      return PrayerStatus.refocused;
    default:
      return PrayerStatus.praying;
  }
}

String prayerStatusToString(PrayerStatus status) {
  switch (status) {
    case PrayerStatus.praying:
      return 'praying';
    case PrayerStatus.answered:
      return 'answered';
    case PrayerStatus.waiting:
      return 'waiting';
    case PrayerStatus.refocused:
      return 'refocused';
    case PrayerStatus.resting:
      return 'resting';
  }
}

class Prayer {
  final String id;
  final String ownerUid;
  final String title;
  final String content;
  final PrayerStatus status;
  final bool isShared;
  final List<String> sharedGroupIds;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? answeredAt;
  final String? gratitudeNote;

  const Prayer({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.content,
    required this.status,
    required this.isShared,
    required this.sharedGroupIds,
    required this.createdAt,
    required this.updatedAt,
    required this.answeredAt,
    required this.gratitudeNote,
  });

  factory Prayer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return Prayer(
      id: doc.id,
      ownerUid: data['owner_uid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      status: prayerStatusFromString(data['status'] as String?),
      isShared: (data['is_shared'] as bool?) ?? false,
      sharedGroupIds: (data['shared_group_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: _fromTimestamp(data['created_at']) ?? DateTime.now(),
      updatedAt: _fromTimestamp(data['updated_at']),
      answeredAt: _fromTimestamp(data['answered_at']),
      gratitudeNote: data['gratitude_note'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'owner_uid': ownerUid,
      'title': title,
      'content': content,
      'status': prayerStatusToString(status),
      'is_shared': isShared,
      'shared_group_ids': sharedGroupIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'answered_at':
          answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'gratitude_note': gratitudeNote,
    };
  }

  Prayer copyWith({
    String? title,
    String? content,
    PrayerStatus? status,
    bool? isShared,
    List<String>? sharedGroupIds,
    DateTime? updatedAt,
    DateTime? answeredAt,
    String? gratitudeNote,
  }) {
    return Prayer(
      id: id,
      ownerUid: ownerUid,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      isShared: isShared ?? this.isShared,
      sharedGroupIds: sharedGroupIds ?? this.sharedGroupIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      answeredAt: answeredAt ?? this.answeredAt,
      gratitudeNote: gratitudeNote ?? this.gratitudeNote,
    );
  }

  static DateTime? _fromTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

