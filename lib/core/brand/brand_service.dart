import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'brand_config.dart';

class BrandService {
  static const _cacheKey = 'platform_brand_v1';

  final Dio _dio;

  BrandService(String baseUrl)
      : _dio = Dio(
          BaseOptions(
            baseUrl: _brandBase(baseUrl),
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            headers: {AppConfig.accessKeyHeader: AppConfig.accessKey},
          ),
        );

  static String _brandBase(String url) {
    var root = url.trim();
    if (root.endsWith('/')) root = root.substring(0, root.length - 1);
    var sub = AppConfig.apiSubUrl;
    if (!sub.startsWith('/')) sub = '/$sub';
    if (sub.endsWith('/')) sub = sub.substring(0, sub.length - 1);
    return '$root$sub';
  }

  Future<BrandConfig> load({SharedPreferences? prefs}) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    BrandConfig cached = BrandConfig.defaults;
    final raw = storage.getString(_cacheKey);
    if (raw != null) {
      try {
        cached = BrandConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {}
    }

    try {
      final res = await _dio.get('/brand');
      final body = res.data;
      final data = body is Map ? (body['data'] ?? body) : null;
      if (data is Map) {
        final brand = BrandConfig.fromJson(Map<String, dynamic>.from(data));
        await storage.setString(_cacheKey, jsonEncode(brand.toJson()));
        return brand;
      }
    } catch (_) {}

    return cached;
  }
}
