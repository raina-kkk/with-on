import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/notification_service.dart';
import 'my_prayer_hold_summary.dart';
import '../widgets/app_banner.dart';

// HTML 디자인 컨셉 기반 기도 상태 Pill 배경색
const Color _statusPraying = AppTheme.statusPrayingBg;
const Color _statusAnswered = AppTheme.statusRespondedBg;
const Color _statusWaiting = AppTheme.statusWaitingBg;
const Color _statusRefocused = AppTheme.statusPartialBg;
const Color _statusResting = AppTheme.statusGratitudeBg;

// [비교용] 기존 기도 상태 Chip 색상 (나의 골방 카드·수정 시 선택 칩 비교 시 참고)
// 아래로 바꾸면 예전 밝은 톤으로 복원 가능.
// const Color _statusPrayingLegacy   = Color(0xFFF5E6D7);  // 따뜻한 베이지
// const Color _statusAnsweredLegacy = Color(0xFFFFE8A3);  // 골드 (기존 accentYellow)
// const Color _statusWaitingLegacy  = Color(0xFFD7EAF5);   // 연한 하늘
// const Color _statusRefocusedLegacy = Color(0xFFE8DDF5);  // 연한 보라
// const Color _statusRestingLegacy  = Color(0xFFEBE8E4);   // 연한 그레이

// ──────────────────────────────────────────
// 상태 정의 및 UI 헬퍼
// ──────────────────────────────────────────

/// 기도 상태 (5종) — Firestore 'status' 필드와 동기화
/// 표시 순서: 기도 중 → 기다리는 중 → 응답 받음 → 방향 전환 → 잠시 멈춤
enum PrayerStatus {
  praying,   // 🙏 기도 중
  waiting,  // ⏳ 기다리는 중
  answered, // ✨ 응답 받음
  refocused,// ⤵️ 방향 전환
  resting,  // ⏸️ 잠시 멈춤
}

extension PrayerStatusX on PrayerStatus {
  String get key {
    switch (this) {
      case PrayerStatus.praying:   return 'praying';
      case PrayerStatus.waiting:  return 'waiting';
      case PrayerStatus.answered: return 'answered';
      case PrayerStatus.refocused: return 'refocused';
      case PrayerStatus.resting:  return 'resting';
    }
  }

  String get label {
    switch (this) {
      case PrayerStatus.praying:   return '기도 중';
      case PrayerStatus.waiting:  return '기다리는 중';
      case PrayerStatus.answered: return '응답 받음';
      case PrayerStatus.refocused: return '방향 전환';
      case PrayerStatus.resting:  return '잠시 멈춤';
    }
  }

  /// cross_prayer_note 스타일 아이콘
  String get icon {
    switch (this) {
      case PrayerStatus.praying:   return '🙏';
      case PrayerStatus.waiting:  return '⏳';
      case PrayerStatus.answered: return '✨';
      case PrayerStatus.refocused: return '⤵️';
      case PrayerStatus.resting:  return '⏸️';
    }
  }

  Color get bgColor {
    switch (this) {
      case PrayerStatus.praying:   return _statusPraying;
      case PrayerStatus.waiting:  return _statusWaiting;
      case PrayerStatus.answered: return _statusAnswered;
      case PrayerStatus.refocused: return _statusRefocused;
      case PrayerStatus.resting:  return _statusResting;
    }
  }

  /// 선택된 칩의 테두리·폰트용 강조색 (cross_prayer_note와 동일 톤)
  Color get color {
    switch (this) {
      case PrayerStatus.praying:   return AppTheme.statusPraying;
      case PrayerStatus.waiting:  return AppTheme.statusWaiting;
      case PrayerStatus.answered: return AppTheme.statusResponded;
      case PrayerStatus.refocused: return AppTheme.statusPartial;
      case PrayerStatus.resting:  return AppTheme.statusGratitude;
    }
  }

  /// HTML status-pill 전경색
  Color get fgColor {
    switch (this) {
      case PrayerStatus.praying:   return AppTheme.statusPrayingFg;
      case PrayerStatus.waiting:  return AppTheme.statusWaitingFg;
      case PrayerStatus.answered: return AppTheme.statusRespondedFg;
      case PrayerStatus.refocused: return AppTheme.statusPartialFg;
      case PrayerStatus.resting:  return AppTheme.statusGratitudeFg;
    }
  }
}

