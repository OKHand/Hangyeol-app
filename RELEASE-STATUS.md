# Release readiness — 2026-11-20 (Official Release Published)

The formal release transition has been updated and verified on 2026-11-20:

- **Android Official Release (`0.2.0 · build 67`, `run 44651974138`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-67.apk` (`56,279,778` bytes, SHA-256 `b9d58f9b5f46ee9e7557bffc1509a3988a71e6485f9f5022d4beb78fe713d2e2`).
  - Google Drive: https://drive.google.com/file/d/1nWM8O7Tmefe208xv-OMaA35XzPr7MdPE/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261120-b67`).

- **Windows Official Release (`0.2.0 · build 68`, `run 44651977448`)**:
  - File: `Hangyeol-windows-0.2.0-68.zip` (`13,885,416` bytes, SHA-256 `617193b6f91646f8ff0193dc65f1684cf0c2b47e217df5a26bc25397a40a4da1`).
  - Google Drive: https://drive.google.com/file/d/1OsJ_S_E92J0XphCqNni6ck__n3Fk978W/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v53, `login` v24)**:
  - Market prices: `summaryOnly` parallel settlement lookup + simultaneous daily/monthly chart start + 30-item sequential quote chunk streaming, 6h server cache TTL (`21600`s), and admin `market.warm` daily 08:00 KST pre-warm trigger.
  - Flutter client: per-account 08:00 KST persistent local cache (`marketDailyCycleKey`) + background quick-select crop prefetching.
  - Industry news: comprehensive issue consolidation, once-daily 07:00 KST scraper + 07:30 KST local cache, and max 10 items weekly Discord briefing.
