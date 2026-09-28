# DataView Soft Pastel — Design Only

이 패키지는 **완성된 DataView의 기능을 그대로 유지하면서 시각 디자인만 Soft Pastel 테마로 변경**하기 위한 자료입니다.

## 작업 범위

변경해도 되는 항목:

- 색상과 그라디언트
- 글꼴 크기, 굵기, 행간
- 여백과 정렬
- 카드 배경, 모서리, 테두리, 그림자
- 게이지와 차트의 시각 스타일
- 탭과 설정 항목의 선택 표현
- 앱 아이콘과 장식 이미지
- 위젯의 시각적 정보 위계

변경하면 안 되는 항목:

- 데이터 수집과 계산 로직
- 상태 관리와 저장 방식
- 네트워크, 동기화, 새로고침 로직
- 화면 이동과 딥링크
- 버튼, 토글, 탭의 동작
- 위젯 Timeline과 갱신 정책
- 권한 및 핫스팟 처리
- 기존 데이터 모델과 공개 API

기능 변경이 필요해 보이더라도 이 패키지의 범위에서는 진행하지 않습니다.

## 포함 파일

- `docs/01_STYLE_SYSTEM.md` — 색상, 타이포그래피, 간격, 카드와 차트 스타일
- `docs/02_APP_STYLING.md` — 홈, 통계, 핫스팟, 설정 화면의 외형
- `docs/03_WIDGET_STYLING.md` — Small, Medium, 잠금화면 위젯의 외형
- `docs/04_ASSET_GUIDE.md` — PNG와 SVG 사용 방법
- `docs/05_VISUAL_QA.md` — 디자인 적용 완료 기준
- `APPLY_PROMPT.md` — 구현 담당자나 코딩 에이전트에 그대로 전달할 지시문
- `tokens/soft-pastel.tokens.json` — 디자인 토큰
- `assets/png/runtime/` — 앱에 포함할 수 있는 PNG
- `assets/png/reference/` — 구현 비교용 기준 시안
- `assets/source/` — 편집 가능한 SVG 원본

## 적용 순서

1. `APPLY_PROMPT.md`와 이 README를 구현 담당자에게 전달합니다.
2. `01_STYLE_SYSTEM.md`의 토큰을 기존 테마 계층에 매핑합니다.
3. `02_APP_STYLING.md`와 `03_WIDGET_STYLING.md`를 기준으로 기존 화면의 외형만 바꿉니다.
4. `assets/png/reference/Ref-Overview.png`와 실제 결과를 비교합니다.
5. `05_VISUAL_QA.md`만 사용해 디자인 회귀를 확인합니다.

## 기준 시안

전체 화면과 위젯의 기준 이미지는 `assets/png/reference/Ref-Overview.png`입니다. 기준 시안은 **색, 밀도, 크기 관계와 정보 위계**를 보여주기 위한 것이며, 기존 앱의 기능 구조를 대체하라는 의미가 아닙니다.

우선순위가 충돌하면 다음 순서를 따릅니다.

1. 기존 앱의 기능과 화면 구조
2. 이 패키지의 디자인 토큰
3. 화면별 스타일 명세
4. 기준 PNG의 세부 표현

