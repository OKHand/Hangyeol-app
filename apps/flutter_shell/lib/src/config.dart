class AppConfig {
  const AppConfig({required this.webUrl, required this.apiUrl, required this.development});
  factory AppConfig.environment() => AppConfig(
    webUrl: Uri.parse(const String.fromEnvironment('WEB_URL', defaultValue: 'http://localhost:5173')),
    apiUrl: Uri.parse(const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8787')),
    development: const bool.fromEnvironment('DEVELOPMENT'),
  );
  final Uri webUrl;
  final Uri apiUrl;
  final bool development;
  static bool sameOrigin(Uri a, Uri b) => a.scheme == b.scheme && a.host == b.host && a.port == b.port;
  bool trustedWeb(Uri candidate) => valid && sameOrigin(candidate, webUrl) && candidate.userInfo.isEmpty;
  bool get valid => _allowed(webUrl) && _allowed(apiUrl);
  bool _allowed(Uri uri) {
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasFragment) { return false; }
    if (uri.scheme == 'https') { return true; }
    return development && uri.scheme == 'http' && const {'localhost','127.0.0.1','10.0.2.2','::1'}.contains(uri.host);
  }
}