PrayerStatus prayerStatusFrom(String? raw) {
  switch (raw) {
    case 'praying':   return PrayerStatus.praying;
    case 'answered':  return PrayerStatus.answered;
    case 'waiting':   return PrayerStatus.waiting;
    case 'refocused': return PrayerStatus.refocused;
    case 'resting':   return PrayerStatus.resting;
    // 레거시 저장값 호환
    case 'in_progress': return PrayerStatus.refocused;
    default:          return PrayerStatus.praying;
  }
}

// ──────────────────────────────────────────
// 페이지
// ──────────────────────────────────────────

class MyRoomPage extends StatefulWidget {
  const MyRoomPage({super.key, this.onRegisterAddPrayer, this.onProfile});

  /// 메인 리본의 '+' 버튼에서 새 기도 시트를 열 때 사용
  final void Function(VoidCallback openAddPrayer)? onRegisterAddPrayer;
  /// 배너 우측 프로필 버튼 탭 시 (예: 통계 페이지로 이동)
  final VoidCallback? onProfile;

  @override
  State<MyRoomPage> createState() => _MyRoomPageState();
}

class _MyRoomPageState extends State<MyRoomPage> {
  bool _isSaving = false;
  String _searchQuery = '';
  DateTime? _selectedDate;
  final _searchController = TextEditingController();
  /// 알림 탭으로 진입 시 응답 받음만 보기
  PrayerStatus? _statusFilter;
  bool _pendingPayloadHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNotificationPayload();
      widget.onRegisterAddPrayer?.call(_openAddPrayerSheet);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 알림(응답 10개 / 100일) 탭 시 payload에 따라 필터 또는 기도 상세 열기
  Future<void> _handlePendingNotificationPayload() async {
    if (_pendingPayloadHandled) return;
    final payload = NotificationService.getAndClearPendingPayload();
    if (payload == null || payload.isEmpty) return;
    _pendingPayloadHandled = true;
    if (payload == 'answered_10') {
      if (mounted) setState(() => _statusFilter = PrayerStatus.answered);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('응답을 받은 기도 제목만 보여드려요.')),
        );
      }
      return;
    }
    if (payload.startsWith('praying_100_')) {
      final prayerId = payload.replaceFirst('praying_100_', '');
      if (prayerId.isNotEmpty) await _openEditPrayerSheetById(prayerId);
    }
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // 현재 로그인된 유저의 닉네임을 Firestore에서 가져옵니다.
  Future<String> _fetchNickname() async {
    final uid = _uid;
    if (uid == null) return '';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return (doc.data()?['nickname'] as String?) ?? '';
  }

  Query<Map<String, dynamic>> _myPrayersQuery() {
    final uid = _uid;
    if (uid == null) {
      return FirebaseFirestore.instance
          .collection('prayers')
          .where('owner_uid', isEqualTo: '__missing_uid__');
    }
    return FirebaseFirestore.instance
        .collection('prayers')
        .where('owner_uid', isEqualTo: uid);
  }

  // ── 새 기도 작성 ──────────────────────────
  Future<void> _openAddPrayerSheet() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    PrayerStatus selectedStatus = PrayerStatus.praying;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 20,
                bottom: bottomInset + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('새 기도 제목을 기록해 볼까요?',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'NotoSerifKR',
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkPrimary
                              : AppTheme.textDark)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '기도 제목',
                      hintText: '마음에 떠오르는 기도 제목을 짧게 적어 주세요.',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '기도 내용',
                      hintText: '나중에 응답을 돌아볼 수 있도록,\n조금 더 구체적으로 적어 두셔도 좋습니다.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16))),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StatusSelector(
                    current: selectedStatus,
                    onChanged: (s) => setSheetState(() => selectedStatus = s),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('기도 제목을 한 줄만이라도 적어 주시면 감사하겠습니다.')),
                            );
                            return;
                          }
                          await _savePrayer(
                            title: title,
                            content: content,
                            status: selectedStatus,
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('기도로 올려드립니다'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── 기도 수정 (목록에서 탭) ──────────────────────────────
  Future<void> _openEditPrayerSheet(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    await _openEditPrayerSheetWithData(doc.id, doc.data());
  }

  /// 알림(100일) 탭 시 기도 상세 열기용
  Future<void> _openEditPrayerSheetById(String docId) async {
    final snap = await FirebaseFirestore.instance
        .collection('prayers')
        .doc(docId)
        .get();
    if (!snap.exists || snap.data() == null || !mounted) return;
    await _openEditPrayerSheetWithData(snap.id, snap.data()!);
  }

  Future<void> _openEditPrayerSheetWithData(
      String docId, Map<String, dynamic> data) async {
    final titleController =
        TextEditingController(text: (data['title'] as String?) ?? '');
    final contentController =
        TextEditingController(text: (data['content'] as String?) ?? '');
    PrayerStatus selectedStatus = prayerStatusFrom(data['status'] as String?);
    bool isPinned = (data['is_pinned'] as bool?) ?? false;
    final initialSharedIds = (data['shared_group_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    Set<String> selectedGroupIds = Set<String>.from(initialSharedIds);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: bottomInset + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '기도 제목 수정',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '기도 제목',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '기도 내용',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatusSelector(
                      current: selectedStatus,
                      onChanged: (s) => setSheetState(() => selectedStatus = s),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            await _togglePin(docId, isPinned);
                            setSheetState(() {
                              isPinned = !isPinned;
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                                color: isPinned
                                    ? Theme.of(context).colorScheme.primary
                                    : AppTheme.textLight,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '상단에 고정',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            final result = await _openGroupShareFilterSheet(
                              context: context,
                              initialSelected: selectedGroupIds,
                            );
                            if (result != null) {
                              setSheetState(() {
                                selectedGroupIds = result;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.filter_alt_outlined,
                            size: 18,
                          ),
                          label: Text(
                            selectedGroupIds.isEmpty
                                ? '소그룹에 공유하기'
                                : '소그룹 ${selectedGroupIds.length}곳',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('닫기'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final content = contentController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '기도 제목을 한 줄만이라도 적어 주시면 감사하겠습니다.'),
                                ),
                              );
                              return;
                            }
                            await _updatePrayer(
                              docId: docId,
                              title: title,
                              content: content,
                              status: selectedStatus,
                            );
                            final updatedData =
                                Map<String, dynamic>.from(data)
                                  ..['title'] = title
                                  ..['content'] = content
                                  ..['status'] = selectedStatus.key;
                            final toAdd =
                                selectedGroupIds.difference(initialSharedIds);
                            final toRemove =
                                initialSharedIds.difference(selectedGroupIds);
                            for (final groupId in toRemove) {
                              await _unsharePrayerFromGroup(docId, groupId);
                            }
                            if (toAdd.isNotEmpty) {
                              await _sharePrayerToGroups(
                                prayerId: docId,
                                data: updatedData,
                                groupIds: toAdd.toList(),
                              );
                            } else if (toRemove.isNotEmpty && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('선택하신 소그룹에서 공유가 해제되었습니다.'),
                                ),
                              );
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text('수정 완료'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Firestore 저장 ─────────────────────────
  Future<void> _savePrayer({
    required String title,
    required String content,
    required PrayerStatus status,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('로그인 정보가 확인되지 않았습니다.\n다시 로그인해 주시면 감사하겠습니다.')));
        }
        return;
      }

      final nickname = await _fetchNickname();
      final now = DateTime.now();

      await FirebaseFirestore.instance.collection('prayers').add({
        'owner_uid': user.uid,
        'owner_email': user.email ?? '',
        'owner_nickname': nickname,
        'title': title,
        'content': content,
        'status': status.key,
        'is_shared': false,
        'is_pinned': false,
        'shared_group_ids': <String>[],
        'hold_count': 1,
        'held_by_uids': [user.uid],
        'last_held_at': now,
        'created_at': now,
        'updated_at': now,
        'answered_at': status == PrayerStatus.answered ? now : null,
        'gratitude_note': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('기도 제목이 기록되었습니다. 기도의 등불을 밝혀주세요.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('잠시 연결에 어려움이 있습니다.\n조금 뒤에 다시 시도해 주세요')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Firestore 수정: prayers 문서만 업데이트하면
  //    group_prayers는 prayer_id 참조로 StreamBuilder가 자동 반영합니다.
  Future<void> _updatePrayer({
    required String docId,
    required String title,
    required String content,
    required PrayerStatus status,
  }) async {
    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('prayers').doc(docId).update({
        'title': title,
        'content': content,
        'status': status.key,
        'updated_at': now,
        'answered_at': status == PrayerStatus.answered ? now : null,
      });
      final gpSnap = await FirebaseFirestore.instance
          .collection('group_prayers')
          .where('prayer_id', isEqualTo: docId)
          .get();
      if (gpSnap.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in gpSnap.docs) {
          batch.update(doc.reference, {
            'title': title,
            'content': content,
            'status': status.key,
            'updated_at': now,
          });
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('기도 제목이 수정되었습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('수정 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.')));
      }
    }
  }

  // ── 핀 토글 ────────────────────────────────
  Future<void> _togglePin(String docId, bool currentPinned) async {
    try {
      final now = DateTime.now();
      final uid = _uid;
      if (!currentPinned) {
        int nextOrder = 0;
        if (uid != null) {
          final snap = await FirebaseFirestore.instance
              .collection('prayers')
              .where('owner_uid', isEqualTo: uid)
              .where('is_pinned', isEqualTo: true)
              .get();
          for (final d in snap.docs) {
            final v = d.data()['pin_order'];
            if (v is int && v >= nextOrder) {
              nextOrder = v + 1;
            }
          }
        }
        await FirebaseFirestore.instance.collection('prayers').doc(docId).update({
          'is_pinned': true,
          'pin_order': nextOrder,
          'updated_at': now,
        });
      } else {
        await FirebaseFirestore.instance.collection('prayers').doc(docId).update({
          'is_pinned': false,
          'pin_order': FieldValue.delete(),
          'updated_at': now,
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('고정 설정 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.')));
      }
    }
  }

  // ── 날짜 피커 ──────────────────────────────
  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.bgLight,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  /// 소그룹 공유 필터 시트 (그룹 목록을 별도 시트에서 필터처럼 선택)
  Future<Set<String>?> _openGroupShareFilterSheet({
    required BuildContext context,
    required Set<String> initialSelected,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        Set<String> tempSelected = Set<String>.from(initialSelected);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '기도 제목 공유하기',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '함께 기도하는 소그룹을 선택해 주세요. 여러 개 선택할 수 있습니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMedium,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('groups')
                        .where('member_uids', arrayContains: uid)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final groups = snapshot.data?.docs ?? [];
                      if (groups.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '참여 중인 소그룹이 없습니다.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.textMedium,
                                ),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groups.map((g) {
                          final groupId = g.id;
                          final name =
                              (g.data()['name'] as String?) ?? '이름 없는 소그룹';
                          final selected = tempSelected.contains(groupId);
                          return FilterChip(
                            selected: selected,
                            label: Text(
                              name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onSelected: (v) {
                              setSheetState(() {
                                if (v) {
                                  tempSelected.add(groupId);
                                } else {
                                  tempSelected.remove(groupId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(tempSelected),
                        child: const Text('공유'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    return result;
  }

  // HTML 디자인 컨셉: 필터 칩 색상
  // static const Color _chipActive = AppTheme.primary;
  // static const Color _chipInactiveBorder = AppTheme.border;
  static const Color _chipInactiveText = AppTheme.textLight;

  // ── 검색 바 위젯 ───────────────────────────
  Widget _buildSearchBar(BuildContext context) {
    final hasFilter = _searchQuery.isNotEmpty ||
        _selectedDate != null ||
        _statusFilter != null;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // [검색창, 날짜선택] — HTML 컨셉: 흰 배경, stone border, rounded-16
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: '기도 제목이나 내용으로 검색...',
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textMedium),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppTheme.textMedium),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  size: 18, color: AppTheme.textMedium),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 날짜 필터 버튼
                GestureDetector(
                  onTap: _openDatePicker,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedDate != null
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: _selectedDate != null
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.2)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 18,
                            color: _selectedDate != null
                                ? Theme.of(context).colorScheme.primary
                                : AppTheme.textMedium),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 5),
                          Text(
                            _formatDate(_selectedDate!),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDate = null),
                            child: Icon(Icons.close_rounded,
                                size: 14, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          // 상태 필터 칩 — 가로 스크롤, 스크롤바 숨김
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                children: [
                  _buildStatusChip(context, null, '전체'),
                  ...PrayerStatus.values.map(
                    (s) => _buildStatusChip(context, s, s.label),
                  ),
                ],
              ),
            ),
          ),
          if (hasFilter)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _buildFilterLabel(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMedium,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    PrayerStatus? status,
    String label,
  ) {
    final isActive = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : _chipInactiveText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildFilterLabel() {
    final parts = <String>[];
    if (_statusFilter != null) parts.add(_statusFilter!.label);
    if (_searchQuery.isNotEmpty) parts.add('"$_searchQuery"');
    if (_selectedDate != null) parts.add(_formatDate(_selectedDate!));
    return parts.isEmpty ? '' : '${parts.join(' · ')} ${parts.length == 1 && _statusFilter != null ? '보기' : '검색 중'}';
  }

  // ── 소그룹 새 글 알림 (종 모양) ─────────────────
  Stream<int> _unreadNotificationCountStream() {
    final uid = _uid;
    if (uid == null) return Stream<int>.value(0);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> _openNotificationsSheet() async {
    final uid = _uid;
    if (uid == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _NotificationsSheet(uid: uid),
    );
  }

  // ── 빌드 ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: AppBanner.totalHeightFor(context),
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                _buildSearchBar(context),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _myPrayersQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '잠시 기도 목록을 불러오는 데 어려움이 있었습니다.\n조금만 기다렸다가 다시 시도해 주시면 감사하겠습니다.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = [...(snapshot.data?.docs ?? const [])];
                allDocs.sort((a, b) {
                  final aPinned = (a.data()['is_pinned'] as bool?) ?? false;
                  final bPinned = (b.data()['is_pinned'] as bool?) ?? false;
                  if (aPinned != bPinned) return aPinned ? -1 : 1;
                  if (aPinned && bPinned) {
                    final aOrder = a.data()['pin_order'] as int? ?? 0;
                    final bOrder = b.data()['pin_order'] as int? ?? 0;
                    return aOrder.compareTo(bOrder);
                  }
                  final aTime = _toDateTime(a.data()['created_at']);
                  final bTime = _toDateTime(b.data()['created_at']);
                  return bTime.compareTo(aTime);
                });

                // 상태 필터 + 검색어 + 날짜 필터링
                final docs = allDocs.where((doc) {
                  final data = doc.data();
                  if (_statusFilter != null) {
                    final status = data['status'] as String?;
                    if (status != _statusFilter!.key) return false;
                  }
                  final title =
                      (data['title'] as String?)?.toLowerCase() ?? '';
                  final content =
                      (data['content'] as String?)?.toLowerCase() ?? '';
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    if (!title.contains(q) && !content.contains(q)) {
                      return false;
                    }
                  }
                  if (_selectedDate != null) {
                    final created = _toDateTime(data['created_at']);
                    final d = _selectedDate!;
                    // 해당 날짜가 속한 주(일~토)의 시작·끝
                    final startOfWeek = DateTime(d.year, d.month, d.day)
                        .subtract(Duration(days: d.weekday % 7));
                    final endOfWeek =
                        startOfWeek.add(const Duration(days: 6));
                    final createdDate =
                        DateTime(created.year, created.month, created.day);
                    final startDate = DateTime(startOfWeek.year,
                        startOfWeek.month, startOfWeek.day);
                    final endDate =
                        DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
                    if (createdDate.isBefore(startDate) ||
                        createdDate.isAfter(endDate)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                // 날짜 선택 검색 시: 날짜·시간 순(오래된 것 먼저). 그 외에는 이미 최신순 유지
                if (_selectedDate != null && docs.isNotEmpty) {
                  docs.sort((a, b) {
                    final aPinned = (a.data()['is_pinned'] as bool?) ?? false;
                    final bPinned = (b.data()['is_pinned'] as bool?) ?? false;
                    if (aPinned != bPinned) return aPinned ? -1 : 1;
                    if (aPinned && bPinned) {
                      final aOrder = a.data()['pin_order'] as int? ?? 0;
                      final bOrder = b.data()['pin_order'] as int? ?? 0;
                      return aOrder.compareTo(bOrder);
                    }
                    final aTime = _toDateTime(a.data()['created_at']);
                    final bTime = _toDateTime(b.data()['created_at']);
                    return aTime.compareTo(bTime);
                  });
                }

                // 기도 자체가 아예 없음
                if (allDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_note_rounded,
                              color: AppTheme.textMedium, size: 56),
                          const SizedBox(height: 12),
                          Text('첫 번째 기도 제목을 작성해 보세요.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                              '마음에 떠오르는 한 줄의 기도부터,\n천천히 함께 시작해도 괜찮습니다.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppTheme.textMedium)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed:
                                _isSaving ? null : _openAddPrayerSheet,
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('기도 제목 기록하기'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 필터 결과 없음
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 52,
                              color:
                                  AppTheme.textMedium.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            '찾으시는 기도 제목이 없어요.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '검색어나 날짜를 조금 바꿔\n다시 찾아보시면 어떨까요?',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textMedium),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedDate = null;
                                _statusFilter = null;
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('필터 초기화'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textMedium,
                              side: const BorderSide(
                                  color: AppTheme.textMedium),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 120),
                  itemCount: docs.length,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) async {
                    final pinnedDocs = docs
                        .where((d) =>
                            ((d.data()['is_pinned'] as bool?) ?? false) == true)
                        .toList();
                    final pinnedCount = pinnedDocs.length;
                    if (oldIndex >= pinnedCount || newIndex > pinnedCount) {
                      return;
                    }
                    if (newIndex > oldIndex) newIndex -= 1;
                    if (oldIndex == newIndex) return;
                    final reordered = List.of(pinnedDocs);
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    final batch = FirebaseFirestore.instance.batch();
                    for (var i = 0; i < reordered.length; i++) {
                      batch.update(reordered[i].reference, {'pin_order': i});
                    }
                    try {
                      await batch.commit();
                    } catch (_) {}
                  },
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final title = (data['title'] as String?)?.trim() ?? '';
                    final content = (data['content'] as String?)?.trim() ?? '';
                    final status = prayerStatusFrom(data['status'] as String?);
                    final isPinned = (data['is_pinned'] as bool?) ?? false;
                    final isShared = (data['is_shared'] as bool?) ?? false;
                    final createdAtText =
                        _formatDate(_toDateTime(data['created_at']));

                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      key: ValueKey(doc.id),
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: (isDark ? AppTheme.darkDivider : AppTheme.border).withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: Offset.zero,
                          ),
                        ],
                      ),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목 + 상태 칩
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 6, top: 2),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openEditPrayerSheet(doc),
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
                        ),
                        if (isPinned)
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4, top: 2),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                size: 18,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusChip(status: status),
                        ],
                      ),
                      // 내용
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _ExpandableText(text: content),
                      ],
                      const SizedBox(height: 12),
                      // 하단: 날짜 (좌측) + 공유 아이콘 + 기도손 (우측)
                      Row(
                        children: [
                          Text(
                            createdAtText,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: AppTheme.textMedium),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isShared) ...[
                                Icon(
                                  Icons.groups_rounded,
                                  size: 14,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 20), // 공유 아이콘 ↔ 기도손 간격
                              ],
                              MyPrayerHoldSummary(
                                prayerId: doc.id,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
              );
                  },
                );
              },
            ),
                ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: _unreadNotificationCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBanner(
                  titleLeft: '나의',
                  titleRight: '기도',
                  subtitle: '나의 기도를 켜는 시간',
                  onNotification: _openNotificationsSheet,
                  onProfile: widget.onProfile,
                  notificationCount: count,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 소그룹 공유 ────────────────────────────
  Future<void> _openShareSheetForPrayer(
      QueryDocumentSnapshot<Map<String, dynamic>> prayerDoc) async {
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('아직 로그인 정보가 준비되지 않았습니다.\n잠시 후 다시 시도해 주시면 감사하겠습니다.')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('어느 소그룹과 함께 나눌까요?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('함께 기도해 줄 소그룹을 선택해 주세요.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textMedium)),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('groups')
                      .where('member_uids', arrayContains: uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('소그룹 정보를 불러오는 중에 잠시 문제가 있었습니다.',
                              style: Theme.of(context).textTheme.bodyMedium));
                    }
                    final groups = snapshot.data?.docs ?? const [];
                    if (groups.isEmpty) {
                      return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                              '아직 함께 기도 나눔을 할 소그룹이 없습니다.\n먼저 소그룹을 만들거나 초대를 받아 참여해 주세요.',
                              style: Theme.of(context).textTheme.bodyMedium));
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final groupDoc = groups[index];
                        final name = (groupDoc.data()['name'] as String?) ??
                            '이름 없는 소그룹';
                        return ListTile(
                          title: Text(name),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _sharePrayerToGroup(
                                prayerDoc: prayerDoc, groupId: groupDoc.id);
                          },
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

  Future<void> _unsharePrayer(String prayerId) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final gpQuery = await FirebaseFirestore.instance
          .collection('group_prayers')
          .where('prayer_id', isEqualTo: prayerId)
          .where('owner_uid', isEqualTo: uid)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in gpQuery.docs) {
        batch.delete(doc.reference);
      }
      batch.update(
        FirebaseFirestore.instance.collection('prayers').doc(prayerId),
        {
          'is_shared': false,
          'shared_group_ids': <String>[],
          'updated_at': DateTime.now(),
        },
      );
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('소그룹 공유가 해제되었습니다.\n\'우리들의 손\'에서 더 이상 보이지 않습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('공유 해제 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.')));
      }
    }
  }

  Future<void> _sharePrayerToGroup({
    required QueryDocumentSnapshot<Map<String, dynamic>> prayerDoc,
    required String groupId,
  }) async {
    await _sharePrayerToGroupByData(
      prayerId: prayerDoc.id,
      data: prayerDoc.data(),
      groupId: groupId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('선택하신 소그룹에 기도 제목이 따뜻하게 나누어졌습니다.')));
    }
  }

  /// docId + data로 소그룹 1곳 공유 (수정 시트 등에서 사용)
  Future<void> _sharePrayerToGroupByData({
    required String prayerId,
    required Map<String, dynamic> data,
    required String groupId,
  }) async {
    try {
      final uid = _uid ?? (data['owner_uid'] as String? ?? '');
      final now = DateTime.now();
      final prayerTitle =
          (data['title'] as String?)?.trim().isEmpty != true
              ? (data['title'] as String?)!.trim()
              : '기도 제목';
      final prayerContent = (data['content'] as String?)?.trim() ?? '';
      final prayerStatus = (data['status'] as String?) ?? 'praying';
      final ownerNickname = (data['owner_nickname'] as String?)?.trim() ?? '';
      final ownerEmail = (data['owner_email'] as String?)?.trim() ?? '';

      await FirebaseFirestore.instance.collection('group_prayers').add({
        'group_id': groupId,
        'prayer_id': prayerId,
        'owner_uid': uid,
        'owner_nickname': ownerNickname,
        'owner_email': ownerEmail,
        'title': prayerTitle,
        'content': prayerContent,
        'status': prayerStatus,
        'hold_count': 0,
        'held_by_uids': <String>[],
        'is_pinned': false,
        'last_held_at': null,
        'created_at': now,
        'updated_at': now,
      });

      await FirebaseFirestore.instance
          .collection('prayers')
          .doc(prayerId)
          .update({
        'is_shared': true,
        'shared_group_ids': FieldValue.arrayUnion([groupId]),
        'updated_at': now,
      });

      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();
      if (groupDoc.exists) {
        final gData = groupDoc.data() ?? {};
        final memberUids = (gData['member_uids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        final groupName =
            (gData['name'] as String?)?.trim().isEmpty != true
                ? (gData['name'] as String?)!.trim()
                : '소그룹';
        final sharedByNickname = await _fetchNickname();

        for (final memberUid in memberUids) {
          if (memberUid == uid) continue;
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(memberUid)
                .collection('notifications')
                .add({
              'type': 'group_prayer_shared',
              'group_id': groupId,
              'group_name': groupName,
              'prayer_id': prayerId,
              'prayer_title': prayerTitle,
              'shared_by_uid': uid,
              'shared_by_nickname': sharedByNickname.isEmpty
                  ? '누군가'
                  : sharedByNickname,
              'created_at': now,
              'read': false,
            });
          } catch (_) {}
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('기도 제목을 공유하는 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.')));
      }
      rethrow;
    }
  }

  /// 선택한 소그룹들에 일괄 공유
  Future<void> _sharePrayerToGroups({
    required String prayerId,
    required Map<String, dynamic> data,
    required List<String> groupIds,
  }) async {
    if (groupIds.isEmpty) return;
    try {
      for (final groupId in groupIds) {
        await _sharePrayerToGroupByData(
          prayerId: prayerId,
          data: data,
          groupId: groupId,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${groupIds.length}곳 소그룹에 기도 제목이 공유되었습니다.')));
      }
    } catch (_) {}
  }

  /// 특정 소그룹 한 곳만 공유 해제
  Future<void> _unsharePrayerFromGroup(String prayerId, String groupId) async {
    try {
      final gpQuery = await FirebaseFirestore.instance
          .collection('group_prayers')
          .where('prayer_id', isEqualTo: prayerId)
          .where('group_id', isEqualTo: groupId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in gpQuery.docs) {
        batch.delete(doc.reference);
      }
      batch.update(
        FirebaseFirestore.instance.collection('prayers').doc(prayerId),
        {
          'shared_group_ids': FieldValue.arrayRemove([groupId]),
          'updated_at': DateTime.now(),
        },
      );
      await batch.commit();

      final prayerSnap = await FirebaseFirestore.instance
          .collection('prayers')
          .doc(prayerId)
          .get();
      final newIds =
          (prayerSnap.data()?['shared_group_ids'] as List<dynamic>?) ?? [];
      if (newIds.isEmpty) {
        await FirebaseFirestore.instance.collection('prayers').doc(prayerId).update({
          'is_shared': false,
          'updated_at': DateTime.now(),
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('공유 해제 중에 잠시 어려움이 있었습니다.\n조금 뒤에 다시 시도해 주시면 감사하겠습니다.')));
      }
      rethrow;
    }
  }
}

