# 01. Soft Pastel 스타일 시스템

## 디자인 방향

Soft Pastel은 민트, 하늘색, 연보라와 옅은 핑크를 사용하는 밝고 차분한 테마입니다. 파스텔 색은 장식보다 **데이터 그룹을 구분하는 표면색**으로 사용하고, 핵심 숫자와 본문은 짙은 네이비로 명확하게 표현합니다.

핵심 인상: `soft`, `airy`, `friendly`, `data-first`

## 색상

| 역할 | Light | Dark | 사용처 |
|---|---|---|---|
| Canvas | `#F7F9FF` | `#111525` | 전체 배경 |
| Elevated | `#FFFFFF` | `#1B2133` | 주요 카드 |
| Subtle | `#EFF4FF` | `#232A40` | 그룹 배경 |
| Text Primary | `#20263A` | `#F5F7FF` | 제목과 핵심 수치 |
| Text Secondary | `#66708A` | `#B9C1D7` | 설명과 단위 |
| Text Tertiary | `#68728B` | `#8E98B2` | 메타데이터 |
| Border Soft | `#E4E9F5` | `#303951` | 구분선 |
| Mint | `#74D7C4` | `#62C9B6` | 기본 게이지와 선택 |
| Mint Strong | `#176B5B` | `#88E3D1` | 활성 탭과 강조 텍스트 |
| Sky | `#A8D8FF` | `#74BDF3` | iPhone 데이터 |
| Lavender | `#C3B5FA` | `#A895F0` | 핫스팟 데이터 |
| Pink | `#F7C4D7` | `#EAAAC3` | 보조 강조 |
| Yellow | `#FFE2A6` | `#E9C875` | 주의 표현 |

틴트 표면:

- Mint surface: `#EAF9F5`
- Sky surface: `#EDF7FF`
- Lavender surface: `#F2EFFF`
- Pink surface: `#FFF1F6`

파스텔 표면 위에 흰색 본문을 사용하지 않습니다. 텍스트는 `Text Primary` 또는 `Text Secondary`를 사용합니다.

## 배경

- 기본색은 `Canvas`.
- 좌측 상단에 낮은 농도의 민트 radial gradient.
- 우측 하단에 낮은 농도의 라벤더 radial gradient.
- 상단 우측에는 필요한 화면에서만 매우 옅은 핑크 glow 사용.
- 그라디언트가 카드와 숫자의 가독성을 방해하면 농도를 낮춥니다.
- `SoftPastel-Mesh` PNG를 사용할 때는 화면에 고정하고 `scaledToFill`로 배치합니다.

## 타이포그래피

시스템 SF Pro를 유지합니다. 새로운 커스텀 폰트는 추가하지 않습니다.

| 역할 | 기준 | Weight |
|---|---:|---|
| 화면 제목 | 28 pt | Bold |
| Hero 숫자 | 36–38 pt, Rounded | Bold |
| 카드 제목 | 16–17 pt | Semibold |
| 카드 수치 | 17–20 pt, Rounded | Bold |
| 본문 | 15–17 pt | Regular |
| 보조 문구 | 13–15 pt | Regular/Medium |
| Caption | 11–12 pt | Medium |

- 숫자에는 monospaced digit을 적용합니다.
- `GB`, `%` 같은 단위는 숫자보다 작고 `Text Secondary`로 표시합니다.
- 핵심 수치와 단위는 가능한 한 한 줄을 유지합니다.
- 기존 Dynamic Type 대응을 제거하거나 고정 높이로 바꾸지 않습니다.

## 간격

| 토큰 | 값 |
|---|---:|
| XS | 4 pt |
| S | 8 pt |
| M | 12 pt |
| L | 16 pt |
| XL | 20 pt |
| XXL | 24 pt |
| Section | 32 pt |

- 화면 좌우 여백: 20 pt
- 카드 내부 여백: 16–20 pt
- 카드 사이: 12 pt
- 섹션 사이: 24–32 pt
- 기존 safe area와 시스템 콘텐츠 여백은 유지합니다.

## 카드

- 주요 카드 radius: 24 pt
- 작은 내부 영역 radius: 16–18 pt
- 배지와 세그먼트 radius: pill
- 카드 그림자: `y 8 / blur 24 / #36415C 8%`
- 다크 모드에서는 강한 그림자 대신 `Border Soft` 1 pt 사용
- 모든 내용을 별도 카드로 만들지 않고 의미상 하나의 그룹만 카드로 묶습니다.
- 카드 안에 다시 흰색 카드를 중첩하지 않습니다. 내부 구분은 틴트 영역으로 표현합니다.

## 게이지와 차트

- 기본 게이지 진행색: Mint
- 게이지 track: `#E7ECF6`
- 원형 게이지 stroke: 12–13 pt
- iPhone 계열: Sky
- 핫스팟 계열: Lavender
- 현재 선택한 날짜나 막대: Mint Strong
- 차트 기준선: Border Soft 1 pt
- 막대와 선의 끝은 둥글게 처리합니다.
- 기존 차트 데이터, 축 계산과 선택 동작은 변경하지 않습니다.

## 아이콘과 선택 상태

- 기존 SF Symbols를 유지합니다.
- 아이콘 weight는 medium 권장.
- 활성 탭: Mint Strong + Mint tint 캡슐.
- 비활성 탭: Text Tertiary.
- 선택 설정: 체크 아이콘과 텍스트 굵기를 함께 사용합니다.
- 색만으로 선택 또는 상태를 표현하지 않습니다.

## 시각 접근성

- 본문과 핵심 수치는 기존 대비 수준을 낮추지 않습니다.
- 작은 텍스트에는 Mint, Sky, Lavender 원색을 직접 사용하지 않습니다.
- 최소 터치 영역과 VoiceOver 순서는 기존 구현을 유지합니다.
- Reduce Motion, Increase Contrast 및 Dynamic Type 대응을 제거하지 않습니다.

