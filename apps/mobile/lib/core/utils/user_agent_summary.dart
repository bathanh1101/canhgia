/// "Mozilla/5.0 (Windows NT 10.0...) Chrome/126" -> "Chrome trên Windows".
String summarizeUserAgent(String? ua) {
  if (ua == null || ua.trim().isEmpty) return 'Thiết bị không xác định';
  final browser = ua.contains('Edg/')
      ? 'Edge'
      : ua.contains('OPR/')
          ? 'Opera'
          : ua.contains('Firefox/')
              ? 'Firefox'
              : ua.contains('Chrome/') || ua.contains('CriOS/')
                  ? 'Chrome'
                  : ua.contains('Safari/')
                      ? 'Safari'
                      : null;
  final os = ua.contains('Windows')
      ? 'Windows'
      : ua.contains('Android')
          ? 'Android'
          : ua.contains('iPhone') || ua.contains('iPad')
              ? 'iOS'
              : ua.contains('Mac OS X')
                  ? 'macOS'
                  : ua.contains('Linux') || ua.contains('X11')
                      ? 'Linux'
                      : null;
  if (browser != null && os != null) return '$browser trên $os';
  return browser ?? os ?? 'Thiết bị không xác định';
}
