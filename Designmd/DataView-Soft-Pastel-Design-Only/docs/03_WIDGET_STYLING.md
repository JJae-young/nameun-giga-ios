# 03. 위젯 스타일링

이 문서는 기존 WidgetKit 구성, 데이터와 Timeline을 유지하면서 위젯 외형만 Soft Pastel로 통일하는 기준입니다.

## 공통

- 기존 supportedFamilies와 딥링크를 변경하지 않습니다.
- `.containerBackground(for: .widget)` 구조를 유지합니다.
- 배경은 Canvas 또는 매우 옅은 Soft Pastel mesh.
- 핵심 수치는 Text Primary, 보조 정보는 Text Secondary.
- 시스템 여백과 widget content margin을 임의로 제거하지 않습니다.
- 개인정보 보호와 redaction 표현을 유지합니다.

## Small

참조 이미지: `assets/png/reference/Ref-Widget-Small@3x.png`

- 상단: 작은 심볼과 `이번 달` 레이블.
- 중앙: Mint 원형 게이지, 옅은 blue-gray track.
- 중앙 퍼센트는 Bold Rounded.
- 하단 남은 데이터는 한 줄의 Bold 텍스트.
- 장식은 최소화하고 게이지와 수치가 먼저 읽히게 합니다.

## Medium

참조 이미지: `assets/png/reference/Ref-Widget-Medium@3x.png`

- 좌측에 남은 데이터와 progress.
- 우측에 흰색 반투명 그룹 표면.
- iPhone 행은 Sky tint, 핫스팟 행은 Lavender tint.
- `87.6`이 가장 크고, `72.4 / 160 GB`는 두 번째 위계.
- 기존 탭 대상과 데이터 표현은 변경하지 않습니다.

## 잠금화면 직사각형

참조 이미지: `assets/png/reference/Ref-Widget-Lock-Rectangular@3x.png`

- 시스템 monochrome/tinted 렌더링을 우선합니다.
- leading 원형 게이지와 2행 텍스트 구조.
- 별도의 파스텔 배경 이미지나 그림자를 사용하지 않습니다.
- 텍스트는 최대 2행이며 기존 privacy 처리와 호환되어야 합니다.

## accessoryCircular / accessoryInline

- Circular: 시스템 Gauge와 중앙 퍼센트만 사용.
- Inline: 기존 한 줄 카피를 유지하고 불필요한 장식 추가 금지.
- 시스템 tint에서 사라지는 고정색을 사용하지 않습니다.

## 다크 및 tinted 렌더링

- 앱의 다크 팔레트 또는 WidgetKit의 시스템 렌더링을 사용합니다.
- Light PNG를 강제로 반전하지 않습니다.
- 게이지와 텍스트가 tinted/monochrome 모드에서도 구분되는지 확인합니다.

