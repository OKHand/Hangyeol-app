# 변경 이력 (Change log)

모든 개발 도구(Codex, VS Code Codex, Antigravity 등)가 공유하는 작업 기록입니다.
새 작업을 시작하기 전에 맨 위 항목부터 읽고, 작업을 마치면 맨 위에 항목을 추가합니다.
규칙은 [AGENTS.md](AGENTS.md)의 "Change history" 절을 따릅니다.

> 이 저장소는 Public입니다. 서버 보안 약점의 재현 방법·세부 내용은 여기에 쓰지 말고
> Private 저장소 `OKHand/Hangyeol`의 `docs/`에 기록한 뒤 문서 이름만 참조합니다.

---

## 2026-11-16 · Antigravity · 농산물 시세 점진적 로딩(선표시·후갱신) 및 전 품목 최근 2주(14일) 일별 시세 추이 그래프 적용

- 요청:
  1. 시세 조회 시 먼저 도착한 당일 첫 페이지 데이터를 즉시 보여주고, 추가 거래 내역과 2주치 그래프 데이터는 완료될 때마다 실시간으로 화면에 반영.
  2. 모든 품목에서 최근 2주(14일) 일별 시세 추이 그래프가 표시되도록 개선.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_prices.dart`:
    - 1페이지(100건) 수신 즉시 로딩바를 해제하고 요약 카드·거래 내역을 먼저 표시.
    - 백그라운드 `_loadProgressive`에서 최근 14일(`D-13`..`D-1`)을 3개 배치로 나누어 병렬 조회하고, 배치가 완료될 때마다 그래프 점·선을 실시간 추가(`2주 추이 불러오는 중… (n/3)` 진행 표시 포함) 및 추가 거래 페이지(`page 2, 3`) 점진적 병합.
- 확인: 로컬 `dart analyze` 무결점 및 시세 위젯 테스트 7건 모두 통과.

## 2026-11-16 · Antigravity · 농산물 경매 시세 요약 대시보드·일별 시세 추이 꺾은선 그래프·도매시장 선택 업그레이드

- 요청: 참고 화면(시세/정보 대시보드) 스타일의 `평균가격(원/kg)`·`거래량(kg)` 요약 카드, `등급별·규격별 평균가` 펼침 보기, `일별 시세 추이` 꺾은선 그래프, 공영도매시장 선택(`Grid_20240625000000000661_1`) 및 정산정보(`Grid_20240625000000000653_1`) 연동 반영.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_prices.dart`:
    - `평균가격`(`원/kg`) · `거래량`(`kg`) 2열 요약 카드(`market-avg-price-card`, `market-total-volume-card`) 추가.
    - `등급별·규격별 평균가` 아코디언(`market-grade-breakdown`) 추가.
    - `일별 시세 추이` 꺾은선 그래프(`market-trend-chart`, `_MarketTrendPainter` CustomPainter) 추가.
    - 공영도매시장 선택 칩(서울가락·서울강서·부산엄궁·대구북부·강릉 등) 및 도매시장 코드 API 동기화 연동.
  - `apps/flutter_shell/test/market_prices_test.dart`: 대시보드 요약 카드 및 일별 시세 추이 차트 위젯 테스트 추가.
- 확인: 로컬 `dart analyze` 무결점 및 시세 위젯 테스트 7건 모두 통과.
- 빌드 및 Google Drive 업로드 (`cdfd67a`):
  - Android (`run 43815471899`, 성공): `Hangyeol-android-online-DEVELOPMENT-NOT-UPDATE-20261116-run43815471899-cdfd67a.apk` (152,078,360 bytes, SHA-256 `5f83fe0971a9961d05edf09255d472435cdd68511e056c6c54b603d0ee858952`) → https://drive.google.com/file/d/1Jjy8Y2pDI38xD1poy70V6IVKo3uajqHY/view
  - Windows (`run 43815476153`, 성공): `Hangyeol-windows-online-development-20261116-run43815476153-cdfd67a.zip` (13,808,569 bytes, SHA-256 `b4061ccbe2690daa5c450e0ccb33b3e4e18d50bf971fff2bda030b18aab4b181`) → https://drive.google.com/file/d/16018O_1Zc_hkSFAargNt40OOMc9vfSEu/view

