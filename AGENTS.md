# Client repository rules

- Preserve current application behavior. Server implementation remains Private.
- Never fetch a Private repository/config branch to install, analyze, test or build.
- Never copy authentication files, signing keys, real customer/ledger data or backups here.
- API URLs and public certificate fingerprints are not private signing material.
- Do not dispatch workflows or publish packages just to validate a source change.
- Analyze/test changed clients locally first; package only on explicit request.
- Never call a debug package an update for an existing installed app.
- Keep Flutter, Node and dependency locks pinned. Missing locks block CI readiness.
- No automatic retries of compiler failures. No Google or production writes in tests.

## Change history — user instruction, 2026-11-16

The user codes with several tools (Codex, VS Code Codex, Antigravity). Every tool must
leave a handoff so the others know what changed.

- Before starting, read the newest entries in `CHANGELOG.md`.
- After any change (code, config, docs, workflow, GitHub settings) or a decision by the
  user, add a new entry at the top of `CHANGELOG.md`: date · tool · title, then the
  request, what changed (files), checks actually run, user decisions, and remaining work.
- Record review-only or settings-only work too. Write it in Korean, keep it concise,
  and never claim a check or build that did not run.
- Commit the entry together with the change so it reaches GitHub. Docs-only pushes do
  not start Actions here.
- This repository is Public: never record secrets or server-vulnerability details here.
  Put those in the Private `OKHand/Hangyeol` docs and reference only the file name.

## Build delivery rule — user instruction, 2026-11-16

- After each explicitly requested successful Windows or Android build, upload the existing verified artifact to the user's Google Drive update folder, then verify the uploaded file and report its link. Do not rebuild or rerun Actions merely to deliver or re-upload an existing result.
- Destination: https://drive.google.com/drive/folders/1sX_b3n1b-6d43JoqIwxWhpk2JYE9jn2m . Keep the existing Android and Windows subfolders and sharing settings. Private tools/drive-update-config.json records their IDs.
- Name artifacts with platform, development/release status, source commit and run ID. Check for an existing matching artifact before uploading to avoid duplicates. Preserve older installers.
- Development/debug APKs must be clearly marked DEVELOPMENT-NOT-UPDATE; uploading them is storage only. Never register them as an installed-app update or replace the established signing key. Release registration still requires signer, package ID, increasing version and data-preserving upgrade verification.
- Use the connected Drive tool or an authenticated browser for delivery. Never put Google credentials in the Public repository, fetch private credentials from a Public build, start Private Actions, or write the server/update registry for this upload-only rule.
- If a connector rejects a large artifact, upload the same bytes through the browser; do not rebuild. If delivery remains blocked, preserve the local artifact and report the exact blocker.
- This is a chat-driven delivery rule, not an unattended Drive uploader installed in GitHub Actions. Do not claim unattended upload automation is configured.
