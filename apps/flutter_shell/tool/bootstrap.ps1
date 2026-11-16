param([switch]$Run, [string]$WebUrl = 'http://localhost:5173', [string]$ApiUrl = 'http://localhost:8787')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$generated = Join-Path ([IO.Path]::GetTempPath()) ('hangyeol-native-' + [guid]::NewGuid().ToString('N'))
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter SDK is required. Open this folder after Flutter is installed.' }
try {
  if (-not (Test-Path (Join-Path $project 'android')) -or -not (Test-Path (Join-Path $project 'windows'))) {
    & flutter create --no-pub --platforms=android,windows --org com.hangyeolseed --project-name hangyeol_platform $generated
    if ($LASTEXITCODE -ne 0) { throw 'Flutter platform generation failed.' }
    foreach ($platform in @('android','windows')) {
      $destination = Join-Path $project $platform
      if (-not (Test-Path $destination)) { Copy-Item (Join-Path $generated $platform) $destination -Recurse }
    }
    $metadata = Join-Path $project '.metadata'
    if (-not (Test-Path $metadata)) { Copy-Item (Join-Path $generated '.metadata') $metadata }
  }
  $manifest = Join-Path $project 'android/app/src/main/AndroidManifest.xml'
  $content = [IO.File]::ReadAllText($manifest)
  foreach ($permission in @('INTERNET','ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION')) {
    if (-not $content.Contains('android.permission.' + $permission)) { $content = $content.Replace('<application', '<uses-permission android:name="android.permission.' + $permission + '"/><application') }
  }
  [IO.File]::WriteAllText($manifest, $content, [Text.UTF8Encoding]::new($false))
  # Cleartext is permitted only by the generated debug manifest; release uses HTTPS.
  $debugManifest = Join-Path $project 'android/app/src/debug/AndroidManifest.xml'
  $debugXml = '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:usesCleartextTraffic="true"/></manifest>'
  [IO.File]::WriteAllText($debugManifest, $debugXml, [Text.UTF8Encoding]::new($false))
  $iconRoot = Join-Path $PSScriptRoot 'native/icons'
  if (Test-Path $iconRoot) {
    $resRoot = Join-Path $project 'android/app/src/main/res'
    if (Test-Path $resRoot) {
      foreach ($dir in @('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi','mipmap-anydpi-v26','drawable','values')) {
        $srcDir = Join-Path $iconRoot $dir
        if (Test-Path $srcDir) {
          $dstDir = Join-Path $resRoot $dir
          New-Item -ItemType Directory -Force $dstDir | Out-Null
          Copy-Item (Join-Path $srcDir '*') $dstDir -Force
        }
      }
    }
    $winRes = Join-Path $project 'windows/runner/resources'
    $icoFile = Join-Path $iconRoot 'app_icon.ico'
    if ((Test-Path $winRes) -and (Test-Path $icoFile)) {
      Copy-Item $icoFile (Join-Path $winRes 'app_icon.ico') -Force
    }
  }
  Push-Location $project
  try {
    & flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies failed.' }
    if ($Run) {
      & flutter run -d windows --dart-define=DEVELOPMENT=true "--dart-define=WEB_URL=$WebUrl" "--dart-define=API_URL=$ApiUrl"
      if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed.' }
    }
  } finally { Pop-Location }
} finally {
  if (Test-Path $generated) { Remove-Item $generated -Recurse -Force }
}
