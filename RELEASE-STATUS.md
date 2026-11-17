# Release readiness — 2026-11-17 (Official Release Published)

The formal release transition has been completed and verified on 2026-11-17:

- **Android Official Release (`0.2.0 · build 63`, `run 43999508143`)**:
  - Signed with the established fixed Android signing identity (`certificateSha256: 84fc6fb951f82620868f662a30477a589bf39fc5bc7100d387cb737a8e75e8fc`, package `com.hangyeolseed.platform_online`).
  - File: `Hangyeol-android-0.2.0-63.apk` (`56,066,786` bytes, SHA-256 `ef1b27f76ae761b88387a280c7d60af34d240bdc2262c4d505b10a9e42ad26c3`).
  - Google Drive: https://drive.google.com/file/d/1sxjxHb_V9kXpOPSsyjwBaoV5QWZAP2iX/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_android`) and recorded in `config/platform-android-signing` (`online-app-20261117-b63`).

- **Windows Official Release (`0.2.0 · build 64`, `run 43999512044`)**:
  - File: `Hangyeol-windows-0.2.0-64.zip` (`13,853,669` bytes, SHA-256 `4d13992a138aeb09b8131dff5f362cf70d7f99681eb9fef016c54bd7293ecd16`).
  - Google Drive: https://drive.google.com/file/d/12dUFMtaoOiQ2oq-iSSREvegonnDvm9cB/view
  - Registered in the live Apps Script in-app update registry (`updates.publish` → `APP_RELEASE_windows`).

- **Apps Script Server (`api` v51, `login` v22)**:
  - `Industry News` bottom tab (`news.list`, `news.feedback`) reading from isolated spreadsheet `1mLQvEAI2lPte8u2UZAzIc1HOCD9Yt5fUIGCUGHvrvB4`.
  - Admin Discord webhook settings (`news.settings`, `news.configure`, `news.sendWeekly`) & Monday 10:00 AM KST weekly batch briefing (`newsWeeklyBriefingWorker_`) active.
