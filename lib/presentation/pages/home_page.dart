import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/app_banner.dart';

const _summaryMainMaxFont = 17.0;
const _summaryMainMinFont = 11.0;

/// 카드 가로 너비에 맞춰 1·2줄에 동일한 [fontSize]를 쓰되, 둘째 문장이 한 줄에 들어가도록 축소한다.
double _homeSummaryFitFontSize(BuildContext context, double maxWidth, int total) {
  if (maxWidth <= 0) return _summaryMainMaxFont;
  final textScaler = MediaQuery.textScalerOf(context);
  const line1 = '혼자가 아니에요.';

  TextStyle baseStyle(double fs) => TextStyle(
        fontSize: fs,
        height: 1.8,
        color: Colors.white,
        fontFamily: 'NotoSerifKR',
        fontWeight: FontWeight.w400,
      );

  InlineSpan line2Span(double fs) => TextSpan(
        style: baseStyle(fs),
        children: [
          const TextSpan(text: '당신을 향한 기도가 '),
          TextSpan(
            text: '$total번',
            style: TextStyle(
              color: const Color(0xFFFFD966),
              fontWeight: FontWeight.w700,
              fontSize: fs,
              height: 1.8,
              fontFamily: 'NotoSerifKR',
            ),
          ),
          const TextSpan(text: ' 쌓이고 있어요.'),
        ],
      );

  double widthOf(InlineSpan span) {
    final p = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: double.infinity);
    return p.size.width;
  }

  for (var fs = _summaryMainMaxFont; fs >= _summaryMainMinFont; fs -= 0.25) {
    final w1 = widthOf(TextSpan(text: line1, style: baseStyle(fs)));
    final w2 = widthOf(line2Span(fs));
    if (w1 <= maxWidth && w2 <= maxWidth) return fs;
  }
  return _summaryMainMinFont;
}

/// HTML 목업 스타일 홈: 서머리 카드 + 나의 기도/소그룹 캐러셀
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onNavigateToMyPrayer,
    required this.onNavigateToGroup,
    required this.onNavigateToProfile,
    this.onNotification,
    this.notificationCount,
  });

  final VoidCallback onNavigateToMyPrayer;
  final VoidCallback onNavigateToGroup;
  final VoidCallback onNavigateToProfile;
  final VoidCallback? onNotification;
  final int? notificationCount;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(AppBanner.totalHeightFor(context)),
        child: AppBanner(
          titleLeft: 'With',
          titleRight: 'On',
          subtitle: '함께 기도를 켜는 시간',
          onNotification: onNotification,
          onProfile: onNavigateToProfile,
          notificationCount: notificationCount,
        ),
      ),
      body: uid == null
          ? const Center(child: Text('로그인 후 이용해 주세요.'))
          : ScrollConfiguration(
              behavior: _NoScrollbarScrollBehavior(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: _HomeBody(
                  uid: uid,
                  onNavigateToMyPrayer: onNavigateToMyPrayer,
                  onNavigateToGroup: onNavigateToGroup,
                ),
              ),
            ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.uid,
    required this.onNavigateToMyPrayer,
    required this.onNavigateToGroup,
  });

  final String uid;
  final VoidCallback onNavigateToMyPrayer;
  final VoidCallback onNavigateToGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _SummaryCard(uid: uid),
        const SizedBox(height: 30),
        _MyPrayerCarousel(uid: uid, onSeeAll: onNavigateToMyPrayer),
        const SizedBox(height: 30),
        _GroupPrayerCarousel(uid: uid, onSeeAll: onNavigateToGroup),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('group_prayers')
          .where('owner_uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            total += (doc.data()['hold_count'] as int?) ?? 0;
          }
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(minHeight: 128),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.primary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final fs = _homeSummaryFitFontSize(context, constraints.maxWidth, total);
                  final baseStyle = TextStyle(
                    fontSize: fs,
                    height: 1.8,
                    color: Colors.white,
                    fontFamily: 'NotoSerifKR',
                    fontWeight: FontWeight.w400,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('혼자가 아니에요.', style: baseStyle),
                      Text.rich(
                        TextSpan(
                          style: baseStyle,
                          children: [
                            const TextSpan(text: '당신을 향한 기도가 '),
                            TextSpan(
                              text: '$total번',
                              style: TextStyle(
                                color: const Color(0xFFFFD966),
                                fontWeight: FontWeight.w700,
                                fontSize: fs,
                                height: 1.8,
                                fontFamily: 'NotoSerifKR',
                              ),
                            ),
                            const TextSpan(text: ' 쌓이고 있어요.'),
                          ],
                        ),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.90),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('groups')
                            .where('member_uids', arrayContains: uid)
                            .snapshots(),
                        builder: (context, groupSnap) {
                          int totalMembers = 0;
                          if (groupSnap.hasData) {
                            for (final doc in groupSnap.data!.docs) {
                              final members =
                                  (doc.data()['member_uids'] as List<dynamic>?) ??
                                      const <dynamic>[];
                              totalMembers += members.length;
                            }
                          }
                          return Text(
                            '$totalMembers명의 소중한 중보자가 함께하고 있어요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.90),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.onSeeAll,
  });

  final IconData icon;
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.textMuted, width: 1),
                ),
              ),
              child: const Text(
                '모두 보기 >',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays > 0) return '${diff.inDays}일 전';
  if (diff.inHours > 0) return '${diff.inHours}시간 전';
  if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
  return '방금 전';
}

