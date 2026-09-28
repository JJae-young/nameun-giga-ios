# 남은기가 출시 체크리스트

최종 업데이트: 2026-09-26

## 코드에서 완료된 항목

- 핫스팟(테더링) 사용량 자동 측정을 베타로 추가: `bridge*`·`ap*` 인터페이스 변화량, 셀룰러 증가량을 상한으로 사용, 핫스팟 한도·80/90% 알림·통신사 값 맞추기 (실기기 검증 전)
- 측정값 명칭을 과도한 정확도를 암시하지 않는 `현재 사용량`으로 정정
- 첫 설정에서 통신사 앱의 현재 사용량을 선택적으로 입력 가능
- 홈과 설정에서 통신사 앱의 사용량 또는 남은 데이터를 기준값으로 다시 동기화 가능
- 수동 보정값과 기간별 차트의 범위를 구분해 안내
- 일별·주별·월별 평균 라벨 정정
- 앱/위젯 버전 번호를 Xcode 빌드 설정에서 공통 관리
- 한국어 개발 언어, iPad 회전 방향, 수출 규정 플래그 설정
- App Store Release 빌드는 App Group만 사용하고 Keychain fallback은 Debug 빌드로 제한
- 개인정보 manifest 및 1024×1024 불투명 앱 아이콘 포함
- Release 무서명 빌드 및 단위 테스트 91개 통과
- 시간 변경 오인에 따른 재합산, 보정 시점 중복, 주기 경계·숫자 입력·위젯 갱신 상태 개선 ([상세 점검 결과](MEASUREMENT_REVIEW.md))

## 출시를 막는 결정 및 외부 준비

- [ ] Apple Developer Program 배포 팀 선택
- [ ] 앱 ID, 위젯 Extension ID, App Group을 배포 계정에 등록
- [ ] App Store Connect에서 `남은기가` 이름 예약
- [ ] 개인정보처리방침 URL 게시 및 앱 안에 링크 연결
- [ ] Support URL과 실제 문의처 준비
- [ ] iPhone 전용으로 출시할지, 셀룰러 iPad까지 지원할지 결정
- [ ] Distribution Archive를 Validate App으로 검증
- [ ] TestFlight 내부/외부 테스트 완료

## App Store Connect 자료

- [ ] 한국어 이름, 부제, 설명, 키워드
- [ ] 카테고리, 연령 등급, 저작권, 가격, 출시 국가
- [ ] App Privacy를 실제 동작에 맞게 작성(현재 구조는 Data Not Collected)
- [ ] EU 배포 시 DSA trader status 설정
- [ ] 심사 연락처와 Review Notes 입력
- [ ] alpha 없는 iPhone 6.9인치 스크린샷
- [ ] iPad를 지원한다면 alpha 없는 13인치 iPad 스크린샷

## Review Notes에 포함할 측정 설명

- 첫 실행은 기존 누적 카운터를 사용량으로 간주하지 않고 기준점만 설정함
- 입력하지 않은 설치 전 사용량은 알 수 없으며 수동 기준값으로 반영할 수 있음
- 공개 네트워크 인터페이스 변화량을 측정하므로 통신사 과금량과 차이가 날 수 있음
- 표시값은 기기에서 관찰한 셀룰러 변화량과 사용자가 입력한 통신사 기준값의 합계임
- 개인용 핫스팟 합계는 공개 API로 제공되지 않으며, 값 차이는 통신사 기준값 재동기화로 보정함
- 백그라운드 및 위젯 갱신 시각은 iOS가 결정하므로 실시간을 보장하지 않음
- 검증 절차: 요금제 설정 → 필요 시 현재 사용량 입력 → 셀룰러 트래픽 발생 → 앱/위젯 새로고침

## TestFlight 최소 검증표

- [ ] iOS 17 및 최신 iOS
- [ ] 단일 SIM 및 듀얼 SIM
- [ ] Wi-Fi ↔ 셀룰러 전환, 비행기 모드, VPN
- [ ] 재부팅 전후 및 날짜/요금제 초기화일 경계
- [ ] Background App Refresh 비활성 상태
- [ ] 핫스팟: 설정 > 측정 > 인터페이스 진단에서 기준 저장 → 노트북 연결 후 500MB 다운로드 → 어떤 인터페이스가 늘고 핫스팟 종료 후 사라지는지 기록, 통신사 테더링 사용량과 비교
- [ ] 라이트, 다크, 틴트 위젯과 각 위젯 크기
- [ ] 앱 삭제·재설치와 데이터 초기 상태
- [ ] VoiceOver, Larger Text, Reduce Motion
- [ ] iPad 지원 시 회전, Split View, 셀룰러 없음 상태

## Apple 참고 문서

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Store 필수 버전 정보: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- 스크린샷 규격: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- 앱 개인정보: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- 심사 제출: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app
