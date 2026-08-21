class AppConfig {
  static const accessKey = '903361';
  static const accessKeyHeader = 'x-access-key';
  static const countryDialCode = '967';
  static const platform = 'android';
  static const defaultApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://admin.marabmall.cloud',
  );

  static bool isUnreachableOnDevice(String url) {
    final value = url.toLowerCase();
    return value.contains('10.0.2.2') ||
        value.contains('127.0.0.1') ||
        value.contains('localhost');
  }

  static const apiSubUrl = String.fromEnvironment(
    'API_SUBURL',
    defaultValue: '/customer',
  );
  static const defaultColor = 0xFF33A36B;
  static const productPageSize = 12;
}
