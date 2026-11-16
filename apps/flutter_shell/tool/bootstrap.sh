#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
generated="$(mktemp -d /tmp/hangyeol-native-XXXXXX)"
trap 'rm -rf "$generated"' EXIT
if [[ ! -d "$project/android" || ! -d "$project/windows" ]]; then
  flutter create --no-pub --platforms=android,windows --org com.hangyeolseed --project-name hangyeol_platform "$generated"
  for target in android windows; do
    [[ -d "$project/$target" ]] || cp -R "$generated/$target" "$project/$target"
  done
  [[ -f "$project/.metadata" ]] || cp "$generated/.metadata" "$project/.metadata"
fi
python3 - "$project" <<'PY'
import pathlib,sys
root=pathlib.Path(sys.argv[1])
p=root/'android/app/src/main/AndroidManifest.xml'
s=p.read_text()
permissions=('INTERNET','ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION')
for permission in permissions:
    if 'android.permission.'+permission not in s:
        s=s.replace('<application',f'<uses-permission android:name="android.permission.{permission}"/><application',1)
p.write_text(s)
p=root/'android/app/src/debug/AndroidManifest.xml'
p.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:usesCleartextTraffic="true"/></manifest>')
PY
cd "$project"
flutter pub get --enforce-lockfile
