# Release readiness — 2026-11-16

Requested change: put agricultural prices immediately after crop photos in the
native bottom navigation. Implemented order: ERP / crop photos / prices / settings.
Prices load on first tab visit; switching tabs preserves the selected price view.
Authorization and the distinction between live prices and fictional examples remain.

Validation: Flutter 3.35.7 analyze passed; 15 navigation, prices, market setup,
settings cache and authentication tests passed.

The requested transition from development packages to a formal release is pending.
The public repository currently has no repository secrets or environments providing
the established Android signing identity. Its packaging workflow builds debug APKs.
Do not relabel those APKs as releases, generate a replacement key, or merely change
the command to `--release`: Flutter's generated release template uses debug signing
until explicitly configured otherwise.

The existing fixed identity must first be connected through a secure owner-controlled
signing process, outside tracked files and chat. Preserve its established fingerprint
and use the existing `configure_android_signing.py` hook only with verified protected
keystore/password-file paths. Check actual APK signer, package ID, increasing version
code, and data-preserving upgrade before releasing. Private server or signing-vault
credentials must not be fetched by public builds. No Private Actions are authorized.

The previous Windows artifact was already compiled in release mode and passed its
startup check; this does not certify the Android package or constitute release of
the new navigation change. No replacement binary has been built for this change yet.
After an authorized successful release build, deliver the verified artifacts to the
existing Drive update folders under the AGENTS.md delivery rule, without rebuilding
for upload. Server deployment and automatic update registration remain separate.
