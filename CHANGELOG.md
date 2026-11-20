# 변경 이력 (Change log)

모든 개발 도구(Codex, VS Code Codex, Antigravity 등)가 공유하는 작업 기록입니다.
새 작업을 시작하기 전에 맨 위 항목부터 읽고, 작업을 마치면 맨 위에 항목을 추가합니다.
규칙은 [AGENTS.md](AGENTS.md)의 "Change history" 절을 따릅니다.

> 이 저장소는 Public입니다. 서버 보안 약점의 재현 방법·세부 내용은 여기에 쓰지 말고
> Private 저장소 `OKHand/Hangyeol`의 `docs/`에 기록한 뒤 문서 이름만 참조합니다.

---

## 2026-11-20 · Antigravity · 농산물 시세 설정 화면 카드형 UI 개편 및 초기 개발용 토마토 분류 더미 제거

- 요청: 기능 변경 없이 농산물 시세 설정 화면을 보기 좋게 정돈하고, 하단 초기 개발 과정의 찰토마토·대추방울토마토 분류 연결 더미 UI 제거.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_setup.dart`:
    - `기본 조회 조건` / `화면 및 차트 표시` / `상단 빠른 선택 품목` / `관리자 · 서버 사전 준비` 4개 흰색 라운드 카드로 섹션을 구조화하고, 넓은 화면에서는 시장·품목 선택 필드를 2열로 배치하며 하단 고정 저장 버튼(`시세 설정 저장 및 적용`)을 적용.
    - 초기 개발용 `찰토마토`·`대추방울토마토` 코드 탐색·연결 더미 위젯 및 `uuid` 의존 사용부 제거.
  - `apps/flutter_shell/test/market_setup_test.dart`: 섹션 렌더링·관리자 사전 준비 스위치·일반 사용자 뷰·더미 UI 미노출 검증 추가(`dart analyze` 무결점 · Flutter 전체 113건 통과).

## 2026-11-20 · Antigravity · 농산물 시세 하루 1회 캐싱 · 백그라운드 품목 사전 준비 · 평균시세/차트 병렬 우선 로딩

- 요청: 시세 화면을 열 때마다 다시 로딩하지 않고 하루 한 번 미리 읽어온 자료로 바로 볼 수 있도록 하며, 상단 평균시세와 일별/월별 추이 차트를 병렬로 먼저 표시한 뒤 개별 경락가 항목을 차례로 불러오도록 개선.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_prices.dart`, `app.dart`:
    - `marketDailyCycleKey` 및 계정별 영구 로컬 캐시 도입: 매일 오전 8시(KST) 이후 첫 조회 시세(과거 거래일은 영구 보관)를 디스크·메모리에 저장하고, 재오픈·품목 전환 시 추가 서버 호출 없이 `저장본 표시 (매일 08시 갱신)`으로 즉시 표시.
    - 초기 로딩 이후 표시 중인 다른 작물 시세를 백그라운드에서 순차적으로 미리 캐싱(`_startBackgroundPrefetch`)해 품목 탭 전환 시 대기 없이 바로 조회.
    - 상단 평균시세(`summaryOnly: true`)와 일별·월별 추이 차트를 동시에 시작해 상단 평균시세·차트를 먼저 표시한 뒤, 개별 경락가 항목을 30건(`chunkSize: 30`) 단위로 이어서 로딩.
  - `apps/flutter_shell/lib/src/market/market_setup.dart`: 관리자용 `매일 오전 8시 서버 시세 사전 준비`(`market.warm`) 스케줄 스위치 추가.
  - `apps/flutter_shell/test/market_prices_test.dart`, `market_setup_test.dart`: 일일 주기(08:00 KST), 병렬 단계 로딩·스트리밍·캐시 재사용·백그라운드 사전 로딩·사전 준비 스위치 테스트 추가(`dart analyze` 무결점 · Flutter 전체 112건 통과).
