# 02. 앱 화면 스타일링

이 문서는 기존 화면의 **내용과 동작을 유지한 상태에서 외형을 바꾸는 기준**입니다. 기준 이미지는 393 × 852 pt 화면을 3x로 내보낸 것입니다.

## 공통 셸

- 전체 배경에 Soft Pastel canvas와 낮은 농도의 mesh를 적용합니다.
- 화면 제목은 28 pt Bold, `Text Primary`.
- 기존 내비게이션과 safe area를 유지합니다.
- 하단 탭은 흰색 반투명 표면과 상단 1 pt 구분선을 사용합니다.
- 활성 탭 아이콘 뒤에 Mint tint 캡슐을 배치합니다.
- 기존 탭 순서, 레이블과 이동 경로는 변경하지 않습니다.

## 홈 / 데이터

참조 이미지: `assets/png/reference/Ref-Screen-Home@3x.png`

### 월간 요약

- 흰색 24 pt radius 카드.
- 좌측에 Mint 원형 게이지, 우측에 남은 데이터 수치.
- `남은 데이터`는 Secondary, `87.6`은 36–38 pt Bold Rounded.
- `GB` 단위는 작은 Secondary 텍스트.
- 갱신일은 Mint tint 캡슐.
- 기존 표시 값, 계산 방식과 갱신 동작은 그대로 유지합니다.

### 오늘 사용량

- 카드 제목과 합계를 한 행에 배치합니다.
- iPhone 영역은 Sky tint, 핫스팟 영역은 Lavender tint.
- 두 영역은 별도 floating card가 아니라 같은 카드 안의 구획으로 표현합니다.

### 최근 사용량 차트

- 흰색 카드에 옅은 기준선.
- 일반 막대는 Sky, 현재 날짜는 Mint Strong.
- 날짜 레이블은 Tertiary, 현재 날짜만 Mint Strong + Semibold.
- 기존 차트 유형과 상호작용은 유지합니다.

## 통계

참조 이미지: `assets/png/reference/Ref-Screen-Statistics@3x.png`

- 기간 선택기는 Subtle 배경의 pill 형태.
- 선택 항목은 흰색 표면과 얕은 그림자.
- 총 사용량은 화면에서 가장 큰 숫자로 표시합니다.
- 막대 차트는 Sky 중심, 선택 막대는 Mint.
- iPhone/핫스팟 비중 바는 Sky와 Lavender로 구분합니다.
- 인사이트 영역은 Mint tint 단일 블록으로 표현합니다.
- 기존 기간 종류, 차트 값과 선택 동작은 변경하지 않습니다.

## 핫스팟

참조 이미지: `assets/png/reference/Ref-Screen-Hotspot@3x.png`

- 상단 상태 영역은 Lavender tint의 24 pt radius 카드.
- 상태 아이콘은 흰색 원 안에 Lavender 강조색.
- 연결 수치를 큰 Bold 텍스트로 표시합니다.
- 월 사용량 카드는 흰색, progress는 Lavender.
- 연결 기기 아바타는 Sky/Pink tint 원형 배경.
- 연결 상태 문구는 고대비 성공색을 사용합니다.
- 기존 연결 상태 판정, 권한과 기기 목록 동작은 변경하지 않습니다.

## 설정

참조 이미지: `assets/png/reference/Ref-Screen-Settings@3x.png`

- 설정은 섹션 제목 + 흰색 grouped card 구조.
- 행 사이에는 Border Soft 1 pt 구분선.
- 테마 미리보기는 3개의 작은 색상 원으로 표현합니다.
- Soft Pastel 선택 상태는 Mint Strong 체크 원을 사용합니다.
- 기존 토글과 disclosure indicator를 유지합니다.
- 위험 동작 텍스트에는 기존 semantic danger 색을 유지하거나 `#A43A58`을 사용합니다.
- 설정 항목의 추가, 삭제, 이름 변경 또는 동작 변경은 하지 않습니다.

## 작은 화면 대응

- 기존 반응형 분기와 스크롤 구조를 유지합니다.
- 좁은 화면에서 Hero가 겹치면 게이지와 수치를 세로 배치합니다.
- 고정 높이 추가로 인해 기존 Dynamic Type이 잘리지 않게 합니다.
- 기준 PNG의 정확한 좌표보다 기존 앱의 콘텐츠 적응성을 우선합니다.

