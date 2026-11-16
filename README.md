# Hangyeol app client

한결씨드 Android·Windows 클라이언트와 React 웹 클라이언트입니다.
서버 코드·Google 인증 파일·실제 거래 자료·서명키는 포함하지 않습니다.

PC 최신 상태와 비교하여 분리한 클라이언트 소스입니다. Flutter 테스트 102개와 웹 검증이
통과했습니다. Windows 빌드는 PC 심볼릭 링크 권한 문제로 중단되었고 Android 빌드와
실제 로그인·설치 업데이트는 검증하지 않았습니다. Flutter analyze에는 기존 테스트의
불필요한 import 안내 1건이 남아 있습니다. 게시가 설치 앱이나 서버 업데이트를 뜻하지 않습니다.

| 위치 | 용도 |
| --- | --- |
| `apps/flutter_shell` | 현재 온라인 앱, 오프라인 체험, 기존 WebView 개발 모드 |
| `apps/web` | 기존 웹 클라이언트 |
| `packages/contracts` | 공개 HTTP·기기 브리지 타입 |
| `config/online.example.json` | 기존 공개 API 주소 입력 예시 |

## 로컬 검사

Node는 `.node-version`, Flutter는 `.flutter-version`을 따릅니다.
웹은 저장소 루트에서 `npm ci --ignore-scripts`, `npm run typecheck`,
`npm test`, `npm run build`를 실행합니다. Private 저장소나 서버 없이 컴파일됩니다.
웹의 실제 업무 기능은 기존 인증 서버를 런타임에 이용합니다.
웹 개발 서버의 `/v1` 프록시는 기존 `http://127.0.0.1:8787` 설정을 유지합니다.

Flutter는 `apps/flutter_shell`에서 `flutter pub get`, `flutter analyze`,
`flutter test --timeout 2m`를 실행합니다. `pubspec.lock`이 아직 없는 경우
고정 SDK로 의존성을 해결하고 잠금파일을 검토·커밋하기 전에는 CI를 활성화하지 않습니다.
Android SDK와 Windows의 Visual Studio 2022 C++ 도구는 해당 플랫폼 빌드에 필요합니다.

Android 준비: `bash tool/bootstrap.sh` → `python3 tool/prepare_serverless_android.py`.
Windows 준비: `./tool/bootstrap.ps1` → `./tool/prepare_serverless_windows.ps1`.
두 스크립트는 생성한 runner만 구성하고 기존 Dart 코드를 덮어쓰지 않습니다.

온라인은 예시 JSON을 저장소 밖 또는 무시되는 `config/online.json`으로 복사하고,
**기존** 회사 API 주소를 입력해 `--dart-define-from-file=<해당 파일>`로 빌드합니다.
API 주소·클라이언트 ID는 공개 식별자이며 인증 토큰과 서명키는 비밀값입니다.
기존 로그인 프로토콜과 API action 이름은 변경하지 않았습니다.
오프라인은 `prepare_offline_android.py`와 `--dart-define=OFFLINE_DEMO=true`를 사용합니다.
온라인/오프라인 Android 준비는 각각 깨끗한 생성 runner에서 실행합니다.

## 자동화와 배포

- 검사: `main` push 및 PR에서 변경된 클라이언트(Flutter / 웹)만 분석·테스트합니다. 수동 검사도 가능합니다.
- 문서만 변경하면 검사가 실행되지 않습니다. 저장소 분리 도구도 앱 검사 대상이 아닙니다.
- 패키징은 수동 `Client development packages`만 제공합니다. Android/Windows 중
  하나를 고르고, Google API 주소는 저장소 변수 `APPS_SCRIPT_API_URL`에서 읽습니다.
- 개발 APK는 임시 debug 서명이며 **기존 설치 앱 업데이트용이 아닙니다**.
  workflow는 Google 배포·Drive 업로드·업데이트 등록·GitHub 릴리스를 하지 않습니다.
- 정식 Android 출시는 기존 고정 서명키의 안전한 이전, 인증서/패키지 ID/증가한 버전
  확인과 이전 APK에 대한 데이터 보존 업데이트 검증을 마친 후 별도로 활성화합니다.
  키를 Public Git에 넣거나 새 키로 대체하지 않습니다.

## 공개 범위 점검

`source-manifest.json`은 원본과 공개 후보의 SHA-256을 기록합니다. 가상 샘플에 남은
인식 가능한 거래처·농가 명칭만 익명화했습니다. 전체 Private 이력은 복제하지 않습니다.
PC 수정본 비교, 비밀값 검사와 최종 파일 목록 검토를 수행했습니다. 이후 게시에도 같은 검토를 유지합니다.
라이선스는 소유자 결정 전까지 임의로 추가하지 않았습니다.
