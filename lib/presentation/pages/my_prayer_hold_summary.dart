import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 나의 기도 카드 우측 하단 "기도 손 + 숫자". 개인 참여(비공유) + 기도 그룹 참여 합산.
class MyPrayerHoldSummary extends StatelessWidget {
  const MyPrayerHoldSummary({super.key, required this.prayerId});

  final String prayerId;

  @override
  Widget build(BuildContext context) {
    if (prayerId.isEmpty) return const SizedBox.shrink();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('prayers')
          .doc(prayerId)
          .snapshots(),
      builder: (context, prayerSnapshot) {
        if (prayerSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final prayerData = prayerSnapshot.data?.data();
        final personalHoldCount = (prayerData?['hold_count'] as int?) ?? 0;
        final personalHeldBy = (prayerData?['held_by_uids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        final prayedByMePersonal =
            uid.isNotEmpty && personalHeldBy.contains(uid);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('group_prayers')
              .where('prayer_id', isEqualTo: prayerId)
              .snapshots(),
          builder: (context, gpSnapshot) {
            if (gpSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            int groupHoldCount = 0;
            bool prayedByMeGroup = false;
            final docs = gpSnapshot.data?.docs ?? [];

            for (final doc in docs) {
              final data = doc.data();
              groupHoldCount += (data['hold_count'] as int?) ?? 0;
              if (!prayedByMeGroup && uid.isNotEmpty) {
                final heldBy = (data['held_by_uids'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    <String>[];
                if (heldBy.contains(uid)) prayedByMeGroup = true;
              }
            }

            final totalHoldCount = personalHoldCount + groupHoldCount;
            final prayedByMe = prayedByMePersonal || prayedByMeGroup;

            Future<void> onTap() async {
              try {
                if (docs.isNotEmpty) {
                  final batch = FirebaseFirestore.instance.batch();
                  final now = DateTime.now();
                  for (final doc in docs) {
                    batch.update(doc.reference, {
                      'hold_count': FieldValue.increment(1),
                      'last_held_at': now,
                      if (uid.isNotEmpty)
                        'held_by_uids': FieldValue.arrayUnion([uid]),
                    });
                  }
                  await batch.commit();
                } else {
                  await FirebaseFirestore.instance
                      .collection('prayers')
                      .doc(prayerId)
                      .update({
                    'hold_count': FieldValue.increment(1),
                    'last_held_at': DateTime.now(),
                    if (uid.isNotEmpty)
                      'held_by_uids': FieldValue.arrayUnion([uid]),
                    'updated_at': DateTime.now(),
                  });
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('예수님의 이름으로 기도합니다. 아멘.'),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '기도를 붙드는 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.',
                      ),
                    ),
                  );
                }
              }
            }

            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🙏',
                    style: TextStyle(fontSize: 10),
                  ),
                  if (totalHoldCount > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$totalHoldCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            prayedByMe ? FontWeight.w700 : FontWeight.w500,
                        color: prayedByMe
                            ? Theme.of(context).colorScheme.primary
                            : AppTheme.textLight,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
