#include "online_browser.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shlobj.h>
#include <filesystem>
#include <memory>
#include <string>
#include <variant>

namespace {
bool OpenIsolatedBrowser(const std::string& value) {
  const std::string prefix="https://accounts.google.com/AccountChooser?";
  if(value.rfind(prefix,0)!=0 || value.size()>8192 || value.find_first_of("\"\r\n")!=std::string::npos) return false;
  const int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,value.data(),static_cast<int>(value.size()),nullptr,0);
  if(count<=0) return false;
  std::wstring url(static_cast<size_t>(count),L'\0');
  MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,value.data(),static_cast<int>(value.size()),url.data(),count);
  std::filesystem::path browser;
  for(const KNOWNFOLDERID* folder : {&FOLDERID_ProgramFilesX86,&FOLDERID_ProgramFiles}) {
    PWSTR root=nullptr;
    if(SUCCEEDED(SHGetKnownFolderPath(*folder,0,nullptr,&root))) {
      auto candidate=std::filesystem::path(root)/L"Microsoft"/L"Edge"/L"Application"/L"msedge.exe";
      CoTaskMemFree(root);
      std::error_code error;
      if(std::filesystem::is_regular_file(candidate,error)){browser=candidate;break;}
    }
  }
  if(browser.empty()) return false;
  wchar_t temp[MAX_PATH];
  const DWORD temp_length=GetTempPathW(MAX_PATH,temp);
  if(temp_length==0 || temp_length>=MAX_PATH) return false;
  GUID id; if(FAILED(CoCreateGuid(&id))) return false;
  wchar_t identifier[40]; if(StringFromGUID2(id,identifier,40)==0) return false;
  const auto profile=std::filesystem::path(temp)/(std::wstring(L"HangyeolAuth-")+identifier);
  std::error_code error;
  std::filesystem::create_directories(profile,error);if(error)return false;
  // A dedicated profile plus InPrivate prevents existing Google account slots
  // from being inherited. Existing browser profiles/cookies are never edited.
  std::wstring command=L"\""+browser.wstring()+L"\" --inprivate --new-window --no-first-run --no-default-browser-check --user-data-dir=\""+profile.wstring()+L"\" \""+url+L"\"";
  STARTUPINFOW startup{};startup.cb=static_cast<DWORD>(sizeof(startup));PROCESS_INFORMATION process{};
  const BOOL started=CreateProcessW(browser.c_str(),command.data(),nullptr,nullptr,FALSE,0,nullptr,nullptr,&startup,&process);
  if(!started) return false;
  CloseHandle(process.hThread);CloseHandle(process.hProcess);
  return true;
}
}
void RegisterOnlineBrowser(flutter::BinaryMessenger* messenger) {
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
  channel=std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(messenger,"hangyeol/isolated_auth_browser",&flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call,auto result){
    if(call.method_name()!="open"){result->NotImplemented();return;}
    const auto* url=call.arguments()?std::get_if<std::string>(call.arguments()):nullptr;
    if(!url){result->Error("INVALID_URL","Invalid login URL");return;}
    result->Success(flutter::EncodableValue(OpenIsolatedBrowser(*url)));
  });
}
