import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDataRecoveryService {
  const AccountDataRecoveryService._();

  static Future<void> recoverByEmail(User user) async {
    try {
      final email = user.email?.trim();
      if (email == null || email.isEmpty) return;

      final db = FirebaseFirestore.instance;
      final uid = user.uid;
      final legacyUserDocs = await _findLegacyUsersByEmail(
        db: db,
        email: email,
        currentUid: uid,
      );
      final legacyUids = legacyUserDocs.map((doc) => doc.id).toList();

      await _mergeUserProfileToCurrent(
        db: db,
        user: user,
        currentUid: uid,
        legacyUserDocs: legacyUserDocs,
      );

      await _migrateOwnerUidByEmail(
        db: db,
        collectionName: 'prayers',
        email: email,
        uid: uid,
      );

      await _migrateOwnerUidByEmail(
        db: db,
        collectionName: 'group_prayers',
        email: email,
        uid: uid,
      );

      for (final legacyUid in legacyUids) {
        await _migrateOwnerUidByLegacyUid(
          db: db,
          collectionName: 'prayers',
          legacyUid: legacyUid,
          uid: uid,
        );
        await _migrateOwnerUidByLegacyUid(
          db: db,
          collectionName: 'group_prayers',
          legacyUid: legacyUid,
          uid: uid,
        );
      }

      await _migrateGroupMembers(
        db: db,
        legacyUids: legacyUids,
        currentUid: uid,
      );

      await _migrateHeldByUids(
        db: db,
        legacyUids: legacyUids,
        currentUid: uid,
      );

      await _backfillGroupPrayersForCurrentUser(
        db: db,
        currentUid: uid,
      );
    } catch (_) {
      // 복구 실패가 앱 전체 렌더링을 깨지 않도록 삼킵니다.
    }
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findLegacyUsersByEmail({
    required FirebaseFirestore db,
    required String email,
    required String currentUid,
  }) async {
    final snap = await db.collection('users').where('email', isEqualTo: email).get();
    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in snap.docs) {
      if (doc.id != currentUid) result.add(doc);
    }
    return result;
  }

  static Future<void> _mergeUserProfileToCurrent({
    required FirebaseFirestore db,
    required User user,
    required String currentUid,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> legacyUserDocs,
  }) async {
    final currentRef = db.collection('users').doc(currentUid);
    final currentSnap = await currentRef.get();
    final currentData = currentSnap.data() ?? <String, dynamic>{};

    final mergedGroupIds = <String>{
      ...((currentData['group_ids'] as List<dynamic>?)?.map((e) => e.toString()) ?? const <String>[]),
    };
    String mergedNickname = (currentData['nickname'] as String?)?.trim() ?? '';
    String? mergedPhotoUrl = currentData['photo_url'] as String?;

    for (final legacyDoc in legacyUserDocs) {
      final data = legacyDoc.data();
      final legacyGroups =
          (data['group_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      mergedGroupIds.addAll(legacyGroups);

      final legacyNickname = (data['nickname'] as String?)?.trim() ?? '';
      if (mergedNickname.isEmpty && legacyNickname.isNotEmpty) {
        mergedNickname = legacyNickname;
      }
      final legacyPhoto = data['photo_url'] as String?;
      if ((mergedPhotoUrl == null || mergedPhotoUrl.isEmpty) &&
          legacyPhoto != null &&
          legacyPhoto.isNotEmpty) {
        mergedPhotoUrl = legacyPhoto;
      }
    }

    final update = <String, dynamic>{
      'uid': currentUid,
      'email': user.email ?? '',
      'group_ids': mergedGroupIds.toList(),
      'updated_at': DateTime.now(),
    };
    if (mergedNickname.isNotEmpty) update['nickname'] = mergedNickname;
    if (mergedPhotoUrl != null && mergedPhotoUrl.isNotEmpty) {
      update['photo_url'] = mergedPhotoUrl;
    }

    await currentRef.set(update, SetOptions(merge: true));
  }

  static Future<void> _migrateOwnerUidByEmail({
    required FirebaseFirestore db,
    required String collectionName,
    required String email,
    required String uid,
  }) async {
    final snap = await db
        .collection(collectionName)
        .where('owner_email', isEqualTo: email)
        .get();

    if (snap.docs.isEmpty) return;

    WriteBatch batch = db.batch();
    var opCount = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['owner_uid'] as String?) == uid) {
        continue;
      }
      batch.update(doc.reference, {
        'owner_uid': uid,
        'updated_at': DateTime.now(),
      });
      opCount++;

      if (opCount >= 450) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
  }

  static Future<void> _migrateOwnerUidByLegacyUid({
    required FirebaseFirestore db,
    required String collectionName,
    required String legacyUid,
    required String uid,
  }) async {
    final snap = await db
        .collection(collectionName)
        .where('owner_uid', isEqualTo: legacyUid)
        .get();

    if (snap.docs.isEmpty) return;

    WriteBatch batch = db.batch();
    var opCount = 0;

    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'owner_uid': uid,
        'updated_at': DateTime.now(),
      });
      opCount++;

      if (opCount >= 450) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
  }

  static Future<void> _migrateGroupMembers({
    required FirebaseFirestore db,
    required List<String> legacyUids,
    required String currentUid,
  }) async {
    for (final legacyUid in legacyUids) {
      final snap = await db
          .collection('groups')
          .where('member_uids', arrayContains: legacyUid)
          .get();
      if (snap.docs.isEmpty) continue;

      WriteBatch batch = db.batch();
      var opCount = 0;
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'member_uids': FieldValue.arrayRemove([legacyUid]),
          'updated_at': DateTime.now(),
        });
        batch.update(doc.reference, {
          'member_uids': FieldValue.arrayUnion([currentUid]),
          'updated_at': DateTime.now(),
        });
        opCount += 2;

        if (opCount >= 400) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      if (opCount > 0) await batch.commit();
    }
  }

  static Future<void> _migrateHeldByUids({
    required FirebaseFirestore db,
    required List<String> legacyUids,
    required String currentUid,
  }) async {
    for (final legacyUid in legacyUids) {
      final snap = await db
          .collection('group_prayers')
          .where('held_by_uids', arrayContains: legacyUid)
          .get();
      if (snap.docs.isEmpty) continue;

      WriteBatch batch = db.batch();
      var opCount = 0;
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'held_by_uids': FieldValue.arrayRemove([legacyUid]),
          'updated_at': DateTime.now(),
        });
        batch.update(doc.reference, {
          'held_by_uids': FieldValue.arrayUnion([currentUid]),
          'updated_at': DateTime.now(),
        });
        opCount += 2;

        if (opCount >= 400) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      if (opCount > 0) await batch.commit();
    }
  }

  static Future<void> _backfillGroupPrayersForCurrentUser({
    required FirebaseFirestore db,
    required String currentUid,
  }) async {
    final userSnap = await db.collection('users').doc(currentUid).get();
    final groupIds = (userSnap.data()?['group_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    if (groupIds.isEmpty) return;

    for (var i = 0; i < groupIds.length; i += 10) {
      final chunk = groupIds.skip(i).take(10).toList();
      final gpSnap = await db
          .collection('group_prayers')
          .where('group_id', whereIn: chunk)
          .get();
      if (gpSnap.docs.isEmpty) continue;

      final prayerIds = gpSnap.docs
          .map((d) => (d.data()['prayer_id'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final prayerMap = <String, Map<String, dynamic>>{};
      for (var p = 0; p < prayerIds.length; p += 10) {
        final pChunk = prayerIds.skip(p).take(10).toList();
        final prayerSnap = await db
            .collection('prayers')
            .where(FieldPath.documentId, whereIn: pChunk)
            .get();
        for (final doc in prayerSnap.docs) {
          prayerMap[doc.id] = doc.data();
        }
      }

      WriteBatch batch = db.batch();
      var opCount = 0;
      for (final gpDoc in gpSnap.docs) {
        final gp = gpDoc.data();
        final prayerId = (gp['prayer_id'] as String?) ?? '';
        if (prayerId.isEmpty) continue;
        final prayer = prayerMap[prayerId];
        if (prayer == null) continue;

        final update = <String, dynamic>{};
        final title = (prayer['title'] as String?)?.trim() ?? '';
        final content = (prayer['content'] as String?)?.trim() ?? '';
        final status = (prayer['status'] as String?) ?? 'praying';
        final ownerNickname = (prayer['owner_nickname'] as String?)?.trim() ?? '';
        final ownerEmail = (prayer['owner_email'] as String?)?.trim() ?? '';
        final ownerUid = (prayer['owner_uid'] as String?) ?? (gp['owner_uid'] as String? ?? '');

        if (((gp['title'] as String?)?.trim() ?? '').isEmpty && title.isNotEmpty) {
          update['title'] = title;
        }
        if (((gp['content'] as String?)?.trim() ?? '').isEmpty && content.isNotEmpty) {
          update['content'] = content;
        }
        if ((gp['status'] as String?) == null) {
          update['status'] = status;
        }
        if (((gp['owner_nickname'] as String?)?.trim() ?? '').isEmpty &&
            ownerNickname.isNotEmpty) {
          update['owner_nickname'] = ownerNickname;
        }
        if (((gp['owner_email'] as String?)?.trim() ?? '').isEmpty &&
            ownerEmail.isNotEmpty) {
          update['owner_email'] = ownerEmail;
        }
        if (((gp['owner_uid'] as String?) ?? '').isEmpty && ownerUid.isNotEmpty) {
          update['owner_uid'] = ownerUid;
        }
        if (update.isEmpty) continue;

        update['updated_at'] = DateTime.now();
        batch.update(gpDoc.reference, update);
        opCount++;

        if (opCount >= 400) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      if (opCount > 0) {
        await batch.commit();
      }
    }
  }
}