class _MyPrayerCarousel extends StatelessWidget {
  const _MyPrayerCarousel({required this.uid, required this.onSeeAll});

  final String uid;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('prayers')
            .where('owner_uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.auto_awesome_rounded,
                  title: '나의 기도',
                  onSeeAll: onSeeAll,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 128,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecorationFor(context),
                  alignment: Alignment.center,
                  child: Text(
                    '기도 목록을 불러오는 데 실패했어요.\n잠시 후 다시 시도해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.textMedium),
                  ),
                ),
              ],
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.auto_awesome_rounded,
                  title: '나의 기도',
                  onSeeAll: onSeeAll,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 128,
                  decoration: AppTheme.cardDecorationFor(context),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            );
          }
          final allDocs = snapshot.data?.docs ?? [];
          final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(allDocs)
            ..sort((a, b) {
              final aAt = a.data()['created_at'];
              final bAt = b.data()['created_at'];
              final aDt = aAt is Timestamp ? aAt.toDate() : (aAt is DateTime ? aAt : DateTime(0));
              final bDt = bAt is Timestamp ? bAt.toDate() : (bAt is DateTime ? bAt : DateTime(0));
              return bDt.compareTo(aDt);
            });
          final top5 = sorted.take(5).toList();
          if (top5.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.auto_awesome_rounded,
                  title: '나의 기도',
                  onSeeAll: onSeeAll,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 128,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecorationFor(context),
                  alignment: Alignment.center,
                  child: Text(
                    '아직 기록한 기도 제목이 없어요.\n첫 기도를 올려 보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            );
          }
          return _MyPrayerCarouselPaged(top5: top5, onSeeAll: onSeeAll);
        },
      );
  }
}

class _MyPrayerCarouselPaged extends StatefulWidget {
  const _MyPrayerCarouselPaged({required this.top5, required this.onSeeAll});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> top5;
  final VoidCallback onSeeAll;

  @override
  State<_MyPrayerCarouselPaged> createState() => _MyPrayerCarouselPagedState();
}

class _MyPrayerCarouselPagedState extends State<_MyPrayerCarouselPaged> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage && mounted) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top5 = widget.top5;
    const double symbolHeight = 32;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: symbolHeight,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '나의 기도',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkPrimary
                      : AppTheme.textDark,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onSeeAll,
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.textMuted, width: 1),
                    ),
                  ),
                  child: const Text(
                    '모두 보기 >',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textLight,
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 128,
          child: PageView.builder(
            controller: _pageController,
            itemCount: top5.length,
            itemBuilder: (context, index) {
              final data = top5[index].data();
              final title = (data['title'] as String?)?.trim() ?? '(제목 없음)';
              final content = (data['content'] as String?)?.trim() ?? '';
              final createdAt = data['created_at'];
              final created = createdAt is Timestamp
                  ? createdAt.toDate()
                  : (createdAt is DateTime ? createdAt : null);
              final timeAgo = created != null ? _formatTimeAgo(created) : '';
              final daysSinceCreated = created != null
                  ? (DateTime.now().difference(DateTime(created.year, created.month, created.day)).inDays + 1).clamp(1, 999)
                  : 1;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecorationFor(context),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        content.isNotEmpty ? '"$content"' : title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.textDark.withValues(alpha: 0.9),
                          fontFamily: 'NotoSerifKR',
                          fontStyle: content.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '연속 $daysSinceCreated일 기도의 등불',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textLight.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
            },
          ),
        ),
        if (top5.length > 1) ...[
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(top5.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.only(right: i == top5.length - 1 ? 0 : 4),
                  width: isActive ? 12 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.navInactive,
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupPrayerCarousel extends StatelessWidget {
  const _GroupPrayerCarousel({required this.uid, required this.onSeeAll});

  final String uid;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        final groupIds = (userSnap.data?.data()?['group_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (groupIds.isEmpty) {
          return _emptySection(context);
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('group_prayers')
              .where('group_id', whereIn: groupIds.length > 10 ? groupIds.take(10).toList() : groupIds)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _emptySection(context);
            final allDocs = snapshot.data?.docs ?? [];
            final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(allDocs)
              ..sort((a, b) {
                final aAt = a.data()['created_at'];
                final bAt = b.data()['created_at'];
                final aDt = aAt is Timestamp ? aAt.toDate() : (aAt is DateTime ? aAt : DateTime(0));
                final bDt = bAt is Timestamp ? bAt.toDate() : (bAt is DateTime ? bAt : DateTime(0));
                return bDt.compareTo(aDt);
              });
            final top5 = sorted.take(5).toList();
            if (top5.isEmpty) return _emptySection(context);
            return _GroupPrayerCarouselPaged(top5: top5, onSeeAll: onSeeAll);
          },
        );
      },
    );
  }

  Widget _emptySection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.groups_rounded,
          title: '소그룹 기도',
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: 8),
        Container(
          height: 168,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationFor(context),
          alignment: Alignment.center,
          child: Text(
            '소그룹에 참여하면\n함께 나눈 기도 제목을 볼 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textMedium),
          ),
        ),
      ],
    );
  }
}

