# Flutter regenerates plugin files before CMake. Filter at configure time so an
# unused embedded browser cannot become a loader dependency of the online app.
set(registrant "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.cc")
file(READ "${registrant}" registrant_source)
string(REGEX REPLACE "#include <webview_windows/[^>]+>[\r\n]+" "" registrant_source "${registrant_source}")
string(REGEX REPLACE "[ \t]*WebviewWindowsPluginRegisterWithRegistrar\\([^;]+;" "" registrant_source "${registrant_source}")
file(WRITE "${registrant}" "${registrant_source}")
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake" plugins_source)
string(REGEX REPLACE "[\r\n][ \t]*webview_windows[ \t]*[\r\n]" "\n" plugins_source "${plugins_source}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/online_generated_plugins.cmake" "${plugins_source}")
include("${CMAKE_CURRENT_BINARY_DIR}/online_generated_plugins.cmake")
