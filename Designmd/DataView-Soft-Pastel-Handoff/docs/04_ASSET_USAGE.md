# 04. 이미지 자산 사용 가이드

## 1. 런타임 자산

| 파일 | 크기 | Alpha | 권장 Asset Catalog 이름 | 용도 |
|---|---:|---|---|---|
| `AppIcon-SoftPastel-1024.png` | 1024 × 1024 | 없음 | AppIcon | iOS 앱 아이콘 master |
| `SoftPastel-Mesh@1x.png` | 393 × 852 | 없음 | SoftPastelMesh | 화면 배경 선택안 |
| `SoftPastel-Mesh@2x.png` | 786 × 1704 | 없음 | SoftPastelMesh | 화면 배경 선택안 |
| `SoftPastel-Mesh@3x.png` | 1179 × 2556 | 없음 | SoftPastelMesh | 화면 배경 선택안 |
| `DataOrbit-Watermark@1x.png` | 256 × 256 | 있음 | DataOrbitWatermark | Hero 장식 워터마크 |
| `DataOrbit-Watermark@2x.png` | 512 × 512 | 있음 | DataOrbitWatermark | Hero 장식 워터마크 |
| `DataOrbit-Watermark@3x.png` | 768 × 768 | 있음 | DataOrbitWatermark | Hero 장식 워터마크 |
| `EmptyState-Data@1x.png` | 160 × 120 | 있음 | EmptyStateData | 사용 기록 없음 |
| `EmptyState-Data@2x.png` | 320 × 240 | 있음 | EmptyStateData | 사용 기록 없음 |
| `EmptyState-Data@3x.png` | 480 × 360 | 있음 | EmptyStateData | 사용 기록 없음 |

### AppIcon

- Xcode의 single-size 1024 × 1024 AppIcon 워크플로에 바로 사용합니다.
- 모서리를 이미지 자체에서 둥글게 자르지 않습니다. iOS가 마스크를 적용합니다.
- 투명 픽셀이 없으며 sRGB RGB PNG입니다.
- 작은 크기에서도 읽히도록 문자나 세밀한 선을 넣지 않았습니다.

### SoftPastel Mesh

- 이미지 뷰를 `.scaledToFill()`하고 화면 경계에서 clip.
- 콘텐츠와 함께 스크롤하지 않고 배경에 고정.
- 다크 모드에서는 이 PNG를 색 반전하지 말고 토큰 기반 다크 그라디언트를 사용.
- 권장안은 SwiftUI 네이티브 그라디언트이며, 이 파일은 스냅샷 일치 또는 저사양 fallback 용도.

### DataOrbit Watermark

- `template` rendering mode 금지. 원본 파스텔 색 유지.
- Hero 카드 우측 상단에 96–132 pt로 배치, opacity 0.35–0.55.
- 핵심 텍스트 뒤에 겹치지 않도록 trailing 영역에만 배치.
- 장식 이미지이므로 VoiceOver에서 숨김.

### EmptyState Data

- 최대 표시 크기 160 × 120 pt.
- 상단 장식, 아래에 `이번 달 사용 기록이 아직 없어요` 문구와 필요 시 CTA.
- 이미지만으로 상태나 행동을 설명하지 않음.
- 다크 모드에서는 opacity 0.85와 별도 텍스트 색 토큰을 사용. 강제 색 반전 금지.

## 2. 참조 자산

`assets/png/reference/` 파일은 구현 비교와 QA용이며 앱 번들에 포함하지 않습니다.

| 파일 | 목적 |
|---|---|
| `Ref-Screen-Home@3x.png` | 홈 레이아웃, 계층, 색상 기준 |
| `Ref-Screen-Statistics@3x.png` | 통계 차트와 기간 선택 기준 |
| `Ref-Screen-Hotspot@3x.png` | 핫스팟 상태/기기 목록 기준 |
| `Ref-Screen-Settings@3x.png` | 테마 선택 및 설정 그룹 기준 |
| `Ref-Widget-Small@3x.png` | Small 위젯 기준 |
| `Ref-Widget-Medium@3x.png` | Medium 위젯 기준 |
| `Ref-Widget-Lock-Rectangular@3x.png` | 잠금화면 직사각형 기준 |
| `Ref-Overview.png` | 전체 전달/리뷰용 보드 |

## 3. 편집 원본

- 모든 PNG는 `assets/source/`의 같은 이름 SVG에서 생성되었습니다.
- SVG는 편집/재수출용이며 iOS 런타임 사용을 전제로 하지 않습니다.
- 원본의 텍스트는 시스템 폰트에 의존하므로 다른 OS에서 열면 자간이 조금 달라질 수 있습니다.
- 아이콘은 외부 라이브러리 파일을 포함하지 않고 단순 도형으로 제작했습니다. 앱 구현에서는 SF Symbols로 교체합니다.

## 4. 내보내기 규칙

- Color space: sRGB
- Bit depth: 8-bit/channel
- 배경 자산/AppIcon: RGB
- 워터마크/EmptyState: RGBA
- 리사이징: Lanczos3
- 앱에서 임의 JPEG 변환 금지
- 에셋 이름은 `code/AssetNames.swift`와 동일하게 유지

## 5. 저작권 및 사용 범위

패키지의 그래픽은 DataView Soft Pastel 핸드오프를 위해 새로 제작한 기하학적 자산입니다. 외부 사진, 로고, 유료 아이콘 또는 서드파티 일러스트를 포함하지 않습니다. `LICENSE-ASSETS.md`도 확인하세요.

