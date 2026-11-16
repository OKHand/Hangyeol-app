$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$cmake = Join-Path $project 'windows/CMakeLists.txt'
$text = [IO.File]::ReadAllText($cmake)
if (-not $text.Contains('set(BINARY_NAME "hangyeol_platform")')) { throw 'Unexpected Windows runner name.' }
[IO.File]::WriteAllText($cmake, $text.Replace('set(BINARY_NAME "hangyeol_platform")', 'set(BINARY_NAME "hangyeol_online")'), [Text.UTF8Encoding]::new($false))
$main = Join-Path $project 'windows/runner/main.cpp'
$text = [IO.File]::ReadAllText($main)
if (-not $text.Contains('L"hangyeol_platform"')) { throw 'Expected generated Windows title.' }
# C++ Unicode escapes keep the native title correct on non-Korean build hosts.
[IO.File]::WriteAllText($main, $text.Replace('L"hangyeol_platform"', 'L"\uD55C\uACB0\uC528\uB4DC \uC628\uB77C\uC778"'), [Text.UTF8Encoding]::new($false))

$text = [IO.File]::ReadAllText($cmake)
if (-not $text.Contains('include(flutter/generated_plugins.cmake)')) { throw 'Expected generated Windows plugin include.' }
$text = $text.Replace('include(flutter/generated_plugins.cmake)', 'include("${CMAKE_CURRENT_SOURCE_DIR}/../tool/online_windows_plugins.cmake")')
[IO.File]::WriteAllText($cmake,$text,[Text.UTF8Encoding]::new($false))
Copy-Item (Join-Path $PSScriptRoot 'native/online_browser.h') (Join-Path $project 'windows/runner/online_browser.h')
Copy-Item (Join-Path $PSScriptRoot 'native/online_browser.cpp') (Join-Path $project 'windows/runner/online_browser.cpp')
$runner = Join-Path $project 'windows/runner/flutter_window.cpp'
$text = [IO.File]::ReadAllText($runner)
$text = '#include "online_browser.h"' + "`n" + $text
$marker = 'RegisterPlugins(flutter_controller_->engine());'
if (-not $text.Contains($marker)) { throw 'Expected Flutter engine registration.' }
$text = $text.Replace($marker,$marker + "`n  RegisterOnlineBrowser(flutter_controller_->engine()->messenger());")
[IO.File]::WriteAllText($runner,$text,[Text.UTF8Encoding]::new($false))
$runnerCmake = Join-Path $project 'windows/runner/CMakeLists.txt'
$extra = @'
target_sources("${BINARY_NAME}" PRIVATE "online_browser.cpp")
target_link_libraries("${BINARY_NAME}" PRIVATE shell32 ole32)
'@
$text = [IO.File]::ReadAllText($runnerCmake) + "`n" + $extra + "`n"
[IO.File]::WriteAllText($runnerCmake,$text,[Text.UTF8Encoding]::new($false))
Write-Host 'Windows online runner prepared without embedded WebView.'