- 정식 버전 빌드·Drive 게시·앱 내 업데이트(`updates.publish`) 등록 완료 (`4d545a9`, `tag: online-app-20261120-b67`):
  - **Android 정식 버전 (`0.2.0 · 빌드 67`, `run 44651974138`)**: `Hangyeol-android-0.2.0-67.apk` (`56,279,778` bytes, SHA-256 `b9d58f9b5f46ee9e7557bffc1509a3988a71e6485f9f5022d4beb78fe713d2e2`) → https://drive.google.com/file/d/1nWM8O7Tmefe208xv-OMaA35XzPr7MdPE/view
  - **Windows 정식 버전 (`0.2.0 · 빌드 68`, `run 44651977448`)**: `Hangyeol-windows-0.2.0-68.zip` (`13,885,416` bytes, SHA-256 `617193b6f91646f8ff0193dc65f1684cf0c2b47e217df5a26bc25397a40a4da1`) → https://drive.google.com/file/d/1OsJ_S_E92J0XphCqNni6ck__n3Fk978W/view

## 2026-11-20 · Antigravity · 업계 뉴스 하루 1회 갱신 로컬 캐시 · 종합 기사 통합 · 주간 Discord 최대 10건 제한

- 요청: 중복 보도(`손실보상`/`손실보장` 등)는 종합 기사 위주로 합쳐서 보고, 앱을 열 때마다 매번 서버에서 다시 불러오지 않고 하루 한 번 갱신된 캐시를 재사용하며, 주간 Discord 브리핑은 중요 기사 최대 10건만 수신.
- 변경:
  - `apps/flutter_shell/lib/src/serverless/industry_news.dart`, `app.dart`:
    - `newsDailyCycleKey` 및 계정별 영구 로컬 캐시(`getApplicationDocumentsDirectory`) 도입: 매일 오전 7시 30분(KST) 이후 첫 조회분만 서버에서 가져와 디스크에 저장하고, 같은 날 재오픈 시 추가 서버 호출 없이 `저장본 표시`로 즉시 표시.
    - `관련 없음` 피드백 시 로컬 디스크 캐시에서도 즉시 제외하여 재실행 시 복원되지 않도록 개선, 수동 새로고침 버튼(`refresh: true`) 시 강제 재조회 및 갱신.
  - `apps/flutter_shell/lib/src/serverless/news_discord_settings.dart`: 주간 월요일 10시 자동 발송 안내 문구에 `최대 10건` 기준 반영.
  - `apps/flutter_shell/test/industry_news_test.dart`: 일일 주기 경계(07:30 KST), 동일 주기 무호출 재오픈, 제외 영구 유지, 수동 새로고침 및 다음 날 자동 재조회 테스트 추가(`dart analyze` 무결점 · Flutter 전체 109건 통과).
- 정식 버전 빌드·Drive 게시·앱 내 업데이트(`updates.publish`) 등록 완료 (`d58e4ee`, `tag: online-app-20261120-b65`):
  - **Android 정식 버전 (`0.2.0 · 빌드 65`, `run 44647768004`)**: `Hangyeol-android-0.2.0-65.apk` (`56,066,786` bytes, SHA-256 `4c4eb62e9b3fcf47e7b2aff2851f528a005dcf3fdc89d0905e16503ca04d3c18`) → https://drive.google.com/file/d/1Iq_Zuu1KzqcUXp0esA5ZAoSxb2bMjIsz/view
  - **Windows 정식 버전 (`0.2.0 · 빌드 66`, `run 44647773100`)**: `Hangyeol-windows-0.2.0-66.zip` (`13,856,804` bytes, SHA-256 `39f8f449f2ed4534780952fe941903be5c72d8e9f58218296b549ec3a3ff8fbb`) → https://drive.google.com/file/d/1NYxzIHPZgez3-8GnASfeJ63LNiq9tMdc/view

## 2026-11-17 · Antigravity · 하단 `업계 뉴스` 탭 추가 및 `설정` 내 주간(월요일 10시) Discord 웹훅 설정 구현

