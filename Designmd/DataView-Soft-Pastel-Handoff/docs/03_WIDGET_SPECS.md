# 03. 위젯 명세

위젯의 1순위 정보는 **남은 데이터**, 2순위는 **사용률**, 3순위는 **사용처 분해**입니다. Small/Medium은 Soft Pastel 색을 사용하고, 잠금화면 accessory family는 시스템 tint와 고대비를 우선합니다.

## 공통 데이터 정책

- Timeline 갱신: 데이터 소스 정책 범위에서 최소 30분 간격을 권장. 앱 foreground 갱신 후 WidgetCenter reload.
- 2시간 이상 갱신 실패: 캐시 값을 유지하고 `업데이트 필요` 또는 갱신 아이콘 표시.
- 24시간 이상 갱신 실패: 수치를 숨기지 말고 날짜를 명시.
- 개인정보 보호 모드: 잠금 상태에서 정확한 GB 대신 `45% 사용`만 표시 가능.
- 딥링크: Small/Medium 탭 → 앱 홈, 핫스팟 보조 영역 → 핫스팟 상세.

## A. systemSmall

기준 콘텐츠 영역: 약 158 × 158 pt. 시스템 여백은 WidgetKit 환경값을 사용합니다.

### 구성

- 상단: 앱 심볼 + `이번 달`
- 중앙: 78 pt 원형 게이지
- 중앙 텍스트: `45%`
- 하단: `87.6 GB 남음`
- 갱신일은 공간이 허용될 때만 caption으로 표시

### 규칙

- 배경: 아주 옅은 soft mesh 또는 `#F7F9FF` 단색.
- ring track: `#E7ECF6`, progress: `accent.mint`.
- `.containerBackground(for: .widget)` 사용.
- 긴 숫자에서는 `minimumScaleFactor(0.78)`, 한 줄 유지.

참조: `assets/png/reference/Ref-Widget-Small@3x.png`

## B. systemMedium

기준 콘텐츠 영역: 약 338 × 158 pt.

### 구성

- 좌측 36%: 제목, `87.6 GB`, `남음`, 사용률 progress bar
- 우측 64%: `72.4 / 160 GB`와 iPhone/핫스팟 2개 틴트 영역
- iPhone `54.2 GB`, 핫스팟 `18.2 GB`

### 규칙

- 시선 순서가 남은 데이터 → 총 사용량 → 사용처가 되도록 값 크기를 차등.
- 틴트 영역은 카드처럼 떠 보이기보다 한 배경 안의 두 구획으로 처리.
- widget margin을 임의로 0으로 만들지 않음.
- Dynamic Type가 크면 보조 레이블을 줄이고 핵심 수치는 유지.

참조: `assets/png/reference/Ref-Widget-Medium@3x.png`

## C. accessoryRectangular

### 구성

- 1행: `데이터 45% 사용`
- 2행: `87.6 GB 남음 · 9월 25일 갱신`
- 선택적 leading gauge 아이콘

### 규칙

- 색상은 `.widgetAccentable()` 및 시스템 monochrome을 따름.
- 배경 이미지와 파스텔 면을 사용하지 않음.
- 텍스트 2행을 초과하지 않음.
- privacy redaction에서도 구조가 유지되어야 함.

참조: `assets/png/reference/Ref-Widget-Lock-Rectangular@3x.png`

## D. accessoryCircular

- 원형 gauge + 중앙 `45`.
- `%`는 accessibility label에 포함하고, 시각적으로는 생략 가능.
- `Gauge(value: 72.4, in: 0...160)` 기반.
- complication 크기에서 `GB` 수치는 표시하지 않음.

## E. accessoryInline

- 문자열: `데이터 87.6GB 남음`.
- 실패 상태: `데이터 업데이트 필요`.
- 최대 한 줄, 장식 아이콘은 1개 이하.

## 상태별 카피

| 상태 | 제목 | 보조 문구 |
|---|---|---|
| 정상 | `87.6 GB 남음` | `45% 사용` |
| 80% 이상 | `32.0 GB 남음` | `사용량을 확인하세요` |
| 95% 이상 | `8.0 GB 남음` | `거의 다 사용했어요` |
| 초과 | `4.1 GB 초과` | `한도를 넘었어요` |
| 무제한 | `72.4 GB 사용` | `무제한 요금제` |
| 미설정 | `요금제를 설정하세요` | 앱 열기 |
| 오래된 데이터 | `87.6 GB 남음` | `어제 업데이트됨` |

## 스냅샷 테스트 필수 케이스

- 0%, 45%, 80%, 95%, 100%, 110%
- 500 MB 이하, 999.9 GB, 1.25 TB
- 한국어/영어
- Light/Dark, tinted rendering, increased contrast
- 개인정보 보호 redaction
- 데이터 없음/오류/오래된 캐시

