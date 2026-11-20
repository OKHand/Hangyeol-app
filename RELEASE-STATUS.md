# Release readiness — 2026-11-20 (Official Release Published)

The formal release transition has been updated and verified on 2026-11-20:

- **Android Official Release (`0.2.0 · build 73`, `run 44658659495`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-73.apk` (`56,263,790` bytes, SHA-256 `e60592dd8f39e60379b6027a2fede28b4f335dbef711d66496c0a9d92137d271`).
  - Google Drive: https://drive.google.com/file/d/1UhI-Qqoq1JSj0HBKKqDkhJTOx8b4PMWR/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261120-b73`).

- **Windows Official Release (`0.2.0 · build 74`, `run 44658664176`)**:
  - File: `Hangyeol-windows-0.2.0-74.zip` (`13,880,087` bytes, SHA-256 `2a46893728450dc28cd59543ce1d9c7a50817f75e89a4140b9089dd5fa0abe60`).
  - Google Drive: https://drive.google.com/file/d/1CwIq-sDzhiqoe8GClGROOT_SOmFqnwb3/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v53, `login` v24)**:
  - Market prices: `summaryOnly` parallel settlement lookup + simultaneous daily/monthly chart start + 30-item sequential quote chunk streaming, 6h server cache TTL (`21600`s), and admin `market.warm` daily 08:00 KST pre-warm trigger.
  - Flutter client: ERP & Market UI boilerplate copy cleanup (`DemoErpPage`, `ErpReportView`, `MarketPricesPage`), Settings UI redesign with account summary & grouped menu cards (`_SettingsPage`), tighter layout spacing across tabs, per-account 08:00 KST persistent local cache (`marketDailyCycleKey`), background quick-select crop prefetching, and card-based `MarketSetupPage` UI without legacy initial-dev tomato mapping dummy.
  - Industry news: comprehensive issue consolidation, once-daily 07:00 KST scraper + 07:30 KST local cache, and max 10 items weekly Discord briefing.
