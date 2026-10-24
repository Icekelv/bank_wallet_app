/// Where the PHP backend lives. Set at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://your-site.com/monofin
/// The GitHub workflow passes the API_BASE_URL repository variable here.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://example.com/monofin',
);