- 요청: 하단 내비게이션에 `업계 뉴스` 탭을 추가하고, 관리자가 `설정` 탭에서 Discord 웹훅을 입력해 매주 월요일 오전 10시(KST) 주간 뉴스를 일괄 발송할 수 있게 구성(AI 요약은 추후 활성화).
- 변경:
  - `apps/flutter_shell/lib/src/serverless/app.dart`: 하단 5탭(`ERP`, `작황 사진`, `농산물 시세`, `업계 뉴스`, `설정`) 구성 및 관리자 설정 메뉴 `업계 뉴스 Discord 알림` 추가.
  - `apps/flutter_shell/lib/src/serverless/industry_news.dart`: `IndustryNewsPage` 구현(5개 트랙 필터, 검색, 작물 태그, 유사보도 펼치기, 외부 원문 열기, `관련 없음` 피드백 제외).
  - `apps/flutter_shell/lib/src/serverless/news_discord_settings.dart`: `NewsDiscordSettingsPage` 구현(웹훅 입력·해제, 매주 월요일 오전 10시 자동 발송 스위치, 즉시 시험 발송, 관리대장 시트 열기).
  - `apps/flutter_shell/test/industry_news_test.dart`, `market_navigation_test.dart`, `company_connections_test.dart`: 위젯 테스트 추가·갱신(전체 107건 통과).
- 정식 버전 빌드·Drive 게시·앱 내 업데이트(`updates.publish`) 등록 완료 (`bdf5d40`):
  - **Android 정식 버전 (`0.2.0 · 빌드 63`, `run 43999508143`)**: `Hangyeol-android-0.2.0-63.apk` (`56,066,786` bytes, SHA-256 `ef1b27f76ae761b88387a280c7d60af34d240bdc2262c4d505b10a9e42ad26c3`) → https://drive.google.com/file/d/1sxjxHb_V9kXpOPSsyjwBaoV5QWZAP2iX/view
  - **Windows 정식 버전 (`0.2.0 · 빌드 64`, `run 43999512044`)**: `Hangyeol-windows-0.2.0-64.zip` (`13,853,669` bytes, SHA-256 `4d13992a138aeb09b8131dff5f362cf70d7f99681eb9fef016c54bd7293ecd16`) → https://drive.google.com/file/d/12dUFMtaoOiQ2oq-iSSREvegonnDvm9cB/view

## 2026-11-16 · Antigravity · KAMIS 3번 API (`monthlySalesList`) 기반 월별 시세 추이 그래프 추가 (`1kg` 환산)

