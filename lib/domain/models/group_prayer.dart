import 'package:cloud_firestore/cloud_firestore.dart';

class GroupPrayer {
  final String id;
  final String groupId;
  final String prayerId;
  final String ownerUid;
  final int holdCount;
  final DateTime? lastHeldAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GroupPrayer({
    required this.id,
    required this.groupId,
    required this.prayerId,
    required this.ownerUid,
    required this.holdCount,
    required this.lastHeldAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupPrayer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return GroupPrayer(
      id: doc.id,
      groupId: data['group_id'] as String? ?? '',
      prayerId: data['prayer_id'] as String? ?? '',
      ownerUid: data['owner_uid'] as String? ?? '',
      holdCount: (data['hold_count'] as int?) ?? 0,
      lastHeldAt: _fromTimestamp(data['last_held_at']),
      createdAt: _fromTimestamp(data['created_at']) ?? DateTime.now(),
      updatedAt: _fromTimestamp(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'group_id': groupId,
      'prayer_id': prayerId,
      'owner_uid': ownerUid,
      'hold_count': holdCount,
      'last_held_at':
          lastHeldAt != null ? Timestamp.fromDate(lastHeldAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  GroupPrayer copyWith({
    int? holdCount,
    DateTime? lastHeldAt,
    DateTime? updatedAt,
  }) {
    return GroupPrayer(
      id: id,
      groupId: groupId,
      prayerId: prayerId,
      ownerUid: ownerUid,
      holdCount: holdCount ?? this.holdCount,
      lastHeldAt: lastHeldAt ?? this.lastHeldAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _fromTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

