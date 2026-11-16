param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$release = Join-Path $project 'build/windows/x64/runner/Release'
if (-not (Test-Path (Join-Path $release 'hangyeol_online.exe'))) { throw 'Online Windows executable was not built.' }
$bundle = Join-Path $OutputDirectory 'HangyeolOnline'
New-Item $bundle -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $release '*') $bundle -Recurse -Force
# Bundle Microsoft's redistributable CRT app-locally for ordinary Windows PCs.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vsRoot) { throw 'Visual C++ runtime location is unavailable.' }
$versions = Get-ChildItem (Join-Path $vsRoot 'VC/Redist/MSVC') -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+' } | Sort-Object { [version]$_.Name } -Descending
$crt = $null
foreach ($version in $versions) {
  $candidate = Join-Path $version.FullName 'x64/Microsoft.VC143.CRT'
  if (Test-Path $candidate) { $crt=$candidate; break }
}
if (-not $crt) { throw 'VS2022 x64 redistributable runtime was not found.' }
Copy-Item (Join-Path $crt '*.dll') $bundle -Force
foreach ($required in @('flutter_windows.dll','msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll','data')) {
  if (-not (Test-Path (Join-Path $bundle $required))) { throw "Missing portable runtime: $required" }
}
# Check the actual loader inputs: an unused WebView must not be linked or bundled.
$forbidden = Get-ChildItem $bundle -Recurse -File | Where-Object { $_.Name -match '^(webview_windows_plugin|WebView2Loader)\.dll$' }
if ($forbidden) { throw 'Unused embedded WebView is still present in the online package.' }
$toolVersions = Get-ChildItem (Join-Path $vsRoot 'VC/Tools/MSVC') -Directory | Sort-Object { [version]$_.Name } -Descending
$dumpbin = $null
foreach ($version in $toolVersions) {
  $candidate = Join-Path $version.FullName 'bin/Hostx64/x64/dumpbin.exe'
  if (Test-Path $candidate) { $dumpbin=$candidate; break }
}
if (-not $dumpbin) { throw 'Windows loader dependency inspector was not found.' }
$dependencies = (& $dumpbin /DEPENDENTS (Join-Path $bundle 'hangyeol_online.exe') | Out-String)
if ($LASTEXITCODE -ne 0 -or $dependencies -match '(?i)webview_windows|WebView2Loader') { throw 'Online executable still depends on embedded WebView.' }
$dependencies | Set-Content (Join-Path $OutputDirectory 'dependencies.log') -Encoding utf8
$nativeFiles = Get-ChildItem $bundle -File | Where-Object { $_.Extension -in @('.exe','.dll') }
foreach ($file in $nativeFiles) {
  $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($file.FullName))
  try {
    if ($reader.ReadUInt16() -ne 0x5a4d) { throw "Invalid native binary: $($file.Name)" }
    $reader.BaseStream.Position=0x3c
    $offset=$reader.ReadUInt32()
    $reader.BaseStream.Position=$offset
    if ($reader.ReadUInt32() -ne 0x00004550 -or $reader.ReadUInt16() -ne 0x8664) { throw "Non-x64 native binary: $($file.Name)" }
  } finally { $reader.Dispose() }
}
$readme = @'
한결씨드 온라인 · Windows 10/11 64비트

1. ZIP 파일을 마우스 오른쪽 버튼으로 눌러 '모두 압축 풀기'를 선택합니다.
2. HangyeolOnline 폴더 안의 hangyeol_online.exe를 실행합니다.
3. Google 로그인 → 별도 Edge InPrivate 창에서 회사 계정 로그인 → 앱의 6자리 코드 입력 → 앱 복귀로 진행합니다.

별도 개발 서버, Node.js, Flutter 설치 없이 인터넷으로 회사 Apps Script에 연결합니다.
기존에 등록된 직원 계정만 사용할 수 있습니다. PC 사진 파일을 선택하여 등록할 수 있습니다.
로그인용 브라우저에 '현재 파일을 열 수 없습니다'가 나오면 앱의 '로그인 화면이 열리지 않나요?'
안내에서 정식 주소를 복사하여 Chrome 또는 Edge의 새 InPrivate/시크릿 창에서 엽니다.

실행 파일만 다른 곳으로 옮기지 마세요. 옆의 DLL과 data 폴더가 함께 있어야 합니다.
이 ZIP은 기존 Windows 개발 서버 버전과 별개의 온라인 시험용 패키지입니다.
사진 정보·Google Drive·Discord 설정은 Android 온라인 앱과 같은 서버를 사용합니다.
회사 Google 로그인과 실제 사진·ERP 조회는 사용자 PC에서 최종 확인해야 합니다.
'@
[IO.File]::WriteAllText((Join-Path $bundle '먼저 읽어주세요.txt'), $readme, [Text.UTF8Encoding]::new($true))
# Verify that the packaged app, rather than only the build directory, starts.
$process = Start-Process -FilePath (Join-Path $bundle 'hangyeol_online.exe') -WorkingDirectory $bundle -PassThru
try {
  Start-Sleep -Seconds 10
  $process.Refresh()
  if ($process.HasExited) { throw "Packaged app stopped at startup (exit $($process.ExitCode))." }
  if ($process.MainWindowHandle -eq 0) { throw 'Packaged app has no main window.' }
  if ($process.MainWindowTitle -ne '한결씨드 온라인') { throw "Packaged app displayed an unexpected title: $($process.MainWindowTitle)" }
  $started = $true
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
}
$zip = Join-Path $OutputDirectory 'hangyeol-online-windows.zip'
Compress-Archive -Path $bundle -DestinationPath $zip -CompressionLevel Optimal -Force
$summary = @{ packaged=$true; startupPassed=$started; embeddedWebViewAbsent=$true; x64BinariesChecked=$nativeFiles.Count; executable='HangyeolOnline/hangyeol_online.exe'; sha256=(Get-FileHash $zip -Algorithm SHA256).Hash; bytes=(Get-Item $zip).Length }
$summary | ConvertTo-Json -Compress | Set-Content (Join-Path $OutputDirectory 'package-result.json') -Encoding utf8
Write-Host 'Portable Windows online ZIP packaged and startup checked.'
