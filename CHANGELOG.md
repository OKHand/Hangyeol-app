# 변경 이력 (Change log)

모든 개발 도구(Codex, VS Code Codex, Antigravity 등)가 공유하는 작업 기록입니다.
새 작업을 시작하기 전에 맨 위 항목부터 읽고, 작업을 마치면 맨 위에 항목을 추가합니다.
규칙은 [AGENTS.md](AGENTS.md)의 "Change history" 절을 따릅니다.

> 이 저장소는 Public입니다. 서버 보안 약점의 재현 방법·세부 내용은 여기에 쓰지 말고
> Private 저장소 `OKHand/Hangyeol`의 `docs/`에 기록한 뒤 문서 이름만 참조합니다.

---

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
