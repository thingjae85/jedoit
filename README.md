# 저두잇

작은 개인 미션을 지인 챌린지로 연결하고, 참여에 따라 공동 책상이 정돈되는 Flutter Web 앱입니다.
현재 구현된 것:
- 개인 미션 4개 체험, 완료 체크·메모를 기기에 기록 (1주차)
- Google 로그인, 로그인 전 체험 기록을 30분 보관했다가 계정에 저장
- 방 만들기·초대 QR/링크(`?invite=`)·참가, 방 전용 닉네임, 시작 확정
- 3일 사진 인증(1280px JPEG 재인코딩, 위치정보 제거), 진행도 H/T와 공동 목표 G
- 공동 책상 그림 (정리된 요소 H개는 가지런히, 나머지는 흐트러짐)
- 내 인증의 사진 삭제·인증 취소 (획득 보상 유지), 계정 삭제 요청 (7일 이내 처리)

다음: 시연용 익명 참가(QR 찍고 닉네임만), Android APK.

- 웹에서 보기: https://thingjae85.github.io/jedoit/ (GitHub Pages, `main`에 푸시하면 자동 배포)
- 설계 문서: [docs/저두잇_설계수정안_v2.md](docs/저두잇_설계수정안_v2.md)
- 주간보고: [docs/weekly/](docs/weekly/)
- 오류 기록: [docs/오류기록.md](docs/오류기록.md)

## 폴더 구조
| 경로 | 내용 |
| --- | --- |
| `lib/` | 앱 소스 (screens, models, services, utils) |
| `test/` | 자동 테스트 |
| `web/` | Flutter Web 설정 (index.html, manifest) |
| `scripts/` | Windows 실행 스크립트 |
| `supabase/migrations/` | Supabase SQL 변경 파일 (순서대로 적용, 3주차부터 사용) |
| `.github/workflows/` | GitHub Pages 자동 배포 |
| `docs/` | 설계 문서, 주간보고, 오류 기록 |

## 1주차 수정 내용

- 홈: 오늘 완료 횟수, 전체 기록 수, 미션별 오늘 완료 표시
- 화면: 초록색 테마, 본문 최대 폭 640, 빈 기록 화면 안내
- 미션: 단계 안내, 아이콘, 타이머 진행 막대, 조기 완료 안내
- 오류 처리: 기록 불러오기 재시도, 저장 및 삭제 실패 알림
- 보고: 주간보고 초안, 발표 대본, 시연 체크리스트

## Windows에서 시작
Flutter를 PATH에 등록한 뒤 `시작하기.bat`을 더블클릭합니다.
처음에는 Android/web 기본 폴더와 패키지를 준비하며 시간이 걸릴 수 있습니다.
Chrome 창이 열리면 터미널 창은 켜 둡니다. 종료할 때 터미널에서 Ctrl+C를 누릅니다.

직접 실행할 경우:
1. `scripts\setup.bat` — 최초 환경 준비
2. `scripts\run_web.bat` — Chrome 시연 (고정 포트 7357)
3. `scripts\run_android.bat` — Android 기기 선택 실행
4. `scripts\test.bat` — 코드 분석·자동 테스트
5. `scripts\build_apk.bat` — Android 릴리스 APK 빌드

Android 실행에는 Android SDK와 연결된 기기 또는 에뮬레이터가 필요합니다.
웹 실행만으로 Android 동작까지 확인된 것은 아닙니다.

## 시연 순서 (약 1분)
물 한 잔 마시기 → 시작하기 → 완료 체크 → 메모 입력 → 저장 → 오늘 횟수 확인 → 내 기록.
그다음 정리 미션의 타이머를 시작해서 보여 줍니다. 5분을 기다릴 필요는 없습니다.
메모를 기록하려면 실제로 실천한 뒤 완료 체크합니다.

## 데이터
기록은 현재 기기/브라우저에만 저장됩니다. 다른 컴퓨터와 동기화되지 않습니다.
웹 주소나 포트가 달라지면 별도 저장 공간으로 처리됩니다. 브라우저 데이터를 지우면 기록이 사라질 수 있습니다.
타이머는 실행 중 화면에서 사용하는 보조 기능이며, 앱 종료 후 복원이나 백그라운드 알림은 지원하지 않습니다.

## Supabase 설정
`supabase/migrations/`의 SQL을 번호 순서대로 Supabase SQL Editor에서 실행합니다.
앱에는 publishable 키만 들어갑니다(`lib/config.dart`). service_role 키와 DB 비밀번호는 저장소에 넣지 않습니다.

## 검증 상태
2026-10-26 Flutter 3.47.8 (Dart 3.13.7, Linux)에서 확인했습니다.
- `flutter analyze`: 오류 없음, const 권장 안내(info) 3건
- `flutter test`: 29개 테스트 모두 통과 (서버는 가짜 구현으로 대체)
- `flutter build web`: 성공
- SQL: 로컬 PostgreSQL 16에서 기획서 예시(4명 중 1명 이탈 시 T=10, G=7) 확인. 실제 Supabase에서의 로그인·업로드는 아직 확인 전

PC Chrome과 iPhone Safari의 실제 동작, Android APK는 아직 확인하지 않았습니다.

자세한 과제 설명은 `docs/weekly/주간보고_1주차.md`, 발표용 한 장 자료는 `docs/weekly/주간보고_1주차.html`을 참고하세요.
