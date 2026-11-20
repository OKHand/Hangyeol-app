# Release readiness — 2026-11-20 (Official Release Published)

The formal release transition has been updated and verified on 2026-11-20:

- **Android Official Release (`0.2.0 · build 77`, `run 44665368817`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-77.apk` (`56,509,802` bytes, SHA-256 `fffa5ad5c50046398f065e89dd423b386f66fbfa96f3c72d1bc63d186bd85448`).
  - Google Drive: https://drive.google.com/file/d/1h5EAsZSZe48Es1T5c9F6NgtCdvJlIU5R/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261120-b77`).

- **Windows Official Release (`0.2.0 · build 78`, `run 44665372977`)**:
  - File: `Hangyeol-windows-0.2.0-78.zip` (`13,899,973` bytes, SHA-256 `2a0a3b6bcbe5915b233da2bc8ce9c3ce627e5652265cfc22acd2fc8ce936b159`).
  - Google Drive: https://drive.google.com/file/d/1Apb_ECDN6z1I7UgbPJtTXtfXV2i-dymK/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v53, `login` v24)**:
  - Market prices: `summaryOnly` parallel settlement lookup + simultaneous daily/monthly chart start + 30-item sequential quote chunk streaming, 6h server cache TTL (`21600`s), and admin `market.warm` daily 08:00 KST pre-warm trigger.
  - Flutter client: KakaoTalk-inspired flat UI with high-contrast pill chips & catalogue buttons (`HangyeolTheme`), top ERP action bar (`추천어 갱신` · `초기화` · `조회 확인`), icon-only photo download to device (`PhotoDetailPage` + Android `MediaStore` / Windows `file_selector`), lightweight `120px` quantized PNG thumbnails (`<= 64KB`), per-account 08:00 KST persistent local cache (`marketDailyCycleKey`), background quick-select crop prefetching, and card-based `MarketSetupPage` UI without legacy initial-dev tomato mapping dummy.
  - Industry news: comprehensive issue consolidation, once-daily 07:00 KST scraper + 07:30 KST local cache, and max 10 items weekly Discord briefing.
