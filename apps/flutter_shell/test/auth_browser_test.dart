import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/serverless/auth_browser.dart';
import 'package:hangyeol_platform/src/serverless/client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel=MethodChannel('hangyeol/isolated_auth_browser');
  final login=GoogleDeviceLogin(deviceCode:'ab'*32,verifier:'private-verifier',userCode:'012345',url:Uri.parse('https://script.google.com/macros/s/login/exec?device=${'ab'*32}'),expiresAt:DateTime.now().add(const Duration(minutes:5)));
  tearDown(() {
    debugDefaultTargetPlatformOverride=null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);
  });
  test('rejects external redirects, account slots, duplicates and private app data',() {
    final good=login.browserUrl;
    expect(trustedLoginBrowserUrl(good),isTrue);
    for(final uri in [
      good.replace(host:'accounts.google.com.evil.example'),
      good.replace(port:444),good.replace(userInfo:'user'),
      good.replace(query:'${good.query}&service=wise'),
      good.replace(queryParameters:{...good.queryParameters,'verifier':'secret'}),
      good.replace(queryParameters:{...good.queryParameters,'continue':'https://evil.example/exec'}),
      good.replace(queryParameters:{...good.queryParameters,'continue':login.url.replace(path:'/macros/u/1/s/login/exec').toString()}),
      good.replace(queryParameters:{...good.queryParameters,'continue':'${login.url}&device=bad'}),
    ]) { expect(trustedLoginBrowserUrl(uri),isFalse,reason:uri.toString()); }
  });
  for(final platform in [TargetPlatform.android,TargetPlatform.windows]) {
    test('$platform sends only the public URL to the isolated system browser',()async {
      debugDefaultTargetPlatformOverride=platform;
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call)async{received=call;return true;});
      expect(await openIsolatedLoginBrowser(login.browserUrl),isTrue);
      expect(received?.method,'open');expect(received?.arguments,login.browserUrl.toString());
      expect(received?.arguments,isNot(contains(login.verifier)));expect(received?.arguments,isNot(contains(login.userCode)));
    });
    test('$platform exposes private-mode recovery when browser isolation is unavailable',()async {
      debugDefaultTargetPlatformOverride=platform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(_)async=>false);
      await expectLater(openIsolatedLoginBrowser(login.browserUrl),throwsA(isA<PlatformAuthFailure>().having((e)=>e.code,'code','PRIVATE_BROWSER_REQUIRED')));
    });
    test('$platform handles a native launch failure without using the old cookie session',()async {
      debugDefaultTargetPlatformOverride=platform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(_)async=>throw PlatformException(code:'unavailable'));
      await expectLater(openIsolatedLoginBrowser(login.browserUrl),throwsA(isA<PlatformAuthFailure>().having((e)=>e.code,'code','PRIVATE_BROWSER_REQUIRED')));
    });
  }
}