// ──────────────────────────────────────────
// 재사용 위젯
// ──────────────────────────────────────────

/// 상태 선택 칩 그룹 (prayer_detail_screen.dart 131~184행과 동일)
/// 미선택: 테두리·폰트 동일 / 선택 시 해당 상태 색상으로 테두리·배경·폰트 변경
class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.current, required this.onChanged});

  final PrayerStatus current;
  final ValueChanged<PrayerStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    // 바텀시트 배경 위로 '살짝 떠있는' 느낌을 위해, 기존 감싸는 Container 배경/테두리를 제거합니다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기도 상태 변경',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textLight,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PrayerStatus.values.map((status) {
            final isActive = status == current;
            return GestureDetector(
              onTap: () => onChanged(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? status.color.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? status.color
                        : AppTheme.textMuted.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '${status.icon} ${status.label}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? status.color : AppTheme.textLight,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 상태 표시 칩 (cross_prayer_note 스타일: 작고 투명, 아이콘 + 라벨)
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final PrayerStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: status.fgColor,
        ),
      ),
    );
  }
}

// ── 소그룹 새 글 알림 시트 (종 모양 탭 시) ─────
class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.uid});

  final String uid;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '소그룹 알림',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .collection('notifications')
                    .orderBy('created_at', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '알림을 불러오는 데 어려움이 있었어요.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppTheme.textMedium),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 48, color: AppTheme.textMedium.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            '아직 소그룹 알림이 없어요.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textMedium),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final type = data['type'] as String?;
                      if (type != 'group_prayer_shared') {
                        return const SizedBox.shrink();
                      }
                      final sharedBy = (data['shared_by_nickname'] as String?)?.trim().isEmpty != true
                          ? (data['shared_by_nickname'] as String?)!.trim()
                          : '누군가';
                      final groupName = (data['group_name'] as String?)?.trim().isEmpty != true
                          ? (data['group_name'] as String?)!.trim()
                          : '소그룹';
                      final title = (data['prayer_title'] as String?)?.trim().isEmpty != true
                          ? (data['prayer_title'] as String?)!.trim()
                          : '기도 제목';
                      final createdAt = data['created_at'];
                      final dateTime = createdAt is Timestamp
                          ? createdAt.toDate()
                          : createdAt is DateTime
                              ? createdAt
                              : null;
                      final dateStr = dateTime != null
                          ? _formatDate(dateTime)
                          : '';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '$sharedBy님이 "$groupName"에 기도 제목을 공유했어요',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textMedium,
                                ),
                          ),
                        ),
                        trailing: dateStr.isNotEmpty
                            ? Text(
                                dateStr,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.textMedium,
                                    ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────
// 유틸
// ──────────────────────────────────────────

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
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