- 요청: 일별 시세 추이 그래프 바로 아래에 KAMIS 월별 시세 추이 그래프를 함께 표시.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_prices.dart`:
    - `_loadProgressive`에서 일별 추이 배치 및 추가 거래 내역과 병렬로 `monthlyTrend: true` 백그라운드 조회.
    - `_monthlyTrendSection`(`market-monthly-trend-chart`) 추가: 일별 그래프 아래에 최근 12개월 월평균 도매 시세 꺾은선 그래프와 지역·품목·실제 단위(`원/kg`, 백다다기는 `원/50개`)·최저/최고 범위 표시.
    - `_MarketTrendPainter`에 선·격자 색상 파라미터를 추가해 일별(파랑) / 월별(그린) 차트가 페인터를 공유.
  - `apps/flutter_shell/lib/src/market/market_setup.dart`:
    - `MarketPreferences.showMonthlyTrend` 및 설정 화면 스위치(`market-pref-monthly-trend`) 추가.
- 확인: 로컬 `dart analyze` 무결점 및 Flutter 전체 테스트 105건 모두 통과.
- 정식 버전 빌드·Drive 게시·앱 내 업데이트(`updates.publish`) 등록 완료 (`fbeec73`):
  - **Android 정식 버전 (`0.2.0 · 빌드 61`, `run 43836225291`)**: `Hangyeol-android-0.2.0-61.apk` (`55,968,042` bytes, SHA-256 `7e5f9b8411b387e90739536b557d5bccbb0157047c1dc1b6298cc505aa1b4b4d`) → https://drive.google.com/file/d/1QL44TDGkzCyijdt2qNDCwHeXyWHVjEF7/view
  - **Windows 정식 버전 (`0.2.0 · 빌드 62`, `run 43836230203`)**: `Hangyeol-windows-0.2.0-62.zip` (`13,837,158` bytes, SHA-256 `f866903dfa3be06413880e9af38de764fb6925f0289f08a5251e5c6f5f4a6f8a`) → https://drive.google.com/file/d/1MQaw1-bswz5F_CscwN1y0rJHGCNnEWK3/view

## 2026-11-16 · Antigravity · 농산물 시세 설정 개편·실제 시세 단일화·11개 품목 순서 개편 및 잎 모양 앱·프로그램 아이콘 적용

- 요청:
  1. 농산물 시세 설정 화면을 실용적인 시세 설정(기본 도매시장, 첫 시작 품목, 추이 그래프 기간 7/14/21일, 대표 단가 기준 `원/kg` vs 상자 단가, 등급별 평균가 자동 펼치기, 상단 빠른 선택 품목 표시 관리 + 관리자 서버 API 코드 연결)으로 개편.
  2. 실제 시세만 조회하므로 `실제 시세` / `예시 자료 보기` 전환 버튼 및 가상 가격 배너 제거.
  3. 품목 탭 순서를 `일반토마토, 찰토마토, 대추방울, 파프리카, 가지, 홍고추, 풋고추, 백다다기, 양파, 양배추, 브로콜리` 11개로 개편.
  4. 어플(Android) 및 프로그램(Windows) 아이콘을 잎 모양 아이콘으로 변경.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_setup.dart`, `market_prices.dart`:
    - `MarketPreferences` 및 새 설정 화면(`MarketSetupPage`) 구현, 모든 사용자에게 시세 설정 버튼(`market-open-setup`) 제공.
    - 온라인 시세 화면에서 `실제 시세` / `예시 자료 보기` 토글 제거.
    - `marketOrderedProducts` 11개 품목 순서(`일반토마토` → `브로콜리`) 적용.
  - `apps/flutter_shell/tool/native/icons/**`, `tool/bootstrap.sh`, `tool/bootstrap.ps1`, `lib/src/serverless/app.dart`, `apps/web/index.html`:
    - 한결씨드 그린(`#1E6247`) 바탕의 잎 모양 런처 아이콘(`ic_launcher.png` mdpi~xxxhdpi, Android 8+ 어댑티브 벡터 아이콘 `ic_launcher.xml`, Windows 다중 해상도 `app_icon.ico`, 웹 SVG 파비콘, 앱 상단 바 리프 아이콘) 생성 및 빌드 부트스트랩 자동 복사 구성.
- 확인: 로컬 `dart analyze` 무결점 및 Flutter 전체 테스트 104건 모두 통과.
- 정식 버전 빌드·Drive 게시·앱 내 업데이트(`updates.publish`) 등록 완료 (`195e565`):
  - **Android 정식 버전 (`0.2.0 · 빌드 59`, `run 43829063685`)**: `Hangyeol-android-0.2.0-59.apk` (`55,951,658` bytes, SHA-256 `b02ffd623b53d79f06e047acfa4a5b5f1e6eb3564eb87b2d4e84b0e4493e7ab5`) → https://drive.google.com/file/d/1Ngijr_rmHGhcuL16cFZVl5fG21lTqXJB/view
  - **Windows 정식 버전 (`0.2.0 · 빌드 60`, `run 43829069527`)**: `Hangyeol-windows-0.2.0-60.zip` (`13,833,081` bytes, SHA-256 `c68e86751101252bf227057b8f6e20e93a37b66917288fc5626afbf54882f811`) → https://drive.google.com/file/d/1jO9-vhcU-qeiWx0PJYIhDA5ykuVkG75u/view

