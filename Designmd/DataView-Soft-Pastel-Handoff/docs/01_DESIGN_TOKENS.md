# 01. 디자인 토큰

## 1. 시각 방향

Soft Pastel은 **민트 + 하늘색 + 연보라 + 옅은 핑크**를 사용하되, 정보 가독성은 짙은 네이비 계열 텍스트가 책임지는 테마입니다. 카드 수를 과도하게 늘리지 않고, 주요 데이터 묶음만 부드러운 배경 블록으로 구분합니다.

키워드: `calm`, `friendly`, `airy`, `data-first`, `rounded`

## 2. 색상

### 2.1 기본 팔레트

| 토큰 | Light | Dark | 사용처 |
|---|---|---|---|
| `color.background.canvas` | `#F7F9FF` | `#111525` | 전체 배경 |
| `color.background.elevated` | `#FFFFFF` | `#1B2133` | 주요 카드 |
| `color.background.subtle` | `#EFF4FF` | `#232A40` | 보조 그룹 |
| `color.text.primary` | `#20263A` | `#F5F7FF` | 제목, 핵심 수치 |
| `color.text.secondary` | `#66708A` | `#B9C1D7` | 설명, 보조 수치 |
| `color.text.tertiary` | `#68728B` | `#8E98B2` | 메타데이터 |
| `color.border.soft` | `#E4E9F5` | `#303951` | 구분선, 테두리 |
| `color.accent.mint` | `#74D7C4` | `#62C9B6` | 기본 게이지, 선택 상태 |
| `color.accent.mintStrong` | `#176B5B` | `#88E3D1` | 버튼/링크, 고대비 강조 |
| `color.accent.sky` | `#A8D8FF` | `#74BDF3` | iPhone 데이터 |
| `color.accent.lavender` | `#C3B5FA` | `#A895F0` | 핫스팟 데이터 |
| `color.accent.pink` | `#F7C4D7` | `#EAAAC3` | 보조 차트/배지 |
| `color.accent.yellow` | `#FFE2A6` | `#E9C875` | 경고 전 단계 |
| `color.semantic.success` | `#2F7D64` | `#7BD8B7` | 정상/연결됨 |
| `color.semantic.warning` | `#8A5B00` | `#FFD47A` | 80% 이상 사용 |
| `color.semantic.danger` | `#A43A58` | `#FF9AB5` | 95% 이상 사용 |

### 2.2 표면 조합

| 표면 | 배경 | 전경 | 테두리 |
|---|---|---|---|
| 기본 카드 | `elevated` | `text.primary` | 없음 또는 `border.soft` 1 px |
| 민트 틴트 카드 | `#EAF9F5` | `text.primary` | `#D5F0E9` |
| 스카이 틴트 카드 | `#EDF7FF` | `text.primary` | `#D9EDFC` |
| 라벤더 틴트 카드 | `#F2EFFF` | `text.primary` | `#E4DDFC` |
| 핑크 틴트 카드 | `#FFF1F6` | `text.primary` | `#F8DEE8` |

파스텔 배경 위에 흰색 본문을 사용하지 않습니다. 작은 본문과 핵심 수치는 항상 `text.primary` 또는 검증된 강한 semantic 색을 사용합니다.

### 2.3 데이터 상태 색상

- 사용률 0–79%: `accent.mint`
- 사용률 80–94%: `accent.yellow` + `semantic.warning` 텍스트
- 사용률 95–100%: `accent.pink` + `semantic.danger` 텍스트
- 데이터 오류/동기화 실패: 색상과 함께 `exclamationmark.circle` 및 오류 문구 표시
- 핫스팟: 사용량 범례는 항상 `accent.lavender`
- iPhone: 사용량 범례는 항상 `accent.sky`

## 3. 배경 그라디언트

`background.softMesh`:

```swift
ZStack {
    Color(hex: "F7F9FF")
    RadialGradient(colors: [Color(hex: "DDF8F1").opacity(0.80), .clear],
                   center: .topLeading, startRadius: 16, endRadius: 260)
    RadialGradient(colors: [Color(hex: "E9E4FF").opacity(0.70), .clear],
                   center: .bottomTrailing, startRadius: 24, endRadius: 300)
}
```

런타임 성능이나 스냅샷 일관성이 중요하면 `SoftPastel-Mesh` PNG를 사용합니다. 콘텐츠 카드 뒤에서만 보이도록 대비를 낮게 유지합니다.

## 4. 타이포그래피

SF Pro 및 시스템 Dynamic Type을 사용합니다. 고정된 커스텀 폰트는 사용하지 않습니다.

