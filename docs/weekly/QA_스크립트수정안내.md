# 실행 스크립트 수정본

2026-10-13 코드 검토 후 발표 준비를 돕기 위해 실행 스크립트만 수정한 별도 사본입니다.
원본 lib/ 및 test/의 Dart 코드는 그대로입니다. 타이머·저장 오류·동시성은 수정 전이며 QA 가이드를 참고하세요.
Flutter 정적 분석·8개 테스트·Android APK·실기기 동작은 이 환경에서 실행하지 못했습니다.

- 모든 스크립트가 자신의 위치를 기준으로 프로젝트 폴더로 이동합니다.
- flutter.bat 호출에 call을 사용하고 오류 시 다음 단계로 진행하지 않습니다.
- Android는 실제 기기 ID를 입력합니다. 예: scripts\run_android.bat emulator-5554
- 초기 설정은 --empty로 불필요한 기본 카운터 예제 생성을 줄입니다.
- Windows 터미널에서 실행해 오류 문구를 확인하세요. 더블클릭하면 종료 후 창이 닫힐 수 있습니다.

실행 순서: scripts\setup.bat, scripts\test.bat, scripts\run_web.bat 또는 scripts\run_android.bat.
기존 프로젝트에 예전 카운터 앱용 test/widget_test.dart가 있다면 내용을 확인하세요.
MyApp 또는 카운터 예제를 기대하는 기본 테스트는 현재 앱에 맞게 교체하거나 기본 예제 파일만 별도로 정리해야 합니다.
실제 프로젝트의 유효한 테스트를 제거하지 마세요.
