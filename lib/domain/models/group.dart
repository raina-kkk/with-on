import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String ownerUid;
  final List<String> memberUids;
  final String inviteCode;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerUid,
    required this.memberUids,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return Group(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      ownerUid: data['owner_uid'] as String? ?? '',
      memberUids: (data['member_uids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      inviteCode: data['invite_code'] as String? ?? '',
      createdAt: _fromTimestamp(data['created_at']) ?? DateTime.now(),
      updatedAt: _fromTimestamp(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'owner_uid': ownerUid,
      'member_uids': memberUids,
      'invite_code': inviteCode,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Group copyWith({
    String? name,
    String? description,
    List<String>? memberUids,
    String? inviteCode,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerUid: ownerUid,
      memberUids: memberUids ?? this.memberUids,
      inviteCode: inviteCode ?? this.inviteCode,
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

