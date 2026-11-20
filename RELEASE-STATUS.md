# Release readiness — 2026-11-20 (Official Release Published)

The formal release transition has been updated and verified on 2026-11-20:

- **Android Official Release (`0.2.0 · build 75`, `run 44662154529`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-75.apk` (`56,280,426` bytes, SHA-256 `6d1a1fac78af629d65c561ae3b136d5b87f40419b20f32b57baaa1af059d27ba`).
  - Google Drive: https://drive.google.com/file/d/1a0mxHDJndwH3ij-jEgOKmJHdNl7cqbel/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261120-b75`).

- **Windows Official Release (`0.2.0 · build 76`, `run 44662158737`)**:
  - File: `Hangyeol-windows-0.2.0-76.zip` (`13,885,260` bytes, SHA-256 `799321cced020959a561e2d8cb8c97fd62744233a7e3217ab38cae8d517d36dc`).
  - Google Drive: https://drive.google.com/file/d/1pqox6C8S8-NQYwmq4zNvs_R50Lf89WkV/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v53, `login` v24)**:
  - Market prices: `summaryOnly` parallel settlement lookup + simultaneous daily/monthly chart start + 30-item sequential quote chunk streaming, 6h server cache TTL (`21600`s), and admin `market.warm` daily 08:00 KST pre-warm trigger.
  - Flutter client: KakaoTalk-inspired flat UI redesign (`HangyeolTheme` pure white canvas, pill tabs, flat hairline list rows, pure white bottom nav bar, and profile+flat menu Settings page preserving Hangyeol green `#1E6247`), ERP & Market UI boilerplate copy cleanup, per-account 08:00 KST persistent local cache (`marketDailyCycleKey`), background quick-select crop prefetching, and card-based `MarketSetupPage` UI without legacy initial-dev tomato mapping dummy.
  - Industry news: comprehensive issue consolidation, once-daily 07:00 KST scraper + 07:30 KST local cache, and max 10 items weekly Discord briefing.
