import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';
void main(){
  GoogleDeviceLogin login(Uri url)=>GoogleDeviceLogin(deviceCode:'ab'*32,verifier:'private-verifier-must-not-leave-app',userCode:'47',url:url,expiresAt:DateTime.now().add(const Duration(minutes:5)));
  final canonical=Uri.parse('https://script.google.com/macros/s/login/exec?device=${'ab'*32}');
  test('Samsung multi-account recovery selects a Google account before entering canonical Apps Script',(){
    final device=login(canonical),browser=device.browserUrl;
    expect(browser.scheme,'https');expect(browser.host,'accounts.google.com');expect(browser.path,'/AccountChooser');
    expect(browser.queryParameters['continue'],canonical.toString());expect(browser.queryParameters['service'],'wise');
    expect(browser.toString(),isNot(contains(device.verifier)));expect(browser.toString(),isNot(contains(device.userCode)));expect(device.url,canonical);
  });
  test('account selection cannot become an open redirect or add extra authentication parameters',(){
    for(final url in [Uri.parse('https://evil.example/exec?device=${'ab'*32}'),canonical.replace(path:'/macros/u/1/s/login/exec'),canonical.replace(query:'device=${'ab'*32}&authuser=1'),canonical.replace(query:'device=${'ab'*32}&device=wrong'),canonical.replace(query:'device=wrong')]){
      expect(()=>login(url).browserUrl,throwsA(isA<PlatformAuthFailure>()));
    }
  });
}
