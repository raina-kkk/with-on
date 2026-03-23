# 앱 폰트 설치 안내

이 앱은 **NotoSansKR**, **Noto Serif KR**, **Pretendard**, **LeferiPoint** 폰트를 사용합니다.  
아래에서 폰트 파일을 다운로드한 뒤, **이 폴더(`assets/fonts/`)에 넣어 주세요.**

---

## 1. NotoSansKR (메인 제목용)

- **다운로드**: [Google Fonts – Noto Sans KR](https://fonts.google.com/noto/specimen/Noto+Sans+KR) → 상단 **Download family** 버튼
- 압축을 푼 뒤, **다음 파일 3개**를 이 폴더에 복사합니다.  
  (폴더 구조는 제품에 따라 다를 수 있으니, 이름이 같은 파일을 찾으면 됩니다.)

  | 필요한 파일명 | 설명 |
  |---------------|------|
  | `NotoSansKR-Regular.ttf` | 기본 (400) |
  | `NotoSansKR-Medium.ttf` | 중간 (500) |
  | `NotoSansKR-Bold.ttf` | 굵게 (700) |

- Google에서 받은 zip 안에 **다른 이름**(예: `NotoSansKR-VariableFont_wght.ttf`만 있는 경우)이면,  
  [Noto Sans KR – GitHub (noto-cjk)](https://github.com/notofonts/noto-cjk) 등에서 **Static OTF/TTF** 버전을 받아 위와 같은 이름으로 맞춰 넣거나,  
  `pubspec.yaml`의 `fonts` → `NotoSansKR` 항목에서 `asset` 경로를 실제 파일명에 맞게 수정하면 됩니다.

---

## 2. Noto Serif KR (로그인 메인카피용)

- **다운로드**: [Google Fonts – Noto Serif KR](https://fonts.google.com/noto/specimen/Noto+Serif+KR) → 상단 **Download family** 버튼
- 압축을 푼 뒤, **다음 파일 2개**를 이 폴더에 복사합니다.

  | 필요한 파일명 | 설명 |
  |---------------|------|
  | `NotoSerifKR-Regular.ttf` | 기본 (400) |
  | `NotoSerifKR-Bold.ttf` | 굵게 (700) |

- zip 안에 파일명이 다르면(예: `NotoSerifKR-VariableFont_wght.ttf`) `pubspec.yaml`의 `NotoSerifKR` 항목에서 `asset` 경로를 실제 파일명에 맞게 수정하면 됩니다.

---

## 3. Pretendard (부제목·본문·입력창용)

- **다운로드**: [Pretendard – GitHub Releases](https://github.com/orioncactus/pretendard/releases) → 최신 버전의 **OTF** 또는 **TTF** 압축 파일
- 압축을 푼 뒤, **다음 파일 3개**를 이 폴더에 복사합니다.

  | 필요한 파일명 | 설명 |
  |---------------|------|
  | `Pretendard-Regular.otf` | 기본 (또는 `.ttf`) |
  | `Pretendard-Medium.otf` | 중간 (또는 `.ttf`) |
  | `Pretendard-Bold.otf` | 굵게 (또는 `.ttf`) |

- 배포본에 **확장자가 `.ttf`**인 경우:  
  파일명을 위 표와 같이 `Pretendard-Regular.ttf` 등으로 두고,  
  `pubspec.yaml`의 `fonts` → `Pretendard` 항목에서 `asset`을 `.ttf`로 바꿔 주세요.  
  예: `asset: assets/fonts/Pretendard-Regular.ttf`

---

## 4. 최종 확인

`assets/fonts/` 폴더에 아래가 있으면 됩니다.

- `NotoSansKR-Regular.ttf`, `NotoSansKR-Medium.ttf`, `NotoSansKR-Bold.ttf`
- `NotoSerifKR-Regular.ttf`, `NotoSerifKR-Bold.ttf`
- `Pretendard-Regular.otf` (또는 `.ttf`), `Pretendard-Medium.otf`, `Pretendard-Bold.otf`
- `LeferiPointSpecialItalic.ttf` (로고용)

이후 터미널에서 `flutter pub get` 실행 후 앱을 다시 실행하면 적용됩니다.
