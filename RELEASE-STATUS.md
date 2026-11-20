# Release readiness — 2026-11-20 (Official Release Published)

The formal release transition has been updated and verified on 2026-11-20:

- **Android Official Release (`0.2.0 · build 81`, `run 44669621132`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-81.apk` (`56,509,802` bytes, SHA-256 `335e30edac3b2b43ec81ec294d6c5c710220ebed188dabd424f4b4283ba566fb`).
  - Google Drive: https://drive.google.com/file/d/1Wlnp8PW6crN7icl_ueLl8nlomTDot-SD/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261120-b81`).

- **Windows Official Release (`0.2.0 · build 82`, `run 44669630881`)**:
  - File: `Hangyeol-windows-0.2.0-82.zip` (`13,902,825` bytes, SHA-256 `bf2aa714db0c6bd2f84ef1ddc29c9c36f8aa7b83449f6375fe3a2f152eb78ce9`).
  - Google Drive: https://drive.google.com/file/d/190xbaE8Kgkg7AZC8ZxvjJbzyagK8vdfK/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v53, `login` v24)**:
  - Market prices: `summaryOnly` parallel settlement lookup + simultaneous daily/monthly chart start + 30-item sequential quote chunk streaming, 6h server cache TTL (`21600`s), and admin `market.warm` daily 08:00 KST pre-warm trigger.
  - Flutter client: KakaoTalk-inspired flat UI with high-contrast pill chips & catalogue buttons (`HangyeolTheme`), top ERP action bar (`추천어 갱신` · `초기화` · `조회 확인`), icon-only photo download to device (`PhotoDetailPage` + Android `MediaStore` / Windows `file_selector`), lightweight `120px` quantized PNG thumbnails (`<= 64KB`), per-account 08:00 KST persistent local cache (`marketDailyCycleKey`), background quick-select crop prefetching, and card-based `MarketSetupPage` UI without legacy initial-dev tomato mapping dummy.
  - Industry news: comprehensive issue consolidation, once-daily 07:00 KST scraper + 07:30 KST local cache, and max 10 items weekly Discord briefing.
