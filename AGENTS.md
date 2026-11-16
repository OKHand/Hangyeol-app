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
