# DataView — Soft Pastel 구현 핸드오프

버전: 1.0  
기준 플랫폼: iOS 17+, WidgetKit  
기준 기기: iPhone 15 Pro, 393 × 852 pt  
언어 기준: 한국어(영문 확장 규칙 포함)

이 패키지는 기존 DataView의 정보 구조와 기능을 유지하면서, 승인된 **Soft Pastel** 시각 언어를 앱과 위젯에 일관되게 적용하기 위한 구현 자료입니다.

## 패키지 구성

- `docs/01_DESIGN_TOKENS.md` — 색상, 타이포그래피, 간격, 모서리, 그림자, 모션, 접근성
- `docs/02_SCREEN_SPECS.md` — 홈, 통계, 핫스팟, 설정 화면의 레이아웃과 상태
- `docs/03_WIDGET_SPECS.md` — Small, Medium, 잠금화면 위젯의 우선순위와 레이아웃
- `docs/04_ASSET_USAGE.md` — 각 PNG의 용도, 크기, 다크 모드 및 리사이징 규칙
- `docs/05_IMPLEMENTATION_CHECKLIST.md` — 개발·QA 완료 조건
- `tokens/soft-pastel.tokens.json` — 디자인 토큰의 기계 판독용 원본
- `code/SoftPastelTheme.swift` — SwiftUI 시작 코드
- `code/AssetNames.swift` — 이미지 자산 이름 상수
- `assets/png/runtime/` — 앱에 넣을 수 있는 export-ready PNG
- `assets/png/reference/` — 구현 및 시각 QA 기준 PNG
- `assets/source/` — PNG와 1:1로 대응하는 편집 가능한 SVG 원본
- `ASSET_MANIFEST.sha256` — PNG 무결성 확인용 체크섬

## 구현 원칙

1. 숫자와 사용량 상태가 장식보다 먼저 읽혀야 합니다.
2. 파스텔 색은 영역 구분과 정서적 톤을 담당하며, 본문 텍스트에는 고대비 잉크 색상을 사용합니다.
3. 배경·게이지·차트는 가능하면 SwiftUI로 그립니다. PNG는 앱 아이콘과 선택적 장식에만 사용합니다.
4. 앱과 위젯은 같은 토큰을 공유하되, 위젯은 정보량과 장식을 줄입니다.
5. 색만으로 상태를 전달하지 않습니다. 숫자, 레이블, 아이콘을 함께 제공합니다.

## 빠른 적용 순서

1. `tokens/soft-pastel.tokens.json`을 프로젝트 토큰 계층에 매핑합니다.
2. `code/SoftPastelTheme.swift`를 기존 테마 프로토콜에 맞게 병합합니다.
3. 앱 아이콘과 선택 자산을 Asset Catalog에 추가합니다.
4. `docs/02_SCREEN_SPECS.md`와 기준 PNG를 보며 화면을 구현합니다.
5. `docs/03_WIDGET_SPECS.md` 기준으로 WidgetKit family별 레이아웃을 분기합니다.
6. `docs/05_IMPLEMENTATION_CHECKLIST.md`로 Dynamic Type, VoiceOver, 긴 숫자와 경계 상태를 검증합니다.

## 샘플 데이터 정의

기준 시안은 아래 데이터를 사용합니다. 모든 숫자가 서로 일치하므로 스냅샷 테스트 fixture로 그대로 사용할 수 있습니다.

| 항목 | 값 |
|---|---:|
| 월 제공량 | 160.0 GB |
| 총 사용량 | 72.4 GB |
| 남은 데이터 | 87.6 GB |
| 사용률 | 45.25% → 표시 45% |
| iPhone 사용량 | 54.2 GB |
| 핫스팟 사용량 | 18.2 GB |
| 오늘 사용량 | 1.86 GB |
| 갱신일 | 9월 25일 |

## 파일 이름 규칙

- `@1x`, `@2x`, `@3x`는 iOS scale을 의미합니다.
- `Ref-` 접두사는 앱에 포함하지 않는 참조 시안입니다.
- `SoftPastel-` 접두사는 테마 전용 런타임 자산입니다.
- 색상 프로파일은 sRGB, PNG는 8-bit RGBA 또는 RGB입니다.

