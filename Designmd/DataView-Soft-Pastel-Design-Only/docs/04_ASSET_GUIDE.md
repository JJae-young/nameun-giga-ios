# 04. 이미지 자산 가이드

## 런타임 PNG

| 자산 | 크기 | 용도 |
|---|---:|---|
| `AppIcon-SoftPastel-1024.png` | 1024 × 1024 | AppIcon master |
| `SoftPastel-Mesh@1x/2x/3x.png` | 393 × 852 기준 | 선택적 화면 배경 |
| `DataOrbit-Watermark@1x/2x/3x.png` | 256 × 256 기준 | 선택적 Hero 장식 |
| `EmptyState-Data@1x/2x/3x.png` | 160 × 120 기준 | 데이터 없음 장식 |

위치는 `assets/png/runtime/`입니다.

### 사용 원칙

- AppIcon은 투명도가 없는 sRGB 1024px master입니다.
- Mesh는 화면에 고정하고 `scaledToFill`로 배치합니다.
- Watermark는 96–132 pt, opacity 0.35–0.55로 사용합니다.
- EmptyState는 최대 160 × 120 pt로 사용합니다.
- Watermark와 EmptyState는 장식이므로 접근성 트리에서 숨깁니다.
- 배경과 장식 PNG는 필수가 아닙니다. 기존 SwiftUI shape/gradient 구조가 있다면 같은 토큰으로 재현해도 됩니다.

## 기준 시안 PNG

위치는 `assets/png/reference/`입니다.

- `Ref-Overview.png`
- `Ref-Screen-Home@3x.png`
- `Ref-Screen-Statistics@3x.png`
- `Ref-Screen-Hotspot@3x.png`
- `Ref-Screen-Settings@3x.png`
- `Ref-Widget-Small@3x.png`
- `Ref-Widget-Medium@3x.png`
- `Ref-Widget-Lock-Rectangular@3x.png`

이 파일들은 앱 번들에 포함하지 않습니다. 구현 비교와 리뷰에만 사용합니다.

## SVG 원본

`assets/source/`에는 모든 그래픽과 기준 시안의 편집 가능한 SVG가 있습니다. 앱 구현에서는 기존 SF Symbols와 SwiftUI 도형을 우선하고, SVG는 수정과 PNG 재수출에 사용합니다.

## 이름과 내보내기

- 색상 프로파일: sRGB
- PNG: 8-bit RGB 또는 RGBA
- 리사이징: Lanczos 계열 권장
- JPEG 변환 금지
- 기존 Asset Catalog naming convention이 있다면 이름은 프로젝트 규칙에 맞춰 변경 가능

