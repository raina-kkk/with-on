import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String? fcmToken;
  final List<String> groupIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.fcmToken,
    required this.groupIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      displayName: data['display_name'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photo_url'] as String?,
      fcmToken: data['fcm_token'] as String?,
      groupIds: (data['group_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: _fromTimestamp(data['created_at']) ?? DateTime.now(),
      updatedAt: _fromTimestamp(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'fcm_token': fcmToken,
      'group_ids': groupIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? fcmToken,
    List<String>? groupIds,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      groupIds: groupIds ?? this.groupIds,
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