| 역할 | SwiftUI | 기준 크기/행간 | Weight | 용도 |
|---|---|---:|---|---|
| Hero Number | `.system(size: 38, weight: .bold, design: .rounded)` | 38/44 | Bold | 남은 GB, 총 사용량 |
| Screen Title | `.title2` | 22/28 | Bold | 화면 제목 |
| Card Title | `.headline` | 17/22 | Semibold | 카드 제목 |
| Metric | `.title3` + rounded | 20/25 | Bold | 카드 내부 수치 |
| Body | `.body` | 17/22 | Regular | 주요 설명 |
| Secondary | `.subheadline` | 15/20 | Regular | 메타 정보 |
| Caption | `.caption` | 12/16 | Medium | 축, 배지, 범례 |
| Widget Hero | family별 24–32 pt | family별 | Bold rounded | 핵심 수치 |

규칙:

- 숫자는 `.monospacedDigit()` 적용으로 갱신 시 폭 변화 방지.
- `GB`, `%` 단위는 수치보다 한 단계 작게 사용.
- 핵심 수치 한 줄 유지. 접근성 크기에서 단위를 다음 줄로 내릴 수 있음.
- 한국어 최소 줄바꿈 단위는 의미 그룹. `남은 데이터`와 값은 분리 가능하지만 `87.6 GB` 내부는 분리하지 않음.

## 5. 간격과 레이아웃

8 pt 기반에 4 pt 보조 단위를 사용합니다.

| 토큰 | 값 | 용도 |
|---|---:|---|
| `space.1` | 4 | 아이콘-텍스트 미세 간격 |
| `space.2` | 8 | 밀접한 정보 |
| `space.3` | 12 | 카드 내부 소간격 |
| `space.4` | 16 | 기본 카드 패딩 |
| `space.5` | 20 | 화면 좌우 여백 |
| `space.6` | 24 | 큰 카드 패딩 |
| `space.8` | 32 | 섹션 간격 |
| `space.10` | 40 | 화면 상단 큰 호흡 |

기준 화면:

- Compact iPhone: 좌우 20 pt
- Plus/Max: 좌우 24 pt, 콘텐츠 최대 폭 560 pt
- iPad: 콘텐츠 최대 폭 720 pt, 카드 열은 2열 허용
- 카드 사이 간격: 12 pt
- 섹션 사이 간격: 24 pt
- 최소 터치 영역: 44 × 44 pt

## 6. 모서리와 테두리

| 토큰 | 값 | 용도 |
|---|---:|---|
| `radius.small` | 12 | 배지, 작은 컨트롤 |
| `radius.medium` | 18 | 소형 카드 |
| `radius.large` | 24 | 주요 카드, 게이지 영역 |
| `radius.pill` | 999 | 세그먼트, 캡슐 |

- 카드 테두리는 필요한 경우에만 1 px 사용.
- 인접 카드끼리 radius를 섞지 않습니다.
- 위젯 외곽 radius는 시스템 컨테이너가 담당합니다.

## 7. 그림자

```text
shadow.card = y 8, blur 24, spread 0, #36415C 8%
shadow.floating = y 12, blur 32, spread 0, #36415C 12%
```

다크 모드에서는 그림자 대신 `border.soft` 1 px로 깊이를 구분합니다. 위젯에서는 커스텀 외곽 그림자를 사용하지 않습니다.

## 8. 아이콘

- SF Symbols 우선. 권장 weight: `.medium`.
- 탭: `gauge.with.dots.needle.67percent`, `chart.bar.xaxis`, `personalhotspot`, `gearshape`
- 상태: `checkmark.circle.fill`, `exclamationmark.circle.fill`, `arrow.clockwise`, `wifi.slash`
- 아이콘만 있는 버튼에는 VoiceOver label 필수.
- 장식용 orbit/watermark는 접근성 트리에서 숨김.

## 9. 모션과 햅틱

- 숫자 갱신: 180 ms ease-out, content transition `.numericText()`.
- 게이지 변화: 350 ms ease-in-out. 첫 진입 시 0에서 채우는 연출은 1회만.
- 세그먼트 전환: 200 ms ease-out.
- `Reduce Motion` 활성화 시 위치/스케일 애니메이션 제거, 불투명도 전환만 사용.
- 수동 새로고침 성공 시 light impact 1회; 자동 갱신에는 햅틱 없음.

## 10. 접근성

- 본문/수치 대비 목표: WCAG AA 4.5:1 이상. 큰 텍스트는 3:1 이상.
- 게이지 VoiceOver 예시: `이번 달 데이터, 160기가 중 72.4기가 사용, 45퍼센트, 87.6기가 남음`.
- 차트는 시각 그래프 외에 요약 문장과 날짜별 값 목록을 제공합니다.
- 선택 상태는 체크 아이콘과 레이블로 함께 표현합니다.
- Dynamic Type `AX5`에서 카드 높이는 고정하지 않고 세로 확장합니다.
- `Increase Contrast`에서는 파스텔 테두리를 `text.secondary` 35% 색으로 강화합니다.