class _GroupPrayerCarouselPaged extends StatefulWidget {
  const _GroupPrayerCarouselPaged({
    required this.top5,
    required this.onSeeAll,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> top5;
  final VoidCallback onSeeAll;

  @override
  State<_GroupPrayerCarouselPaged> createState() => _GroupPrayerCarouselPagedState();
}

class _GroupPrayerCarouselPagedState extends State<_GroupPrayerCarouselPaged> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage && mounted) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top5 = widget.top5;
    const double symbolHeight = 32;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: symbolHeight,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '소그룹 기도',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkPrimary
                      : AppTheme.textDark,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onSeeAll,
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.textMuted, width: 1),
                    ),
                  ),
                  child: const Text(
                    '모두 보기 >',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textLight,
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _pageController,
            itemCount: top5.length,
            itemBuilder: (context, index) {
              final gpDoc = top5[index];
              final data = gpDoc.data();
              final prayerId = data['prayer_id'] as String? ?? '';
              final groupId = data['group_id'] as String? ?? '';
              final holdCount = (data['hold_count'] as int?) ?? 0;
              return _GroupPrayerCard(
                prayerId: prayerId,
                groupId: groupId,
                holdCount: holdCount,
              );
            },
          ),
        ),
        if (top5.length > 1) ...[
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(top5.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.only(right: i == top5.length - 1 ? 0 : 4),
                  width: isActive ? 12 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.navInactive,
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupPrayerCard extends StatelessWidget {
  const _GroupPrayerCard({
    required this.prayerId,
    required this.groupId,
    required this.holdCount,
  });

  final String prayerId;
  final String groupId;
  final int holdCount;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('prayers').doc(prayerId).snapshots(),
      builder: (context, snap) {
        final prayerData = snap.data?.data();
        final title = (prayerData?['title'] as String?)?.trim() ?? '(제목 없음)';
        final ownerUid = prayerData?['owner_uid'] as String? ?? '';
        final ownerNickname = (prayerData?['owner_nickname'] as String?)?.trim();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationFor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<({String nickname, String groupName})>(
                      future: _fetchNicknameAndGroupName(ownerUid, ownerNickname, groupId),
                      builder: (context, asyncSnap) {
                        final nickname = asyncSnap.data?.nickname ?? '···';
                        final groupName = asyncSnap.data?.groupName ?? '···';
                        final firstLine = '$nickname | $groupName';
                        return Text(
                          firstLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        );
                      },
                    ),
                  ),
                  Icon(Icons.favorite_rounded,
                      size: 14,
                      color: holdCount > 0 ? Theme.of(context).colorScheme.primary : AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '$holdCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: holdCount > 0 ? Theme.of(context).colorScheme.primary : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textDark.withValues(alpha: 0.8),
                  fontFamily: 'NotoSerifKR',
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.bgDeep,
                    foregroundColor: AppTheme.textMedium,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('자세히 보기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<({String nickname, String groupName})> _fetchNicknameAndGroupName(
  String ownerUid,
  String? ownerNickname,
  String groupId,
) async {
  String nickname = ownerNickname?.isNotEmpty == true ? ownerNickname! : '';
  String groupName = '';

  if (nickname.isEmpty && ownerUid.isNotEmpty) {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .get();
      nickname = (userDoc.data()?['nickname'] as String?)?.trim() ?? '';
    } catch (_) {}
  }
  if (nickname.isEmpty) nickname = '(이름 없음)';

  if (groupId.isNotEmpty) {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();
      groupName = (groupDoc.data()?['name'] as String?)?.trim() ?? '';
    } catch (_) {}
  }
  if (groupName.isEmpty) groupName = '(소그룹)';

  return (nickname: nickname, groupName: groupName);
}

/// 홈 세로 스크롤 시 스크롤바 비표시
class _NoScrollbarScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