## 2026-11-16 · Antigravity · 농산물 경매 시세 다품목 빠른 선택 및 품목 코드 API 전체 품목 선택 기능

- 요청: 자주 보는 품목(찰토마토, 일반토마토, 대추방울, 파프리카, 가지, 고추, 양배추, 브로콜리) 빠른 선택 칩과, 품목 코드 API(`Grid_20240626000000000668_1`) 연동 기반 전체 부류·품목·품종 검색/선택 시세 조회 지원.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_prices.dart`:
    - 자주 보는 8개 품목 빠른 선택 ChoiceChip 제공.
    - `품목 코드로 전체 품목·품종 선택` 패널(`market-catalogue-panel`) 추가: 부류(`LARGE`) 필터, 품목·품종·코드 검색창(`market-item-search`), 품목 전체(`LARGE:MID`) 및 개별 품종(`LARGE:MID:SMALL`) 선택 조회, `품목 코드 API` 실시간 동기화 버튼(`market-sync-codes`) 제공.
  - `apps/flutter_shell/test/market_prices_test.dart`: 다품목 프리셋 및 품목 코드 카탈로그 검색·선택 위젯 테스트 추가.
- 확인: 로컬 `dart analyze` 무결점 및 시세 관련 위젯 테스트 7건 모두 통과.
- 빌드 및 Google Drive 업로드 (`6d7863a`):
  - Android (`run 43810821504`, 성공): `Hangyeol-android-online-DEVELOPMENT-NOT-UPDATE-20261116-run43810821504-6d7863a.apk` (152,070,652 bytes, SHA-256 `4972603f2473d8ed37c5fcf17e93e896c1c4b01e04fc3618bfd9c5e17eb8c9b0`) → https://drive.google.com/file/d/16za_AnW3rbvBxcR0PgGgY7_V_G3FQQJE/view
  - Windows (`run 43810824829`, 성공): `Hangyeol-windows-online-development-20261116-run43810824829-6d7863a.zip` (13,790,715 bytes, SHA-256 `acbd6e61b888ce830297d7748f9a127f2f52492ef7df90c4b66b6461656bc95d`) → https://drive.google.com/file/d/134OrO2vLWbsf5X3fSgq7DXwuAGeOAf3z/view

## 2026-11-16 · Antigravity · Android·Windows 개발 패키지 빌드 및 Google Drive 업로드

- 요청: `9d02119`(2자리 번호 고르기 로그인 및 하단 내비게이션 순서 반영본) 빌드 및 Drive 전달.
- 빌드(GitHub Actions `Client development packages`, `mode=online`):
  - Android (`run 43800072284`, 성공): `Hangyeol-android-online-DEVELOPMENT-NOT-UPDATE-20261116-run43800072284-9d02119.apk` (152,051,016 bytes, SHA-256 `d7bf460c5dd87e51cd8c4217bed90e0199eee212c4d6f353162cb22b053ab8cc`) — 개발용 debug 서명(기존 설치 앱 덮어쓰기 업데이트용 아님).
  - Windows (`run 43800075246`, 성공): `Hangyeol-windows-online-development-20261116-run43800075246-9d02119.zip` (13,776,778 bytes, SHA-256 `c3e1cc6e8575420182707622a3055a5c55f8057bc6a7031f6987ed7fcae85edc`).
- Drive 업로드 및 무결성(MD5·SHA-256) 검증 완료:
  - Android: https://drive.google.com/file/d/1ptuYG0wT6r0DMCB0bapZacfCqn8gQdYl/view
  - Windows: https://drive.google.com/file/d/1TDcjrNxgC3CQ42hhp23owrlMKUpg90TD/view
- 로컬 보관: `C:\Users\sango\Hangyeol-builds\20261116\`.

## 2026-11-16 · Antigravity · 기기 로그인 2자리 번호 고르기(Number Matching) 즉시 전환 (1번)

- 요청: 6자리 숫자 타이핑 없이 로그인 피싱을 막기 위해 2자리 번호 고르기 방식으로 즉시 전환.
- 변경:
  - `apps/flutter_shell/lib/src/serverless/client.dart`: `auth.start`의 `userCode`를 2자리 숫자(`^\d{2}$`)로 검증.
  - `apps/flutter_shell/lib/src/serverless/app.dart`: 로그인 대기 화면 중앙에 2자리 확인 번호 배지(`login-match-code`)를 크게 표시하고 브라우저의 3개 숫자 중 같은 번호를 누르도록 안내.
  - `apps/flutter_shell/test/serverless_auth_test.dart`, `auth_browser_test.dart`, `google_login_routing_test.dart`: 2자리 번호 기준 테스트 갱신.
- 확인: 로컬 `flutter analyze --no-pub` 및 인증 테스트 3개 파일 통과, `main` push 시 GitHub Actions `Client checks` 자동 실행.
- 주의: 서버(`OKHand/Hangyeol`의 `platform/apps-script-auth`)도 즉시 전환으로 함께 수정되었으며, 실제 Google Apps Script 반영과 앱 새 빌드 배포를 맞물려 진행해야 함.

## 2026-11-16 · Antigravity · `main` 브랜치 push 자동 검사 활성화 (3번-B)

- 요청: PR 없이 `main`에 직접 push할 때도 클라이언트 검사가 자동으로 돌도록 설정(옵션 B).
- 변경: `.github/workflows/client-checks.yml`, `README.md`, `CHANGELOG.md`.
- 확인: 로컬 `actionlint`로 워크플로 문법 검증. 문서 외 워크플로 파일 변경이 포함되어 push 시 GitHub Actions `Client checks` 실행됨(Public 저장소 무료 러너).
- 결정(사용자):
  - 3번은 B(`main` push 시 변경된 클라이언트만 자동 검사)로 확정.
  - 1번은 **번호 고르기(2자리 숫자 선택 탭)** 방식으로 진행 예정.

## 2026-11-16 · Antigravity · 전체 코드 리뷰 (코드 변경 없음)

- 요청: GitHub와 PC(`C:\Users\sango`)의 한결씨드 온라인 리뷰.
- 변경: 코드 없음. 이 `CHANGELOG.md`와 AGENTS.md의 기록 규칙만 추가.
- 확인: 소스 읽기 검토만 수행. 빌드·테스트·Actions 실행 없음.
- 결정(사용자):
  - 로그인 시 6자리 번호 입력은 계속 **사용하지 않음**. 대신 입력 없는 보완책을 검토한다.
  - Actions 사용량을 늘리지 않는 방식으로만 검사·브랜치 보호를 설정한다.
- 남은 일(클라이언트 관련):
  - 오프라인 상태로 앱 시작 시 로그인 화면으로만 떨어지는 문제 → "다시 연결" 제공.
  - `main` 직접 push 시 검사 미실행, 브랜치 보호 없음.
  - 정식 출시 전: 업데이트 허용 저장소(`OKHand/Hangyeol` 고정) 재결정, `APP_VERSION`/`APP_BUILD_NUMBER`
    주입, Windows ZIP 해시 확인.
  - 유지보수: `dart format`·린트 도입, `apps/web/src/App.tsx` 분리.
- 서버 측 상세 리뷰: Private `docs/code-review-online-2026-11-16.md`.

## 2026-11-16 이전

- `a0e1d7a` 하단 내비게이션 순서 변경: ERP / 작황 사진 / 농산물 시세 / 설정 ([RELEASE-STATUS.md](RELEASE-STATUS.md)).
- `097fe87` Private 저장소에서 클라이언트만 분리해 이 저장소 초기화.