## 2026-11-16 · Antigravity · 정식 버전(0.2.0) 전환 완료 — 고정 Android 서명 Release 빌드 · Google Drive 게시 · 앱 내 업데이트 등록

- 요청: 테스트(개발) 버전을 정식 버전으로 전환 및 정산 가격 정보 API(`653_1`)의 등급별 가격 반영 확인.
- 변경:
  - `.github/workflows/client-packages.yml`, `RELEASE-STATUS.md`:
    - 비공개 Google Drive 보관소의 고정 Android 서명키(인증서 지문 `84fc6fb9...`)를 복원·검증하여 Release 서명 적용 및 `apksigner`·`aapt` 검증 단계 활성화.
    - `APP_VERSION=0.2.0` 및 증가하는 빌드 번호(`APP_BUILD_NUMBER`)를 Android·Windows 정식 빌드에 주입.
- 정식 버전 빌드·Drive 게시·앱 내 업데이트(`updates.publish`) 등록 완료:
  - **Android 정식 버전 (`0.2.0 · 빌드 56`, `run 43822471247`)**: `Hangyeol-android-0.2.0-56.apk` (`55,911,590` bytes, SHA-256 `8cd85ce21a3cc5360673abeda697d5c8b0b9f898920c3900410ba7d9eb28cf80`) → https://drive.google.com/file/d/1fMxFg8PrdSMHRletonQG0DZ1_QGoYyud/view
  - **Windows 정식 버전 (`0.2.0 · 빌드 58`, `run 43823680741`)**: `Hangyeol-windows-0.2.0-58.zip` (`13,815,981` bytes, SHA-256 `12af6b89d021ca0a9ba1e857ca004916e5e417e7da543c51215ff4173db5e92e`) → https://drive.google.com/file/d/10bDNmmfVk7O5sVIyFGAnTCo2is2PFqeB/view

## 2026-11-16 · Antigravity · 농산물 시세 점진적 로딩(선표시·후갱신) 및 전 품목 최근 2주(14일) 일별 시세 추이 그래프 적용

- 요청:
  1. 시세 조회 시 먼저 도착한 당일 첫 페이지 데이터를 즉시 보여주고, 추가 거래 내역과 2주치 그래프 데이터는 완료될 때마다 실시간으로 화면에 반영.
  2. 모든 품목에서 최근 2주(14일) 일별 시세 추이 그래프가 표시되도록 개선.
- 변경:
  - `apps/flutter_shell/lib/src/market/market_prices.dart`:
    - 1페이지(100건) 수신 즉시 로딩바를 해제하고 요약 카드·거래 내역을 먼저 표시.
    - 백그라운드 `_loadProgressive`에서 최근 14일(`D-13`..`D-1`)을 3개 배치로 나누어 병렬 조회하고, 배치가 완료될 때마다 그래프 점·선을 실시간 추가(`2주 추이 불러오는 중… (n/3)` 진행 표시 포함) 및 추가 거래 페이지(`page 2, 3`) 점진적 병합.
- 확인: 로컬 `dart analyze` 무결점 및 시세 위젯 테스트 7건 모두 통과.
- 빌드 및 Google Drive 업로드 (`6155850`):
  - Android (`run 43819310788`, 성공): `Hangyeol-android-online-DEVELOPMENT-NOT-UPDATE-20261116-run43819310788-6155850.apk` (152,094,768 bytes, SHA-256 `d84d8efaf54e21a9ea9bf0edb00117a2c931710d33a2125443dfabebb1e444a2`) → https://drive.google.com/file/d/1yu4ZvUyL8Y0omTMJLpXD-kk5rUF6x608/view
  - Windows (`run 43819314283`, 성공): `Hangyeol-windows-online-development-20261116-run43819314283-6155850.zip` (13,815,952 bytes, SHA-256 `898726338fb994243b845fab77a34c971f212702ff159d5f5cdcbdb236d2814d`) → https://drive.google.com/file/d/1CD9-CphZUFhQOlguFLERMGDIr9fxq6MC/view

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
