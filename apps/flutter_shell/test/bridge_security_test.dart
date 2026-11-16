import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangyeol_platform/src/bridge.dart';
import 'package:hangyeol_platform/src/config.dart';

void main(){
  final config=AppConfig(webUrl:Uri.parse('https://company.example/work'),apiUrl:Uri.parse('https://api.example'),development:false);
  test('only same-origin trusted HTTPS pages can receive native capabilities',(){
    expect(config.trustedWeb(Uri.parse('https://company.example/photos')),isTrue);
    for(final page in ['https://company.example.evil.test','https://company.example:444','http://company.example','https://other.example']){
      expect(config.trustedWeb(Uri.parse(page)),isFalse);
    }
    final insecure=AppConfig(webUrl:Uri.parse('http://localhost:5173'),apiUrl:Uri.parse('http://localhost:8787'),development:false);
    expect(insecure.valid,isFalse);
  });
  test('frame spoofing, navigation and old pending replies cannot reuse a capability',(){
    final gate=BridgeGate(config),page=Uri.parse('https://company.example/photos');
    final nonce=gate.activate(page);
    expect(gate.accepts({'nonce':nonce},page),isTrue);
    // Removing a ticket fragment or changing an internal route is same-document.
    expect(gate.accepts({'nonce':nonce},Uri.parse('https://company.example/photos?view=recent')),isTrue);
    expect(gate.accepts({'nonce':'untrusted-frame'},page),isFalse);
    expect(gate.accepts({'nonce':nonce},Uri.parse('https://evil.example')),isFalse);
    gate.invalidate();
    expect(gate.accepts({'nonce':nonce},page),isFalse);
    final second=gate.activate(page);
    expect(second,isNot(nonce));expect(gate.isActive(nonce),isFalse);
    expect(gate.accepts({'nonce':second},page),isTrue);
    final script=bridgeScript(second,windows:false);
    expect(script,contains('window!==window.top'));
    expect(script,contains(jsonEncode(second)));
  });
}
