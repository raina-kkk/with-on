import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/week_utils.dart';
import '../widgets/app_banner.dart';

// ── 소그룹 멤버 시트/제거 (설정 화면에서도 사용) ──
Future<Map<String, String>> _fetchGroupMemberNicknames(
    List<String> uids) async {
  final result = <String, String>{};
  for (final uid in uids) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      result[uid] =
          (doc.data()?['nickname'] as String?)?.trim() ?? uid;
    } catch (_) {
      result[uid] = uid;
    }
  }
  return result;
}

Future<void> _removeMemberFromGroup({
  required BuildContext context,
  required String groupId,
  required String memberUid,
}) async {
  try {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
      'member_uids': FieldValue.arrayRemove([memberUid]),
      'updated_at': now,
    });
    await FirebaseFirestore.instance.collection('users').doc(memberUid).set(
      {
        'group_ids': FieldValue.arrayRemove([groupId]),
        'updated_at': now,
      },
      SetOptions(merge: true),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택하신 멤버를 소그룹에서 조용히 내보냈습니다.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '멤버를 내보내는 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.'),
        ),
      );
    }
  }
}

void _openGroupMemberSheet({
  required BuildContext context,
  required String groupId,
  required String ownerUid,
  required List<String> memberUids,
  required String currentUid,
  required bool canManage,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              canManage ? '소그룹 멤버 관리' : '소그룹 멤버 목록',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canManage
                  ? '함께하고 있는 손길들을 조심스럽게 관리할 수 있습니다.\n필요할 때에만 신중하게 사용해 주세요.'
                  : '함께 기도하고 있는 소그룹 멤버들입니다.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMedium,
                  ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<Map<String, String>>(
                future: _fetchGroupMemberNicknames(memberUids),
                builder: (context, nicknameSnapshot) {
                  final nicknames = nicknameSnapshot.data ?? {};
                  final isLoading =
                      nicknameSnapshot.connectionState == ConnectionState.waiting;
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: memberUids.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final memberUid = memberUids[index];
                      final isOwnerRow = memberUid == ownerUid;
                      final isMe = memberUid == currentUid;
                      final nickname = isLoading
                          ? '...'
                          : (nicknames[memberUid] ?? memberUid);
                      final displayName =
                          isMe ? '$nickname (나)' : nickname;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            nickname.isNotEmpty
                                ? nickname[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        title: Text(
                          isOwnerRow ? '$displayName 👑' : displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: isOwnerRow
                            ? const Text('이 소그룹의 관리자입니다.')
                            : null,
                        trailing: canManage && !isOwnerRow
                            ? IconButton(
                                icon: const Icon(
                                  Icons.person_remove_rounded,
                                  color: AppTheme.errorRed,
                                ),
                                onPressed: () async {
                                  await _removeMemberFromGroup(
                                    context: ctx,
                                    groupId: groupId,
                                    memberUid: memberUid,
                                  );
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                },
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class GroupPage extends StatefulWidget {
  const GroupPage({
    super.key,
    this.onNotification,
    this.onProfile,
    this.notificationCount,
  });

  final VoidCallback? onNotification;
  final VoidCallback? onProfile;
  final int? notificationCount;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  String? _selectedGroupId;

  /// 0 = 이번 주, -1 = 지난 주, 1 = 다음 주
  int _weekOffset = 0;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _openCreateGroupSheet() async {
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 로그인 정보가 준비되지 않았습니다.\n잠시 후 다시 시도해 주시면 감사하겠습니다.'),
        ),
      );
      return;
    }

    final nameController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: bottomInset + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '새 소그룹을 만들어 볼까요?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '소그룹 이름',
                  hintText: '예: 청년부 3조, 화요 기도 모임',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('조용히 닫기'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('소그룹 이름을 한 줄만이라도 적어 주시면 감사하겠습니다.'),
                          ),
                        );
                        return;
                      }

                      final groupId = await _createGroup(name: name, adminUid: uid);
                      if (!mounted) return;

                      Navigator.of(context).pop();

                      setState(() {
                        _selectedGroupId = groupId;
                      });
                    },
                    child: const Text('소그룹 만들기'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _createGroup({
    required String name,
    required String adminUid,
  }) async {
    try {
      final inviteCode = await _generateUniqueInviteCode();
      final now = DateTime.now();

      final groupRef = await FirebaseFirestore.instance.collection('groups').add({
        'name': name,
        'description': null,
        'owner_uid': adminUid,
        'member_uids': [adminUid],
        'invite_code': inviteCode,
        'created_at': now,
        'updated_at': now,
      });

      // Users 컬렉션에 내가 속한 groupIds 추가
      await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .set(
        {
          'group_ids': FieldValue.arrayUnion([groupRef.id]),
          'updated_at': now,
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '소그룹이 만들어졌습니다.\n초대 코드는 $inviteCode 입니다.',
            ),
          ),
        );
      }

      return groupRef.id;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('소그룹을 만드는 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.'),
          ),
        );
      }
      return null;
    }
  }

  Future<String> _generateUniqueInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 헷갈리는 문자 제외
    final rand = Random();

    while (true) {
      final code = List.generate(
        6,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();

      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('invite_code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return code;
      }
    }
  }

  Future<void> _openJoinGroupSheet() async {
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 로그인 정보가 준비되지 않았습니다.\n잠시 후 다시 시도해 주시면 감사하겠습니다.'),
        ),
      );
      return;
    }

    final codeController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: bottomInset + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '초대 코드를 입력해 주세요.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '초대 코드 (6자리)',
                  hintText: '예: ABC123',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('조용히 닫기'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final code = codeController.text.trim().toUpperCase();
                      if (code.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('초대 코드는 6자리로 입력해 주시면 됩니다.'),
                          ),
                        );
                        return;
                      }

                      final joinedGroupId =
                          await _joinGroupWithCode(uid: uid, code: code);
                      if (!mounted) return;

                      Navigator.of(context).pop();

                      if (joinedGroupId != null) {
                        setState(() {
                          _selectedGroupId = joinedGroupId;
                        });
                      }
                    },
                    child: const Text('소그룹 참여하기'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _joinGroupWithCode({
    required String uid,
    required String code,
  }) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('groups')
          .where('invite_code', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('해당 초대 코드를 가진 소그룹을 찾지 못했습니다.\n코드를 다시 한 번만 확인해 주시겠어요?'),
            ),
          );
        }
        return null;
      }

      final groupDoc = query.docs.first;
      final now = DateTime.now();

      await groupDoc.reference.update({
        'member_uids': FieldValue.arrayUnion([uid]),
        'updated_at': now,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(
        {
          'group_ids': FieldValue.arrayUnion([groupDoc.id]),
          'updated_at': now,
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('소그룹 "${groupDoc.data()['name'] ?? ''}" 에 함께 하게 되었습니다.'),
          ),
        );
      }

      return groupDoc.id;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('소그룹에 참여하는 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.'),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _leaveGroup({
    required String groupId,
    required bool isOwner,
    required int memberCount,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    if (isOwner && memberCount > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 함께하고 있는 소그룹원이 있어서,\n관리자는 바로 나갈 수 없습니다.\n먼저 멤버 관리에서 다른 분들을 내보내 주세요.'),
        ),
      );
      return;
    }

    try {
      final groupRef =
          FirebaseFirestore.instance.collection('groups').doc(groupId);
      final now = DateTime.now();

      await groupRef.update({
        'member_uids': FieldValue.arrayRemove([uid]),
        'updated_at': now,
      });

      if (memberCount <= 1) {
        // 나가고 나면 더 이상 남는 사람이 없다면 그룹을 정리합니다.
        await groupRef.delete();
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'group_ids': FieldValue.arrayRemove([groupId]),
          'updated_at': now,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _selectedGroupId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('소그룹에서 조용히 나왔습니다.\n함께했던 시간을 기억하며, 앞으로도 주님 안에서 평안하시길 기도합니다.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('소그룹을 나오는 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: AppBanner.totalHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                Expanded(
                  child: uid == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '아직 로그인 정보가 준비되지 않았습니다.\n'
                  '잠시 후 다시 들어와 주시면 감사하겠습니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, userSnap) {
                final orderedGroupIds = (userSnap.data?.data()?['group_ids'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList();
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                height: 48,
                                child: _GroupSelector(
                                  uid: uid,
                                  selectedGroupId: _selectedGroupId,
                                  orderedGroupIds: orderedGroupIds,
                                  onGroupChanged: (groupId) {
                                    setState(() {
                                      _selectedGroupId = groupId;
                                    });
                                  },
                                  onSettingsTap: null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: _selectedGroupId != null
                                  ? () {
                                      Navigator.push<void>(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => GroupSettingsLandingPage(
                                            uid: uid,
                                            onCreateTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => _openCreateGroupSheet()),
                                            onJoinTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => _openJoinGroupSheet()),
                                            onLeaveGroup: (groupId, isOwner, memberCount) =>
                                                _leaveGroup(groupId: groupId, isOwner: isOwner, memberCount: memberCount),
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              behavior: HitTestBehavior.opaque,
                              child: Tooltip(
                                message: '소그룹 설정',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Icon(
                                    Icons.settings_rounded,
                                    size: 24,
                                    color: _selectedGroupId != null
                                        ? AppTheme.textMedium
                                        : AppTheme.textMedium.withValues(
                                            alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _selectedGroupId == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '아직 함께하는 소그룹이 없거나,\n선택된 소그룹이 없습니다.\n\n'
                              '상단에서 소그룹을 선택하시거나,\n새로운 소그룹을 만들어 보셔도 좋습니다.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                          : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: _WeekNavigator(
                                weekOffset: _weekOffset,
                                onPrev: () => setState(() => _weekOffset--),
                                onNext: _weekOffset < 0
                                    ? () => setState(() => _weekOffset++)
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: _GroupPrayersList(
                                groupId: _selectedGroupId!,
                                weekRange: getWeekRange(_weekOffset),
                              ),
                            ),
                          ],
                        ),
                    ),
                  ],
                );
              },
            ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBanner(
              titleLeft: '소그룹',
              titleRight: '기도',
              subtitle: '우리의 기도를 켜는 시간',
              onNotification: widget.onNotification,
              onProfile: widget.onProfile,
              notificationCount: widget.notificationCount,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 소그룹 설정 랜딩 (새 소그룹 만들기 / 참여하기 / 관리하기) ─────
class GroupSettingsLandingPage extends StatelessWidget {
  const GroupSettingsLandingPage({
    super.key,
    required this.uid,
    required this.onCreateTap,
    required this.onJoinTap,
    required this.onLeaveGroup,
  });

  final String uid;
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  final Future<void> Function(String groupId, bool isOwner, int memberCount) onLeaveGroup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('소그룹 설정'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textDark,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: AppTheme.cardDecorationFor(context),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) => onCreateTap());
              },
              borderRadius: BorderRadius.circular(24),
              child: ListTile(
                leading: Icon(Icons.group_add_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                title: const Text(
                  '새 소그룹 만들기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '새로운 소그룹을 만들어 함께 기도해 보세요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: AppTheme.cardDecorationFor(context),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) => onJoinTap());
              },
              borderRadius: BorderRadius.circular(24),
              child: ListTile(
                leading: Icon(Icons.qr_code_2_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                title: const Text(
                  '새 소그룹 참여하기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '초대 코드로 이미 있는 소그룹에 참여해 보세요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: AppTheme.cardDecorationFor(context),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => _GroupManagePage(
                      uid: uid,
                      onLeaveGroup: onLeaveGroup,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: ListTile(
                leading: Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                title: const Text(
                  '소그룹 관리하기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '참여 중인 소그룹 목록과 순서를 관리합니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 참여중인 소그룹 목록 (길게 눌러 순서 변경, 짧게 눌러 개별 설정) ─────
class _GroupManagePage extends StatefulWidget {
  const _GroupManagePage({
    required this.uid,
    required this.onLeaveGroup,
  });

  final String uid;
  final Future<void> Function(String groupId, bool isOwner, int memberCount) onLeaveGroup;

  @override
  State<_GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<_GroupManagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('참여중인 소그룹'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textDark,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
        builder: (context, userSnap) {
          final groupIds = (userSnap.data?.data()?['group_ids'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];

          if (groupIds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '참여 중인 소그룹이 없습니다.\n소그룹 설정에서 새 소그룹을 만들거나 참여해 보세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .where(FieldPath.documentId, whereIn: groupIds.length > 10 ? groupIds.take(10).toList() : groupIds)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              final idToDoc = {for (var d in docs) d.id: d};
              final ordered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              for (final id in groupIds) {
                final d = idToDoc[id];
                if (d != null) ordered.add(d);
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: ordered.length,
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 8,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: child,
                    ),
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final newIds = List<String>.from(groupIds);
                  final id = newIds.removeAt(oldIndex);
                  newIds.insert(newIndex, id);
                  FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                    'group_ids': newIds,
                    'updated_at': DateTime.now(),
                  });
                },
                itemBuilder: (context, index) {
                  final doc = ordered[index];
                  final data = doc.data();
                  final name = (data['name'] as String?)?.trim().isNotEmpty == true
                      ? (data['name'] as String).trim()
                      : '소그룹';
                  final groupId = doc.id;
                  return Padding(
                    key: ValueKey(groupId),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: AppTheme.cardDecorationFor(context),
                      child: InkWell(
                        onTap: () async {
                            final left = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute<bool>(
                                builder: (_) => GroupSettingsPage(
                                  groupId: groupId,
                                  currentUid: widget.uid,
                                  onLeaveGroup: (gid, isOwner, memberCount) =>
                                      widget.onLeaveGroup(gid, isOwner, memberCount),
                                ),
                              ),
                            );
                            if (left == true && mounted) setState(() {});
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: AppTheme.textMedium,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(name, overflow: TextOverflow.ellipsis),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── 소그룹 설정 화면 공통 카드 래퍼 ─────────────────────────────────────
Widget _buildSettingsCard({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  Color? iconColor,
  Color? cardColor,
  Color? titleColor,
  Color? subtitleColor,
  VoidCallback? onTap,
  Widget? trailing,
  Widget? customChild,
}) {
  final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.primary;
  final effectiveTitleColor = titleColor ?? Theme.of(context).colorScheme.primary;
  final effectiveSubtitleColor = subtitleColor ?? AppTheme.textMedium;
  final effectiveTrailing = trailing ?? const Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium);

  final content = customChild ??
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: effectiveIconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: effectiveTitleColor,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: effectiveSubtitleColor,
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing else effectiveTrailing,
          ],
        ),
      );

  final card = Container(
    clipBehavior: Clip.antiAlias,
    decoration: cardColor != null
        ? BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: cardColor == AppTheme.errorRedBg
                  ? AppTheme.errorRed.withValues(alpha: 0.4)
                  : AppTheme.border.withValues(alpha: 0.4),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          )
        : AppTheme.cardDecorationFor(context),
    child: onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: content,
          )
        : content,
  );

  return card;
}

// ── 소그룹 설정 화면 (개별: 이름수정/초대코드/멤버/나가기) ─────────────────────
class GroupSettingsPage extends StatelessWidget {
  const GroupSettingsPage({
    super.key,
    required this.groupId,
    required this.currentUid,
    required this.onLeaveGroup,
  });

  final String groupId;
  final String currentUid;
  final Future<void> Function(String groupId, bool isOwner, int memberCount) onLeaveGroup;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('소그룹 설정')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final actualName =
            (data['name'] as String?)?.trim().isNotEmpty == true
                ? (data['name'] as String).trim()
                : '소그룹';
        final inviteCode = (data['invite_code'] as String?) ?? '';
        final ownerUid = data['owner_uid'] as String? ?? '';
        final memberUids = (data['member_uids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final isOwner = ownerUid == currentUid;
        final memberCount = memberUids.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(actualName, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.transparent,
            foregroundColor: AppTheme.textDark,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // 이름 수정
              _NameEditCard(
                groupId: groupId,
                currentUid: currentUid,
                actualGroupName: actualName,
              ),
              const SizedBox(height: 16),
              // 초대 코드
              _buildSettingsCard(
                context: context,
                icon: Icons.key_rounded,
                title: '초대 코드',
                subtitle: inviteCode.isEmpty ? '—' : inviteCode,
                customChild: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.key_rounded, size: 24, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '초대 코드',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              inviteCode.isEmpty ? '—' : inviteCode,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMedium,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: inviteCode.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                    ClipboardData(text: inviteCode));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '초대 코드가 클립보드에 복사되었습니다.\n함께 기도할 분들과 나눠 보셔도 좋겠습니다.'),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('복사'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 멤버 관리 / 멤버 목록
              _buildSettingsCard(
                context: context,
                icon: Icons.people_rounded,
                title: isOwner ? '멤버 관리' : '멤버 목록',
                subtitle: '함께하는 멤버 $memberCount명',
                onTap: () {
                  _openGroupMemberSheet(
                    context: context,
                    groupId: groupId,
                    ownerUid: ownerUid,
                    memberUids: memberUids,
                    currentUid: currentUid,
                    canManage: isOwner,
                  );
                },
              ),
              const SizedBox(height: 48),
              // 소그룹 나가기
              _buildSettingsCard(
                context: context,
                icon: Icons.logout_rounded,
                title: '이 소그룹 나가기',
                subtitle: '이 소그룹의 기도 제목 목록에 더 이상 접근할 수 없습니다.',
                iconColor: AppTheme.errorRed,
                cardColor: AppTheme.errorRedBg,
                titleColor: AppTheme.errorRed,
                subtitleColor: AppTheme.errorRed,
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.errorRed),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text('소그룹을 나가시겠어요?'),
                      content: const Text(
                          '나가시면 이 소그룹의 기도 제목 목록에 더 이상 접근할 수 없습니다.\n'
                          '함께했던 시간을 기억하며, 앞으로도 주님 안에서 평안하시길 기도합니다.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('머무르기'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(
                            '나가기',
                            style: const TextStyle(
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  await onLeaveGroup(groupId, isOwner, memberCount);
                  if (context.mounted) Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 이름 수정 카드 (소그룹 이름·사용자 닉네임 개인 표시 오버라이드) ─────
class _NameEditCard extends StatelessWidget {
  const _NameEditCard({
    required this.groupId,
    required this.currentUid,
    required this.actualGroupName,
  });

  final String groupId;
  final String currentUid;
  final String actualGroupName;

  Future<void> _openEditSheet(BuildContext context) async {
    String? customGroupName;
    String? customMyName;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('group_display_prefs')
        .doc(groupId)
        .get()
        .then((d) {
      if (d.exists) {
        customGroupName = (d.data()?['group_name'] as String?)?.trim();
        customMyName = (d.data()?['my_nickname'] as String?)?.trim();
      }
    });
    String? baseNickname;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get()
        .then((d) {
      baseNickname = (d.data()?['nickname'] as String?)?.trim();
    });

    if (!context.mounted) return;
    final groupController = TextEditingController(
        text: customGroupName?.isNotEmpty == true ? customGroupName : actualGroupName);
    final nameController = TextEditingController(
        text: customMyName?.isNotEmpty == true ? customMyName : (baseNickname ?? ''));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: bottomInset + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이름 수정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '다른 사람에게는 적용되지 않고, 나에게만 보입니다.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMedium,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: groupController,
                decoration: const InputDecoration(
                  labelText: '소그룹 이름',
                  hintText: '이 소그룹을 나만 이렇게 부르기',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '내 이름',
                  hintText: '이 소그룹에서 나를 이렇게 부르기',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final g = groupController.text.trim();
                      final n = nameController.text.trim();
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUid)
                          .collection('group_display_prefs')
                          .doc(groupId)
                          .set({
                        'group_name': g.isEmpty ? null : g,
                        'my_nickname': n.isEmpty ? null : n,
                        'updated_at': DateTime.now(),
                      }, SetOptions(merge: true));
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('저장되었습니다. 나에게만 적용됩니다.')),
                        );
                      }
                    },
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('group_display_prefs')
          .doc(groupId)
          .snapshots(),
      builder: (context, prefsSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, userSnap) {
            final prefs = prefsSnap.data?.data();
            final customGroup = (prefs?['group_name'] as String?)?.trim();
            final customName = (prefs?['my_nickname'] as String?)?.trim();
            final baseNick = (userSnap.data?.data()?['nickname'] as String?)?.trim();

            final displayGroup = customGroup?.isNotEmpty == true ? customGroup! : actualGroupName;
            final displayName = customName?.isNotEmpty == true ? customName! : (baseNick ?? '(이름 없음)');

            return _buildSettingsCard(
              context: context,
              icon: Icons.edit_rounded,
              title: '이름 수정',
              subtitle: '$displayGroup · $displayName',
              onTap: () => _openEditSheet(context),
            );
          },
        );
      },
    );
  }
}

// ── 주간 네비게이터 (my_room_page 상단 바와 동일 스타일) ─────────────────────────────
// const Color _weekBarAccent = AppTheme.primary;

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.weekOffset,
    required this.onPrev,
    this.onNext,
  });

  final int weekOffset;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final range = getWeekRange(weekOffset);
    final label = formatWeekLabel(range);
    final isCurrentWeekNow = isCurrentWeek(weekOffset);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: '이전 주',
            color: AppTheme.textDark,
            style: IconButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (isCurrentWeekNow)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '이번 주',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: onNext != null ? AppTheme.textDark : AppTheme.textMedium,
            ),
            tooltip: '다음 주',
            style: IconButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.uid,
    required this.selectedGroupId,
    required this.onGroupChanged,
    this.onSettingsTap,
    this.orderedGroupIds,
  });

  final String uid;
  final String? selectedGroupId;
  final List<String>? orderedGroupIds;
  final ValueChanged<String?> onGroupChanged;
  final void Function(String groupId)? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final useOrder = orderedGroupIds != null && orderedGroupIds!.isNotEmpty;
    final query = useOrder
        ? FirebaseFirestore.instance
            .collection('groups')
            .where(FieldPath.documentId, whereIn: orderedGroupIds!.length > 10 ? orderedGroupIds!.take(10).toList() : orderedGroupIds)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('groups')
            .where('member_uids', arrayContains: uid)
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            '소그룹 정보를 불러오는 중입니다. 잠시만 기다려 주세요.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMedium),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('소그룹을 불러오는 중입니다...'),
            ],
          );
        }

        var groups = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (useOrder && orderedGroupIds != null) {
          final idToIndex = {for (var i = 0; i < orderedGroupIds!.length; i++) orderedGroupIds![i]: i};
          groups = List.from(groups)
            ..sort((a, b) => (idToIndex[a.id] ?? 999).compareTo(idToIndex[b.id] ?? 999));
        }
        if (groups.isEmpty) {
          return Text(
            '아직 함께하는 소그룹이 없습니다.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMedium),
          );
        }

        final firstId = groups.first.id;
        final currentSelectedId = selectedGroupId ?? firstId;
        if (selectedGroupId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onGroupChanged(firstId);
          });
        }

        String currentName = (groups.firstWhere(
          (g) => g.id == currentSelectedId,
          orElse: () => groups.first,
        ).data()['name'] as String?) ??
            '이름 없는 소그룹';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return _GroupSelectBottomSheet(
                        groups: groups,
                        currentSelectedId: currentSelectedId,
                      );
                    },
                  );
                  if (selected != null && selected != currentSelectedId) {
                    onGroupChanged(selected);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        currentName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppTheme.textMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onSettingsTap != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => onSettingsTap!(currentSelectedId),
                icon: const Icon(Icons.settings_rounded),
                tooltip: '소그룹 설정',
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.textMedium,
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GroupSelectBottomSheet extends StatefulWidget {
  const _GroupSelectBottomSheet({
    required this.groups,
    required this.currentSelectedId,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> groups;
  final String currentSelectedId;

  @override
  State<_GroupSelectBottomSheet> createState() =>
      _GroupSelectBottomSheetState();
}

class _GroupSelectBottomSheetState extends State<_GroupSelectBottomSheet> {
  String _query = '';
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentSelectedId;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final filtered = widget.groups.where((doc) {
      final data = doc.data();
      final name = (data['name'] as String?) ?? '';
      if (_query.trim().isEmpty) return true;
      return name.contains(_query.trim());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: media.viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '소그룹 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(_selectedId);
                    },
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '함께 기도할 소그룹을 선택하세요.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: '그룹명 검색',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  filled: true,
                  fillColor: AppTheme.bgLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) {
                  setState(() => _query = v);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final name =
                        (data['name'] as String?) ?? '이름 없는 소그룹';
                    final memberUids =
                        (data['member_uids'] as List<dynamic>?) ?? const [];
                    final memberCount = memberUids.length;
                    final isSelected = doc.id == _selectedId;
                    final initial = name.trim().isNotEmpty
                        ? name.trim().characters.first
                        : 'G';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          setState(() {
                            _selectedId = doc.id;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFF5E6)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.border,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppTheme.primary
                                              : AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$memberCount명',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupPrayersList extends StatelessWidget {
  const _GroupPrayersList({
    required this.groupId,
    required this.weekRange,
  });

  final String groupId;
  final WeekRange weekRange;

  DateTime _todt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    // 현재 그룹 멤버 목록을 실시간으로 구독 (탈퇴 사용자 판별용)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .snapshots(),
      builder: (context, groupSnapshot) {
        final memberUids =
            ((groupSnapshot.data?.data()?['member_uids'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toSet()) ??
                const <String>{};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('group_prayers')
              .where('group_id', isEqualTo: groupId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '함께 나눈 기도 제목을 불러오는 중에\n잠시 어려움이 있었습니다.\n\n'
                    '조금 뒤에 다시 시도해 주시면 감사하겠습니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 주간 필터링 (client-side, created_at 기준)
            final allDocs = snapshot.data?.docs ?? const [];
            final filtered = allDocs.where((doc) {
              final created = _todt(doc.data()['created_at']);
              return !created.isBefore(weekRange.start) &&
                  !created.isAfter(weekRange.end);
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '이번 주에 공유된 기도 제목이 없습니다.\n'
                    '나의 상황을 소그룹에 기도 요청 해보세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            // 핀 우선, 그 다음 최신순 정렬
            filtered.sort((a, b) {
              final aPinned = (a.data()['is_pinned'] as bool?) ?? false;
              final bPinned = (b.data()['is_pinned'] as bool?) ?? false;
              if (aPinned != bPinned) return aPinned ? -1 : 1;
              return _todt(b.data()['created_at'])
                  .compareTo(_todt(a.data()['created_at']));
            });

            return ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 120),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                final gpDoc = filtered[index];
                final data = gpDoc.data();
                final prayerId = data['prayer_id'] as String?;

                if (prayerId == null || prayerId.isEmpty) {
                  return const SizedBox.shrink();
                }

                return _GroupPrayerTile(
                  prayerId: prayerId,
                  groupPrayerId: gpDoc.id,
                  groupPrayerData: data,
                  currentMemberUids: memberUids,
                  currentUid:
                      FirebaseAuth.instance.currentUser?.uid ?? '',
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GroupPrayerTile extends StatelessWidget {
  const _GroupPrayerTile({
    required this.prayerId,
    required this.groupPrayerId,
    required this.groupPrayerData,
    required this.currentMemberUids,
    required this.currentUid,
  });

  final String prayerId;
  final String groupPrayerId;
  final Map<String, dynamic> groupPrayerData;
  final Set<String> currentMemberUids;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final title = (groupPrayerData['title'] as String?)?.trim() ?? '';
    final content = (groupPrayerData['content'] as String?)?.trim() ?? '';
    final ownerUid = (groupPrayerData['owner_uid'] as String?) ?? '';
    final fallbackNickname =
        (groupPrayerData['owner_nickname'] as String?)?.trim() ?? '';
    final statusRaw = groupPrayerData['status'] as String?;
    final statusLabel = _statusLabel(statusRaw);
    final statusBg = _statusBg(statusRaw);

    final createdAt = groupPrayerData['created_at'];
    DateTime? createdAtTime;
    if (createdAt is Timestamp) {
      createdAtTime = createdAt.toDate();
    } else if (createdAt is DateTime) {
      createdAtTime = createdAt;
    }

    final holdCount = (groupPrayerData['hold_count'] as int?) ?? 0;
    final isPinned = (groupPrayerData['is_pinned'] as bool?) ?? false;
    final heldByUids = (groupPrayerData['held_by_uids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final prayedByMe = currentUid.isNotEmpty && heldByUids.contains(currentUid);

    final isFormerMember = currentMemberUids.isNotEmpty &&
        ownerUid.isNotEmpty &&
        !currentMemberUids.contains(ownerUid);
    final nickname = isFormerMember
        ? '탈퇴한 사용자'
        : (fallbackNickname.isNotEmpty ? fallbackNickname : '사용자');

    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작성자 닉네임 + 핀 버튼
                Row(
                  children: [
                    if (nickname.isNotEmpty) ...[
                      Icon(
                        isFormerMember
                            ? Icons.person_off_outlined
                            : Icons.person_outline_rounded,
                        size: 14,
                        color: isFormerMember
                            ? AppTheme.textMedium.withValues(alpha: 0.6)
                            : AppTheme.textMedium,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        nickname,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: isFormerMember
                                  ? AppTheme.textMedium.withValues(alpha: 0.6)
                                  : AppTheme.textMedium,
                              fontStyle: isFormerMember
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _toggleGroupPrayerPin(groupPrayerId, isPinned, context),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isPinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          size: 18,
                          color: isPinned
                              ? Theme.of(context).colorScheme.primary
                              : AppTheme.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                if (nickname.isNotEmpty) const SizedBox(height: 6),
                // 제목 + 상태 칩
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title.isEmpty ? '(제목 없음)' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _statusFg(statusRaw),
                        ),
                      ),
                    ),
                  ],
                ),
                // 내용
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ExpandableText(text: content),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (createdAtTime != null)
                      Text(
                        _formatDate(createdAtTime),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppTheme.textMedium),
                      ),
                    const Spacer(),
                    _HoldPrayerButton(
                      groupPrayerId: groupPrayerId,
                      holdCount: holdCount,
                      currentUid: currentUid,
                      prayedByMe: prayedByMe,
                    ),
                  ],
                ),
              ],
            ),
          );
  }

  Future<void> _toggleGroupPrayerPin(
      String gpId, bool currentPinned, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('group_prayers')
          .doc(gpId)
          .update({
        'is_pinned': !currentPinned,
        'updated_at': DateTime.now(),
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고정 설정 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.'),
        ),
      );
    }
  }

  String _statusLabel(String? raw) {
    switch (raw) {
      case 'praying':   return '기도 중';
      case 'answered': return '응답 받음';
      case 'waiting':  return '기다리는 중';
      case 'refocused': return '방향 전환';
      case 'resting':  return '잠시 멈춤';
      case 'in_progress': return '방향 전환';
      default:         return '기도 중';
    }
  }

  Color _statusBg(String? raw) {
    // HTML 디자인 컨셉 status-pill 배경색
    switch (raw) {
      case 'praying':     return AppTheme.statusPrayingBg;
      case 'answered':    return AppTheme.statusRespondedBg;
      case 'waiting':     return AppTheme.statusWaitingBg;
      case 'refocused':   return AppTheme.statusPartialBg;
      case 'resting':     return AppTheme.statusGratitudeBg;
      case 'in_progress': return AppTheme.statusPartialBg;
      default:            return AppTheme.statusPrayingBg;
    }
  }

  Color _statusFg(String? raw) {
    switch (raw) {
      case 'praying':     return AppTheme.statusPrayingFg;
      case 'answered':    return AppTheme.statusRespondedFg;
      case 'waiting':     return AppTheme.statusWaitingFg;
      case 'refocused':   return AppTheme.statusPartialFg;
      case 'resting':     return AppTheme.statusGratitudeFg;
      case 'in_progress': return AppTheme.statusPartialFg;
      default:            return AppTheme.statusPrayingFg;
    }
  }
}

/// cross_prayer_note 스타일: 🙏 기도했어요 + 카운트, 미선택/선택 시 테두리·배경·폰트 구분
class _HoldPrayerButton extends StatelessWidget {
  const _HoldPrayerButton({
    required this.groupPrayerId,
    required this.holdCount,
    required this.currentUid,
    required this.prayedByMe,
  });

  final String groupPrayerId;
  final int holdCount;
  final String currentUid;
  final bool prayedByMe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (groupPrayerId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('기도 붙들기 정보를 찾지 못했습니다.')),
          );
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        try {
          final ref = FirebaseFirestore.instance
              .collection('group_prayers')
              .doc(groupPrayerId);

          final updates = <String, dynamic>{
            'hold_count': FieldValue.increment(1),
            'last_held_at': DateTime.now(),
          };
          if (currentUid.isNotEmpty) {
            updates['held_by_uids'] = FieldValue.arrayUnion([currentUid]);
          }

          await ref.update(updates);
          debugPrint('[기도 붙들기] gpId=$groupPrayerId uid=$currentUid');

          messenger.showSnackBar(
            const SnackBar(
                content:
                    Text('예수님의 이름으로 기도합니다. 아멘.')),
          );
        } catch (e) {
          debugPrint('[기도 붙들기] 오류: $e');
          messenger.showSnackBar(
            const SnackBar(
                content: Text(
                    '기도를 붙드는 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.')),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: prayedByMe
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🙏', style: TextStyle(fontSize: 10)),
            if (holdCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$holdCount',
                style: TextStyle(
                  fontSize: 10,
                  color: prayedByMe
                      ? Theme.of(context).colorScheme.primary
                      : AppTheme.textLight,
                  fontWeight:
                      prayedByMe ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y.$m.$d';
}

// ── 더보기 토글 텍스트 ──────────────────────────
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;
  static const int maxLines = 4;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: _ExpandableText.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflow = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: Text(
                widget.text,
                maxLines: _expanded ? null : _ExpandableText.maxLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            if (isOverflow || _expanded) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? '접기' : '더보기',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

