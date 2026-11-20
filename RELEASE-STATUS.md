# Release readiness — 2026-11-20 (Official Release Published)

The formal release transition has been updated and verified on 2026-11-20:

- **Android Official Release (`0.2.0 · build 65`, `run 44647768004`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-65.apk` (`56,066,786` bytes, SHA-256 `4c4eb62e9b3fcf47e7b2aff2851f528a005dcf3fdc89d0905e16503ca04d3c18`).
  - Google Drive: https://drive.google.com/file/d/1Iq_Zuu1KzqcUXp0esA5ZAoSxb2bMjIsz/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261120-b65`).

- **Windows Official Release (`0.2.0 · build 66`, `run 44647773100`)**:
  - File: `Hangyeol-windows-0.2.0-66.zip` (`13,856,804` bytes, SHA-256 `39f8f449f2ed4534780952fe941903be5c72d8e9f58218296b549ec3a3ff8fbb`).
  - Google Drive: https://drive.google.com/file/d/1NYxzIHPZgez3-8GnASfeJ63LNiq9tMdc/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v52, `login` v23)**:
  - Comprehensive issue consolidation in both `NewsScraper.gs` and `news.gs`, once-daily 07:00 KST scraping trigger, 30-min `CacheService` TTL (`1800`s), and weekly Monday 10:00 AM KST Discord briefing capped at 10 important articles (`NW_MAX_DISCORD_ITEMS_ = 10`).
  - Flutter client caches feeds locally per account across the daily 07:30 KST refresh boundary so repeated opens do not refetch until the next day's update.
