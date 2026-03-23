# WithOn App — UI Color 사용 현황 분석

> 작성일: 2026-03-08
> 분석 대상: `lib/core/theme/app_theme.dart` 및 전체 페이지 파일
> 목적: Theme 변경 작업의 용이성 확대를 위한 Color 사용 현황 정리

---

## 목차

1. [Color 변수 전체 목록 (app_theme.dart)](#1-color-변수-전체-목록)
2. [페이지별 Color 사용 현황](#2-페이지별-color-사용-현황)
   - [로그인 (login_page.dart)](#21-로그인)
   - [홈 (home_page.dart)](#22-홈)
   - [나의 기도 / 새 기도 작성 (my_room_page.dart)](#23-나의-기도--새-기도-작성)
   - [통계 (profile_page.dart)](#24-통계)
   - [소그룹 (group_page.dart)](#25-소그룹)
3. [미사용 Color 변수](#3-미사용-color-변수)
4. [주요 관찰 사항](#4-주요-관찰-사항)

---

## 1. Color 변수 전체 목록

> 파일 위치: `lib/core/theme/app_theme.dart`

### 기본 팔레트

| 변수명 | Color Code | 설명 |
|---|---|---|
| `primary` | `0xFF232C34` | 주요 텍스트, 타이틀, 메인 버튼 |
| `primaryLight` | `0xFF3A4552` | primary 밝은 변형 |
| `primaryDark` | `0xFF1A2129` | primary 어두운 변형 |
| `secondary` | `0xFF72513E` | 강조 포인트 (아이콘, 텍스트 버튼) |
| `accent` | `0xFFC7D6D9` | 비활성, 칩, 배지 등 보조 UI |

### Light 배경

| 변수명 | Color Code | 설명 |
|---|---|---|
| `bgLight` | `0xFFFFFFFF` | 전체 앱 배경 (Light) |
| `bgWarm` | `0xFFFAFAFA` | 따뜻한 배경 톤 |
| `bgDeep` | `0xFFF5F5F5` | 깊은 배경 톤 (버튼 배경 등) |

### Light 텍스트

| 변수명 | Color Code | 설명 |
|---|---|---|
| `textDark` | `0xFF232C34` | 주요 텍스트 |
| `textMedium` | `0xFF232C34` | 중간 강조 텍스트 ※ textDark와 동일값 |
| `textLight` | `0xFF5C6B75` | 보조 텍스트 |
| `textMuted` | `0xFF8A9BA3` | 비활성/힌트 텍스트 |

### Light 테두리

| 변수명 | Color Code | 설명 |
|---|---|---|
| `border` | `0xFFF0EBCC` | 은은한 경계선 |
| `borderLight` | `0xFFF5F1D8` | 더 연한 경계선 |

### Dark 전용

| 변수명 | Color Code | 설명 |
|---|---|---|
| `darkBackground` | `0xFF0D0D0D` | Dark 모드 배경 |
| `darkPrimary` | `0xFF2C3540` | Dark 모드 Primary |
| `darkPrimaryText` | `0xFFFAF8E3` | Dark 모드 텍스트 |
| `darkSecondary` | `0xFFA7763E` | Dark 모드 Secondary |
| `darkDivider` | `0xFF1A2129` | Dark 모드 구분선 |
| `darkCard` | `0xFFFAF8E3` | Dark 모드 카드/입력 배경 |
| `darkNavInactive` | `0x99FAF8E3` | Dark 모드 Nav 비활성 |

### 기도 상태 색상

| 변수명 | Color Code | 설명 |
|---|---|---|
| `statusPraying` | `0xFF72513E` | 기도 중 — 텍스트색 |
| `statusWaiting` | `0xFF232C34` | 기다리는 중 — 텍스트색 |
| `statusResponded` | `0xFF4A7C59` | 응답 받음 — 텍스트색 |
| `statusPartial` | `0xFF5C6B75` | 방향 전환 — 텍스트색 |
| `statusGratitude` | `0xFF8A9BA3` | 잠시 멈춤 — 텍스트색 |
| `statusPrayingBg` | `0xFFF0EBE0` | 기도 중 — 칩 배경 |
| `statusPrayingFg` | `0xFF72513E` | 기도 중 — 칩 전경 |
| `statusWaitingBg` | `0xFFE8ECEF` | 기다리는 중 — 칩 배경 |
| `statusWaitingFg` | `0xFF232C34` | 기다리는 중 — 칩 전경 |
| `statusRespondedBg` | `0xFFE8F0E6` | 응답 받음 — 칩 배경 |
| `statusRespondedFg` | `0xFF4A7C59` | 응답 받음 — 칩 전경 |
| `statusPartialBg` | `0xFFE8ECEF` | 방향 전환 — 칩 배경 ※ statusWaitingBg와 동일값 |
| `statusPartialFg` | `0xFF5C6B75` | 방향 전환 — 칩 전경 |
| `statusGratitudeBg` | `0xFFE8EAED` | 잠시 멈춤 — 칩 배경 |
| `statusGratitudeFg` | `0xFF8A9BA3` | 잠시 멈춤 — 칩 전경 |

### 소그룹 / 차트

| 변수명 | Color Code | 설명 |
|---|---|---|
| `groupBlue` | `0xFF5C6B75` | 소그룹 섹션 아이콘 ※ textLight와 동일값 |
| `chartPeach` | `0xFF72513E` | 차트 — 기도 중 / 오늘 날짜 |
| `chartSkyBlue` | `0xFF7A8B95` | 차트 — 기다리는 중 |
| `chartGreen` | `0xFF4A7C59` | 차트 — 응답 받음 |
| `chartLavender` | `0xFF8A9BA3` | 차트 — 잠시 멈춤 ※ textMuted와 동일값 |

### 네비게이션 / 에러 / 카드

| 변수명 | Color Code | 설명 |
|---|---|---|
| `navInactive` | `0xFFC7D6D9` | 네비 비활성 탭 |
| `errorRed` | `0xFFA64444` | 에러/경고 (Light·Dark 공통) |
| `errorRedBg` | `0xFFFDEAEA` | 에러 배경 |
| `cardBackground` | `0xFFF8F8E6` | 카드·입력창 배경 (lightTheme 내부 사용) |

### Legacy 호환 별칭 (AppTheme 클래스 내)

| 변수명 | 가리키는 변수 | 비고 |
|---|---|---|
| `primaryColor` | `primary` | 미사용 |
| `backgroundLight` | `bgLight` | 미사용 |
| `accentYellow` | `statusGratitude` | 미사용 |
| `textMain` | `textDark` | 미사용 |
| `textSubtle` | `textMedium` | 미사용 |

---

## 2. 페이지별 Color 사용 현황

### 2.1 로그인

> 파일: `lib/presentation/pages/login_page.dart`

| Color 적용 위치 | Color Code | 사용 Mode | 변수명 | 변수 위치 |
|---|---|---|---|---|
| Scaffold Background | `0xFFFFFFFF` | Light | `bgLight` | app_theme.dart |
| 로고 아이콘 컨테이너 배경 | `0xFF232C34` (+alpha) | Light | `primary` | app_theme.dart |
| 로고 아이콘 색상 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 앱 타이틀 텍스트 | `0xFF232C34` | Light | `textDark` | app_theme.dart |
| 서브타이틀 텍스트 | `0xFFC7D6D9` | Light | `accent` | app_theme.dart |
| 설명/링크 텍스트 | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 입력 필드 아이콘 | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 카드 데코레이션 (배경·테두리·그림자) | — | 공통 | `cardDecorationFor()` | app_theme.dart |

---

### 2.2 홈

> 파일: `lib/presentation/pages/home_page.dart`

| Color 적용 위치 | Color Code | 사용 Mode | 변수명 | 변수 위치 |
|---|---|---|---|---|
| Scaffold Background | `0xFFFFFFFF` | Light | `bgLight` | app_theme.dart |
| 기도 섹션 아이콘 컨테이너 배경 | `0xFF232C34` (+alpha) | Light | `primary` | app_theme.dart |
| 아이콘 색상 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 섹션 타이틀 텍스트 | `0xFF232C34` | Light | `textDark` | app_theme.dart |
| 탭 구분선 | `0xFF8A9BA3` | Light | `textMuted` | app_theme.dart |
| 탭/소제목 텍스트 | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 카드 본문 텍스트 | `0xFF232C34` | Light | `textMedium` | app_theme.dart |
| 탭 활성 인디케이터 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 탭 비활성 인디케이터 | `0xFFC7D6D9` | Light | `navInactive` | app_theme.dart |
| 소그룹 섹션 아이콘 컨테이너 배경 | `0xFF5C6B75` (+alpha) | Light | `groupBlue` | app_theme.dart |
| 소그룹 아이콘 색상 | `0xFF5C6B75` | Light | `groupBlue` | app_theme.dart |
| 소그룹 카드 텍스트 | `0xFF232C34` | Light | `textDark` | app_theme.dart |
| 더보기 버튼 배경 | `0xFFF5F5F5` | Light | `bgDeep` | app_theme.dart |
| 더보기 버튼 텍스트 | `0xFF232C34` | Light | `textMedium` | app_theme.dart |
| 기도 카운트 아이콘/텍스트 (활성) | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 기도 카운트 아이콘/텍스트 (비활성) | `0xFF8A9BA3` | Light | `textMuted` | app_theme.dart |
| 카드 날짜 텍스트 | `0xFF5C6B75` (+alpha) | Light | `textLight` | app_theme.dart |
| 카드 데코레이션 (배경·테두리·그림자) | — | 공통 | `cardDecorationFor()` | app_theme.dart |

---

### 2.3 나의 기도 / 새 기도 작성

> 파일: `lib/presentation/pages/my_room_page.dart`
> ※ 새 기도 작성은 별도 페이지 없이 `my_room_page.dart` 내 `showModalBottomSheet` / Dialog로 구현됨

| Color 적용 위치 | Color Code | 사용 Mode | 변수명 | 변수 위치 |
|---|---|---|---|---|
| Scaffold Background | `0xFFFFFFFF` | Light | `bgLight` | app_theme.dart |
| 모달(새 기도 작성) Background | `0xFFFFFFFF` | Light | `bgLight` | app_theme.dart |
| 모달 ColorScheme — primary | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 모달 ColorScheme — surface | `0xFFFFFFFF` | Light | `bgLight` | app_theme.dart |
| 모달 ColorScheme — onSurface | `0xFF232C34` | Light | `textDark` | app_theme.dart |
| **기도 상태칩 — 기도 중 (배경)** | `0xFFF0EBE0` | Light | `statusPrayingBg` | app_theme.dart |
| **기도 상태칩 — 기도 중 (전경)** | `0xFF72513E` | Light | `statusPrayingFg` | app_theme.dart |
| **기도 상태칩 — 기도 중 (텍스트색)** | `0xFF72513E` | Light | `statusPraying` | app_theme.dart |
| **기도 상태칩 — 기다리는 중 (배경)** | `0xFFE8ECEF` | Light | `statusWaitingBg` | app_theme.dart |
| **기도 상태칩 — 기다리는 중 (전경)** | `0xFF232C34` | Light | `statusWaitingFg` | app_theme.dart |
| **기도 상태칩 — 기다리는 중 (텍스트색)** | `0xFF232C34` | Light | `statusWaiting` | app_theme.dart |
| **기도 상태칩 — 응답 받음 (배경)** | `0xFFE8F0E6` | Light | `statusRespondedBg` | app_theme.dart |
| **기도 상태칩 — 응답 받음 (전경)** | `0xFF4A7C59` | Light | `statusRespondedFg` | app_theme.dart |
| **기도 상태칩 — 응답 받음 (텍스트색)** | `0xFF4A7C59` | Light | `statusResponded` | app_theme.dart |
| **기도 상태칩 — 방향 전환 (배경)** | `0xFFE8ECEF` | Light | `statusPartialBg` | app_theme.dart |
| **기도 상태칩 — 방향 전환 (전경)** | `0xFF5C6B75` | Light | `statusPartialFg` | app_theme.dart |
| **기도 상태칩 — 방향 전환 (텍스트색)** | `0xFF5C6B75` | Light | `statusPartial` | app_theme.dart |
| **기도 상태칩 — 잠시 멈춤 (배경)** | `0xFFE8EAED` | Light | `statusGratitudeBg` | app_theme.dart |
| **기도 상태칩 — 잠시 멈춤 (전경)** | `0xFF8A9BA3` | Light | `statusGratitudeFg` | app_theme.dart |
| **기도 상태칩 — 잠시 멈춤 (텍스트색)** | `0xFF8A9BA3` | Light | `statusGratitude` | app_theme.dart |
| 필터 칩 (활성 배경) | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 필터 칩 (비활성 테두리) | `0xFFF0EBCC` | Light | `border` | app_theme.dart |
| 필터 칩 (비활성 텍스트) | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 카드 테두리 | `0xFFF0EBCC` | Light | `border` | app_theme.dart |
| 정렬 아이콘/텍스트 | `0xFF232C34` | Light | `textMedium` | app_theme.dart |
| 날짜/메모 텍스트 | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 비활성 아이콘 | `0xFF8A9BA3` | Light | `textMuted` | app_theme.dart |
| FAB 버튼 배경 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 카드 데코레이션 (배경·테두리·그림자) | — | 공통 | `cardDecorationFor()` | app_theme.dart |

---

### 2.4 통계

> 파일: `lib/presentation/pages/profile_page.dart`

| Color 적용 위치 | Color Code | 사용 Mode | 변수명 | 변수 위치 |
|---|---|---|---|---|
| 프로필 서브텍스트 | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 통계 배지 색상 | `0xFFC7D6D9` | Light | `accent` | app_theme.dart |
| 통계 배지 색상 | `0xFFA7763E` | **Dark** | `darkSecondary` | app_theme.dart |
| 통계 배지 배경 | `0xFF2C3540` | **Dark** | `darkPrimary` | app_theme.dart |
| 섹션 아이콘 색상 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 카드 타이틀 텍스트 | `0xFF232C34` | Light | `textDark` | app_theme.dart |
| 조회 버튼 배경 | `0xFFF5F5F5` | Light | `bgDeep` | app_theme.dart |
| 조회 버튼 아이콘/텍스트 | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| **차트 바 — 기도 중** | `0xFF72513E` | Light | `chartPeach` | app_theme.dart |
| **차트 바 — 기다리는 중** | `0xFF7A8B95` | Light | `chartSkyBlue` | app_theme.dart |
| **차트 바 — 응답 받음** | `0xFF4A7C59` | Light | `chartGreen` | app_theme.dart |
| **차트 바 — 잠시 멈춤** | `0xFF8A9BA3` | Light | `chartLavender` | app_theme.dart |
| **파이차트 — 기도 중** | `0xFF72513E` | Light | `statusPrayingFg` | app_theme.dart |
| **파이차트 — 응답 받음** | `0xFF4A7C59` | Light | `statusRespondedFg` | app_theme.dart |
| **파이차트 — 기다리는 중** | `0xFF232C34` | Light | `statusWaitingFg` | app_theme.dart |
| **파이차트 — 방향 전환** | `0xFF5C6B75` | Light | `statusPartialFg` | app_theme.dart |
| **파이차트 — 잠시 멈춤** | `0xFF8A9BA3` | Light | `statusGratitudeFg` | app_theme.dart |
| 슬라이더 (activeTrack) | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 달력 — 오늘 날짜 하이라이트 | `0xFF72513E` | Light | `chartPeach` | app_theme.dart |
| 카드 내 테두리 | `0xFFF0EBCC` | Light | `border` | app_theme.dart |
| 로그아웃 버튼 아이콘/텍스트 | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 로그아웃 버튼 테두리 | `0xFFF0EBCC` | Light | `border` | app_theme.dart |
| 버전 정보 텍스트 | `0xFF8A9BA3` | Light | `textMuted` | app_theme.dart |
| 링크 텍스트 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 카드 데코레이션 (배경·테두리·그림자) | — | 공통 | `cardDecorationFor()` | app_theme.dart |

---

### 2.5 소그룹

> 파일: `lib/presentation/pages/group_page.dart`

| Color 적용 위치 | Color Code | 사용 Mode | 변수명 | 변수 위치 |
|---|---|---|---|---|
| Scaffold Background | `0xFFFFFFFF` | Light | `bgLight` | app_theme.dart |
| 헤더/목록 텍스트 | `0xFF232C34` | Light | `textMedium` | app_theme.dart |
| 아이콘 컨테이너 배경 | `0xFF232C34` (+alpha) | Light | `primary` | app_theme.dart |
| 아이콘 색상 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 에러 텍스트 | `0xFFA64444` | 공통 | `errorRed` | app_theme.dart |
| 다이얼로그 전경 | `0xFF232C34` | Light | `textDark` | app_theme.dart |
| 메뉴 항목 텍스트 | `0xFF232C34` | Light | `textMedium` | app_theme.dart |
| 메뉴 항목 아이콘 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| 멤버 이름 텍스트 | `0xFF232C34` | Light | `textDark` | app_theme.dart |
| 멤버 서브텍스트 | `0xFF232C34` | Light | `textMedium` | app_theme.dart |
| 초대 버튼 배경 | `0xFF232C34` | Light | `primary` | app_theme.dart |
| **기도 상태 칩 — 기도 중 (배경)** | `0xFFF0EBE0` | Light | `statusPrayingBg` | app_theme.dart |
| **기도 상태 칩 — 응답 받음 (배경)** | `0xFFE8F0E6` | Light | `statusRespondedBg` | app_theme.dart |
| **기도 상태 칩 — 기다리는 중 (배경)** | `0xFFE8ECEF` | Light | `statusWaitingBg` | app_theme.dart |
| **기도 상태 칩 — 방향 전환 (배경)** | `0xFFE8ECEF` | Light | `statusPartialBg` | app_theme.dart |
| **기도 상태 칩 — 잠시 멈춤 (배경)** | `0xFFE8EAED` | Light | `statusGratitudeBg` | app_theme.dart |
| **기도 상태 칩 — 기도 중 (전경)** | `0xFF72513E` | Light | `statusPrayingFg` | app_theme.dart |
| **기도 상태 칩 — 응답 받음 (전경)** | `0xFF4A7C59` | Light | `statusRespondedFg` | app_theme.dart |
| **기도 상태 칩 — 기다리는 중 (전경)** | `0xFF232C34` | Light | `statusWaitingFg` | app_theme.dart |
| **기도 상태 칩 — 방향 전환 (전경)** | `0xFF5C6B75` | Light | `statusPartialFg` | app_theme.dart |
| **기도 상태 칩 — 잠시 멈춤 (전경)** | `0xFF8A9BA3` | Light | `statusGratitudeFg` | app_theme.dart |
| 탈퇴 카드 테두리 | `0xFFA64444` (+alpha) | 공통 | `errorRed` | app_theme.dart |
| 탈퇴 카드 배경 기준값 | `0xFFFDEAEA` | 공통 | `errorRedBg` | app_theme.dart |
| 탈퇴 버튼 텍스트/아이콘 | `0xFFA64444` | 공통 | `errorRed` | app_theme.dart |
| 기도 항목 아이콘 (활성) | `0xFF232C34` (+alpha) | Light | `primary` | app_theme.dart |
| 기도 항목 아이콘 (비활성 — 강) | `0xFF8A9BA3` (+alpha) | Light | `textMuted` | app_theme.dart |
| 기도 항목 아이콘 (비활성 — 약) | `0xFF5C6B75` | Light | `textLight` | app_theme.dart |
| 주간 바 색상 | `0xFF232C34` | Light | `primary` (via `_weekBarAccent`) | group_page.dart |
| 카드 데코레이션 (배경·테두리·그림자) | — | 공통 | `cardDecorationFor()` | app_theme.dart |

---

## 3. 미사용 Color 변수

### 3-A. 완전 미사용 — 코드베이스 어디서도 직접 참조되지 않음

| Color Code | 변수명 | 변수 위치 | 비고 |
|---|---|---|---|
| `0xFF3A4552` | `primaryLight` | app_theme.dart | 정의만 존재, 참조 없음 → 삭제 검토 가능 |
| `0xFF1A2129` | `primaryDark` | app_theme.dart | 정의만 존재, 참조 없음 → 삭제 검토 가능 |
| `0xFFFAFAFA` | `bgWarm` | app_theme.dart | 정의만 존재, 참조 없음 → 삭제 검토 가능 |
| `0xFFF5F1D8` | `borderLight` | app_theme.dart | 정의만 존재, 참조 없음 → 삭제 검토 가능 |
| (alias) | `primaryColor` | app_theme.dart | `primary` 별칭, 미사용 → 삭제 검토 가능 |
| (alias) | `backgroundLight` | app_theme.dart | `bgLight` 별칭, 미사용 → 삭제 검토 가능 |
| (alias) | `accentYellow` | app_theme.dart | `statusGratitude` 별칭, 미사용 → 삭제 검토 가능 |
| (alias) | `textMain` | app_theme.dart | `textDark` 별칭, 미사용 → 삭제 검토 가능 |
| (alias) | `textSubtle` | app_theme.dart | `textMedium` 별칭, 미사용 → 삭제 검토 가능 |

### 3-B. 테마 빌더 내부에서만 사용 — 페이지/위젯에서 직접 참조 없음

> `lightTheme` / `darkTheme` 빌더 메서드 내부에서는 사용되나, 페이지 파일에서 직접 `AppTheme.xxx` 형태로 호출되지 않음

| Color Code | 변수명 | 내부 사용 위치 |
|---|---|---|
| `0xFF72513E` | `secondary` | `lightTheme` — BottomNav selectedItem, TextButton foreground |
| `0xFFF8F8E6` | `cardBackground` | `lightTheme` — BottomNav 배경, Input fill |
| `0xFF0D0D0D` | `darkBackground` | `darkTheme` — Scaffold 배경 |
| `0xFFFAF8E3` | `darkPrimaryText` | `darkTheme` — 텍스트 전반 |
| `0xFFFAF8E3` | `darkCard` | `darkTheme` — BottomNav 배경, Input fill |
| `0x99FAF8E3` | `darkNavInactive` | `darkTheme` — BottomNav 비활성 |

---

## 4. 주요 관찰 사항

### 4-1. 동일한 색상값을 가진 변수들

Theme 변경 시 한 변수를 변경하면 시각적으로 동일하게 보이는 다른 변수들과의 일관성을 함께 검토해야 함.

| 색상값 | 동일값을 가진 변수들 |
|---|---|
| `0xFF232C34` | `primary`, `textDark`, `textMedium`, `statusWaiting`, `statusWaitingFg` |
| `0xFF72513E` | `secondary`, `statusPraying`, `statusPrayingFg`, `chartPeach` |
| `0xFF4A7C59` | `statusResponded`, `statusRespondedFg`, `chartGreen` |
| `0xFF5C6B75` | `textLight`, `statusPartial`, `statusPartialFg`, `groupBlue` |
| `0xFF8A9BA3` | `textMuted`, `statusGratitude`, `statusGratitudeFg`, `chartLavender` |
| `0xFFE8ECEF` | `statusWaitingBg`, `statusPartialBg` |

### 4-2. textDark vs textMedium

현재 두 변수 모두 `0xFF232C34`로 **동일한 색상값**. 의미적 분리는 되어 있으나 실제 색상이 같음.
→ 향후 Light/Dark 전환 시 다른 값으로 분리하려면 **광범위한 수정** 필요 (약 120여 곳에서 혼용)

### 4-3. 새 기도 작성 페이지

별도 파일 없음. `my_room_page.dart` 내부의 `showModalBottomSheet` 및 Dialog로 구현됨.
사용 색상은 나의 기도 페이지와 동일한 체계 (`bgLight`, `primary`, `textDark` 등)를 따름.

### 4-4. Dark Mode 적용 범위

대부분의 페이지는 `Theme.of(context)` 시스템을 통해 자동으로 다크 모드를 따름.
**직접 Dark 변수를 참조하는 위치:**
- `profile_page.dart` — 통계 배지 색상 (`darkSecondary`, `darkPrimary`)
- `main.dart` — 하단 네비게이션 테두리 (`darkDivider`)

### 4-5. 파일 외부 로컬 변수 주의

일부 페이지 파일에서 `AppTheme` 변수를 파일 상단의 `const` 로컬 변수에 할당하여 사용함.
Theme 변경 시 이 로컬 변수들도 추적 필요:

| 파일 | 로컬 변수 | 참조하는 AppTheme 변수 |
|---|---|---|
| `my_room_page.dart` | `_statusPraying` | `statusPrayingBg` |
| `my_room_page.dart` | `_statusAnswered` | `statusRespondedBg` |
| `my_room_page.dart` | `_statusWaiting` | `statusWaitingBg` |
| `my_room_page.dart` | `_statusRefocused` | `statusPartialBg` |
| `my_room_page.dart` | `_statusResting` | `statusGratitudeBg` |
| `my_room_page.dart` | `_chipActive` | `primary` |
| `my_room_page.dart` | `_chipInactiveBorder` | `border` |
| `my_room_page.dart` | `_chipInactiveText` | `textLight` |
| `profile_page.dart` | `_kPeach` | `chartPeach` |
| `profile_page.dart` | `_kSkyBlue` | `chartSkyBlue` |
| `profile_page.dart` | `_kSageGreen` | `chartGreen` |
| `profile_page.dart` | `_kLavender` | `chartLavender` |
| `group_page.dart` | `_weekBarAccent` | `primary` |
