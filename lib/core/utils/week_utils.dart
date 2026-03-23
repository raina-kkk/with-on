// 주간 날짜 범위 유틸리티 (일~토 기준, 기기 로컬 시간 사용)
// 기기가 한국(KST, UTC+9)으로 설정된 경우 자동으로 KST 기준으로 동작합니다.

class WeekRange {
  const WeekRange({required this.start, required this.end});

  /// 해당 주의 일요일 00:00:00
  final DateTime start;

  /// 해당 주의 토요일 23:59:59
  final DateTime end;
}

/// [weekOffset] 0 = 이번 주, -1 = 지난 주, 1 = 다음 주, ...
WeekRange getWeekRange(int weekOffset) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Dart weekday: 1=Mon, 2=Tue, ..., 7=Sun
  // 일요일을 주의 시작으로 삼기 위한 오프셋:
  //   Sun(7) → 0, Mon(1) → 1, ... Sat(6) → 6
  final daysFromSunday = today.weekday % 7;
  final thisSunday = today.subtract(Duration(days: daysFromSunday));

  final weekStart = thisSunday.add(Duration(days: 7 * weekOffset));
  final weekEnd = weekStart.add(
    const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
  );

  return WeekRange(start: weekStart, end: weekEnd);
}

/// 표시용 주차 레이블을 반환합니다.
/// 예시: "2월 3주차  (02.16 ~ 02.22)"
String formatWeekLabel(WeekRange range) {
  final s = range.start;
  final e = range.end;
  final weekOfMonth = ((s.day - 1) ~/ 7) + 1;
  final sm = s.month.toString().padLeft(2, '0');
  final sd = s.day.toString().padLeft(2, '0');
  final em = e.month.toString().padLeft(2, '0');
  final ed = e.day.toString().padLeft(2, '0');
  return '${s.month}월 $weekOfMonth주차   ($sm.$sd ~ $em.$ed)';
}

/// 현재 주와 동일한지 여부를 반환합니다. (next week 이동 제한에 사용)
bool isCurrentWeek(int weekOffset) => weekOffset == 0;
