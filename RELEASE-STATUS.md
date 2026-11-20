# Release readiness — 2026-11-20 (Official Release Published)

The formal release transition has been updated and verified on 2026-11-20:

- **Android Official Release (`0.2.0 · build 69`, `run 44654220952`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-69.apk` (`56,263,830` bytes, SHA-256 `20873e1b0b6ca5e9efc5586f195e25654da5b81251acc21d2352121f39897015`).
  - Google Drive: https://drive.google.com/file/d/1Fkq890LURUb84n2dv05X-RslOefN-PE1/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261120-b69`).

- **Windows Official Release (`0.2.0 · build 70`, `run 44654224525`)**:
  - File: `Hangyeol-windows-0.2.0-70.zip` (`13,879,650` bytes, SHA-256 `2e9a26c28fd03470e58aaa9aa4a9bbb55ff24a6d6b9c18ecc131461c9cf17433`).
  - Google Drive: https://drive.google.com/file/d/1QCylm7e31D1L94prWv2DwmsMA8FCFY9M/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v53, `login` v24)**:
  - Market prices: `summaryOnly` parallel settlement lookup + simultaneous daily/monthly chart start + 30-item sequential quote chunk streaming, 6h server cache TTL (`21600`s), and admin `market.warm` daily 08:00 KST pre-warm trigger.
  - Flutter client: per-account 08:00 KST persistent local cache (`marketDailyCycleKey`), background quick-select crop prefetching, and card-based `MarketSetupPage` UI with legacy initial-dev tomato mapping dummy removed.
  - Industry news: comprehensive issue consolidation, once-daily 07:00 KST scraper + 07:30 KST local cache, and max 10 items weekly Discord briefing.
