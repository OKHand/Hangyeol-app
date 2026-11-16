import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiFailure implements Exception {
  ApiFailure(this.message, {this.code = 'REQUEST_FAILED'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

class NativeApi {
  NativeApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();
  final Uri baseUrl;
  final http.Client _client;
  String? token;
  String? userId;
  Future<Map<String, dynamic>> request(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    final url = baseUrl.resolve(path);
    if (!AppConfig.sameOrigin(url, baseUrl)) { throw ApiFailure('허용되지 않은 서버 주소입니다.'); }
    final request = http.Request(method, url)..headers.addAll({'Content-Type': 'application/json', 'X-Client-Type': 'native'});
    if (token != null) { request.headers['Authorization'] = 'Bearer $token'; }
    if (body != null) { request.body = jsonEncode(body); }
    final response = await http.Response.fromStream(await _client.send(request).timeout(const Duration(seconds: 30)));
    if (response.statusCode >= 200 && response.statusCode < 300 && response.body.isEmpty) { return {}; }
    Map<String, dynamic> data;
    try { data = jsonDecode(response.body) as Map<String, dynamic>; }
    catch (_) { throw ApiFailure('서버 응답을 읽을 수 없습니다.'); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'] as Map<String, dynamic>?;
      throw ApiFailure(error?['message'] as String? ?? '요청을 완료하지 못했습니다.', code: error?['code'] as String? ?? 'REQUEST_FAILED');
    }
    return data;
  }
  Future<void> upload(String uploadUrl, List<int> bytes, String contentType) async {
    final url = baseUrl.resolve(uploadUrl);
    if (!AppConfig.sameOrigin(url, baseUrl)) { throw ApiFailure('업로드 서버 주소가 일치하지 않습니다.'); }
    final response = await _client.put(url, headers: {
      'Content-Type': contentType,
      if (token != null) 'Authorization': 'Bearer $token',
    }, body: bytes).timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) { throw ApiFailure('사진 전송이 완료되지 않았습니다. 다시 시도해 주세요.'); }
  }
  Future<String> developmentSession() async {
    final result = await request('/v1/auth/dev', method: 'POST', body: {'native': true});
    final value = result['token'];
    final user = result['user'] as Map<String, dynamic>?;
    if (value is! String || user?['id'] is! String) { throw ApiFailure('서버가 앱 세션을 발급하지 않았습니다.'); }
    token = value;
    userId = user!['id'] as String;
    final ticket = await request('/v1/web-sessions/tickets', method: 'POST', body: {});
    return ticket['ticket'] as String;
  }
  NativeApi snapshot() => NativeApi(baseUrl, client: _client)..token = token..userId = userId;
  void clearSession() { token = null; userId = null; }
  void close() => _client.close();
}
