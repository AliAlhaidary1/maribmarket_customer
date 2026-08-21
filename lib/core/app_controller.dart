import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'city_mode.dart';
import 'app_theme.dart';
import 'config.dart';
import 'i18n.dart';
import 'json_util.dart';
import 'api/customer_api.dart';

class AppController extends ChangeNotifier {
  AppController();

  late SharedPreferences _prefs;
  late CustomerApi api;
  final i18n = I18n();

  String apiUrl = AppConfig.defaultApiUrl;
  String? token;
  String? viewerKey;
  Map<String, dynamic>? user;
  Map<String, dynamic> settings = {
    'web_settings': <String, dynamic>{},
    'firebase': <String, dynamic>{},
  };
  Map<String, dynamic> paymentSettings = {};
  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> rootCategories = [];
  bool citiesLoaded = false;
  Map<String, dynamic>? city;
  Map<String, dynamic>? shop;
  List<Map<String, dynamic>> addresses = [];
  Map<String, dynamic>? selectedAddress;
  Map<String, dynamic>? cart;
  List<Map<String, dynamic>> cartProducts = [];
  double cartSubTotal = 0;
  List<Map<String, dynamic>> guestCart = [];
  double guestCartTotal = 0;
  Map<String, dynamic>? promoCode;
  List<dynamic> favoriteIds = [];
  bool bootstrapped = false;
  String? bootstrapError;
  bool busy = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  bool get isGuest => !isLoggedIn;
  bool get maintenance => J.str(webSettings['website_mode']) == '1';
  bool get akhdimniEnabled => J.flag(settings['akhdimni_enabled']);
  Map<String, dynamic> get webSettings => J.map(settings['web_settings']);
  /// Deep Navy Blue — headers, navigation, primary structures.
  Color get brandColor => AppTheme.primaryNavy;

  /// Dynamic Orange — CTAs, badges, active states.
  Color get accentColor => AppTheme.accentOrange;

  String get currency => J.str(settings['currency'], 'ر.ي');
  int get decimals => J.i(settings['decimal_point'], 2);
  String get placeholder => J.str(webSettings['placeholder_image']);
  int get cartCount => isLoggedIn ? cartProducts.length : guestCart.length;

  ({double latitude, double longitude})? get coords => shopCoordinates(city);
  ({double latitude, double longitude}) get browseCoords =>
      coords ?? (latitude: 0.0, longitude: 0.0);

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    apiUrl = AppConfig.defaultApiUrl;
    await _prefs.setString('api_url', apiUrl);
    token = _prefs.getString('token');
    viewerKey = _prefs.getString('viewer_key');
    if (viewerKey == null || viewerKey!.length < 8) {
      viewerKey = _newViewerKey();
      await _prefs.setString('viewer_key', viewerKey!);
    }
    final lang = _prefs.getString('language') ?? 'ar';
    await i18n.load(lang);
    i18n.addListener(notifyListeners);

    final guestRaw = _prefs.getString('guest_cart');
    if (guestRaw != null) {
      guestCart = J.maps(jsonDecode(guestRaw));
    }
    final cityRaw = _prefs.getString('city');
    if (cityRaw != null) {
      city = J.map(jsonDecode(cityRaw));
    }

    api = CustomerApi(baseUrl: apiUrl, token: token, viewerKey: viewerKey);
    try {
      if (token != null) {
        final me = await api.userDetails();
        if (me.ok) {
          user = me.user.isNotEmpty ? me.user : me.dataMap;
        } else {
          await _clearSession();
        }
      }
      await reloadSettings();
      await loadCities();
      await resolveCity();
      await loadShop();
      await loadRootCategories();
      if (isLoggedIn) {
        await loadAddresses();
        await refreshCart();
      }
      bootstrapped = true;
    } catch (error) {
      bootstrapError = '$error';
      bootstrapped = true;
    }
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    final value = url.trim();
    apiUrl = value.isEmpty ? AppConfig.defaultApiUrl : value;
    await _prefs.setString('api_url', apiUrl);
    api.setBaseUrl(apiUrl);
    notifyListeners();
    await reloadSettings();
    await loadCities();
    await resolveCity();
    await loadShop();
    await loadRootCategories();
  }

  Future<void> setLanguage(String code) async {
    await i18n.load(code);
    await _prefs.setString('language', i18n.code);
    notifyListeners();
  }

  String t(String key) => i18n.t(key);

  Future<void> reloadSettings() async {
    final result = await api.settings(withAuth: isLoggedIn);
    if (result.ok) {
      var data = result.dataMap;
      if (data['web_settings'] is List)
        data['web_settings'] = <String, dynamic>{};
      if (data['firebase'] is List) data['firebase'] = <String, dynamic>{};
      settings = data;
      favoriteIds = J.list(data['favorite_product_ids']);
    }
    try {
      final pay = await api.paymentMethods();
      if (pay.ok) {
        var decoded = pay.data;
        if (decoded is String) {
          try {
            decoded = jsonDecode(utf8.decode(base64Decode(decoded)));
          } catch (_) {}
        }
        paymentSettings = J.map(decoded);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadCities() async {
    final result = await api.cities();
    cities = result.ok ? result.dataMaps : [];
    citiesLoaded = true;
    notifyListeners();
  }

  Future<void> resolveCity() async {
    if (!citiesLoaded) return;
    if (isSingleCityMode(cities)) {
      await selectCity(normalizeCity(getSoleCity(cities)));
      return;
    }
    if (isLoggedIn) {
      await loadAddresses();
      final defaultAddress = addresses.cast<Map<String, dynamic>?>().firstWhere(
        (item) => J.i(item?['is_default']) == 1,
        orElse: () => addresses.isNotEmpty ? addresses.first : null,
      );
      selectedAddress = defaultAddress;
      final fromAddress = cityFromAddress(defaultAddress, cities);
      if (fromAddress != null) {
        await selectCity(fromAddress);
        return;
      }
    }
    if (city == null && settings['default_city'] != null) {
      await selectCity(normalizeCity(settings['default_city']));
      return;
    }
    if (city == null && cities.isNotEmpty) {
      await selectCity(normalizeCity(cities.first));
    }
  }

  Future<void> selectCity(Map<String, dynamic> next) async {
    city = next;
    await _prefs.setString('city', jsonEncode(next));
    notifyListeners();
    await loadShop();
    await loadRootCategories();
    if (isLoggedIn) await refreshCart();
  }

  Future<void> loadShop() async {
    final point = browseCoords;
    final result = await api.shop(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (result.ok) shop = result.dataMap;
    notifyListeners();
  }

  Future<void> loadRootCategories() async {
    final result = await api.categories(categoryId: 0, limit: 50, offset: 0);
    if (result.ok) {
      rootCategories = result.dataMaps;
    }
    notifyListeners();
  }

  Future<void> loadAddresses() async {
    if (!isLoggedIn) return;
    final result = await api.addresses();
    if (result.ok) {
      addresses = result.dataMaps;
      selectedAddress ??= addresses.cast<Map<String, dynamic>?>().firstWhere(
        (item) => J.i(item?['is_default']) == 1,
        orElse: () => addresses.isNotEmpty ? addresses.first : null,
      );
    }
    notifyListeners();
  }

  Future<String?> login({
    required String mobile,
    required String password,
  }) async {
    final result = await api.loginMobile(mobile: mobile, password: password);
    if (!result.ok)
      return result.message.isEmpty ? t('login_error') : result.message;
    await _applyAuth(result);
    return null;
  }

  Future<String?> registerCustomer({
    required String name,
    required String mobile,
    required String password,
    String email = '',
  }) async {
    final result = await api.register(
      name: name,
      mobile: mobile,
      password: password,
      email: email,
    );
    if (!result.ok) return result.message;
    await _applyAuth(result);
    return null;
  }

  Future<void> _applyAuth(ApiResult result) async {
    token = result.token ?? J.str(result.dataMap['access_token']);
    if (token == null || token!.isEmpty) {
      throw StateError('missing_token');
    }
    user = result.user.isNotEmpty ? result.user : result.dataMap;
    api.setToken(token);
    await _prefs.setString('token', token!);
    if (guestCart.isNotEmpty) {
      final ids = guestCart
          .map((item) => '${item['product_variant_id']}')
          .join(',');
      final qtys = guestCart.map((item) => '${item['qty']}').join(',');
      await api.bulkAddToCart(variantIds: ids, quantities: qtys);
      guestCart = [];
      guestCartTotal = 0;
      await _prefs.remove('guest_cart');
    }
    await reloadSettings();
    await resolveCity();
    await loadShop();
    await refreshCart();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    token = null;
    user = null;
    cart = null;
    cartProducts = [];
    addresses = [];
    selectedAddress = null;
    promoCode = null;
    favoriteIds = [];
    api.setToken(null);
    await _prefs.remove('token');
  }

  Future<ApiResult> refreshCart({int checkout = 0}) async {
    final point = _cartCoords(checkout: checkout == 1);
    if (point == null) return ApiResult({'status': 0});
    if (isLoggedIn) {
      final result = await api.cart(
        latitude: point.latitude,
        longitude: point.longitude,
        checkout: checkout,
      );
      if (result.ok) {
        cart = result.dataMap;
        cartProducts = J.maps(cart?['cart'] ?? cart?['items'] ?? result.data);
        cartSubTotal = J.d(cart?['sub_total'] ?? cart?['total']);
      }
      notifyListeners();
      return result;
    }
    if (guestCart.isEmpty) {
      guestCartTotal = 0;
      notifyListeners();
      return ApiResult({'status': 1, 'data': []});
    }
    final result = await api.guestCart(
      latitude: point.latitude,
      longitude: point.longitude,
      variantIds: guestCart
          .map((item) => '${item['product_variant_id']}')
          .join(','),
      quantities: guestCart.map((item) => '${item['qty']}').join(','),
    );
    if (result.ok) {
      guestCartTotal = J.d(
        result.dataMap['sub_total'] ?? result.dataMap['total'],
      );
      final priced = J.maps(result.dataMap['cart'] ?? result.data);
      if (priced.isNotEmpty) {
        guestCart = priced;
      }
    }
    notifyListeners();
    return result;
  }

  ({double latitude, double longitude})? _cartCoords({required bool checkout}) {
    if (checkout && selectedAddress != null) {
      final lat = double.tryParse('${selectedAddress!['latitude']}');
      final lng = double.tryParse('${selectedAddress!['longitude']}');
      if (lat != null && lng != null) return (latitude: lat, longitude: lng);
    }
    return coords;
  }

  /// Returns `same_seller` when mixing sellers is not allowed.
  Future<String?> addToCart({
    required dynamic productId,
    required dynamic variantId,
    required int qty,
    double? productPrice,
    dynamic sellerId,
    bool replaceSeller = false,
  }) async {
    if (isLoggedIn) {
      if (replaceSeller) await api.clearCart();
      final result = await api.addToCart(
        productId: productId,
        variantId: variantId,
        qty: qty,
      );
      if (result.oneSellerError == 1) return 'same_seller';
      if (!result.ok)
        return result.message.isEmpty
            ? t('something_went_wrong')
            : result.message;
      await refreshCart();
      return null;
    }
    if (replaceSeller) {
      guestCart = [];
    } else if (guestCart.isNotEmpty && sellerId != null) {
      final current = guestCart.first['seller_id'];
      if (current != null &&
          '$current'.isNotEmpty &&
          '$current' != '$sellerId') {
        return 'same_seller';
      }
    }
    final existingIndex = guestCart.indexWhere(
      (item) => '${item['product_variant_id']}' == '$variantId',
    );
    if (existingIndex >= 0) {
      guestCart[existingIndex]['qty'] = qty;
    } else {
      guestCart.add({
        'product_id': productId,
        'product_variant_id': variantId,
        'qty': qty,
        if (sellerId != null) 'seller_id': sellerId,
        if (productPrice != null) 'productPrice': productPrice,
      });
    }
    await _prefs.setString('guest_cart', jsonEncode(guestCart));
    await refreshCart();
    return null;
  }

  Future<void> removeCartLine({
    required dynamic productId,
    required dynamic variantId,
  }) async {
    if (isLoggedIn) {
      await api.removeFromCart(productId: productId, variantId: variantId);
      await refreshCart();
      return;
    }
    guestCart.removeWhere(
      (item) => '${item['product_variant_id']}' == '$variantId',
    );
    await _prefs.setString('guest_cart', jsonEncode(guestCart));
    await refreshCart();
  }

  Future<void> clearAllCart() async {
    if (isLoggedIn) {
      await api.clearCart();
    }
    guestCart = [];
    await _prefs.remove('guest_cart');
    await refreshCart();
  }

  Future<String?> applyPromo(String code, double total) async {
    final result = await api.validatePromo(promoCode: code, total: total);
    if (!result.ok) return result.message;
    promoCode = result.dataMap.isNotEmpty
        ? result.dataMap
        : {'promo_code': code, ...result.raw};
    notifyListeners();
    return null;
  }

  void clearPromo() {
    promoCode = null;
    notifyListeners();
  }

  void selectAddress(Map<String, dynamic>? address) {
    selectedAddress = address;
    notifyListeners();
  }

  void setUser(Map<String, dynamic>? next) {
    user = next;
    notifyListeners();
  }

  bool isFavorite(dynamic productId) =>
      favoriteIds.map((id) => '$id').contains('$productId');

  Future<void> toggleFavorite(dynamic productId) async {
    if (!isLoggedIn) return;
    if (isFavorite(productId)) {
      await api.removeFavorite(productId);
      favoriteIds.removeWhere((id) => '$id' == '$productId');
    } else {
      await api.addFavorite(productId);
      favoriteIds.add(productId);
    }
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    final uid = J.str(user?['auth_uid'] ?? user?['id']);
    final result = await api.deleteAccount(uid);
    if (!result.ok)
      return result.message.isEmpty
          ? t('something_went_wrong')
          : result.message;
    await _clearSession();
    notifyListeners();
    return null;
  }

  Future<String> cmsHtml(String key) async {
    var html = J.html(settings[key]);
    if (html.trim().isEmpty) html = J.html(webSettings[key]);
    if (html.trim().isEmpty) {
      final result = switch (key) {
        'privacy_policy' => await api.privacyPolicy(),
        'terms_conditions' => await api.termsConditions(),
        'about_us' => await api.aboutUs(),
        'contact_us' => await api.contactUs(),
        _ => ApiResult({'status': 0}),
      };
      if (result.ok) html = result.html;
    }
    if (html.trim().isEmpty && key == 'contact_us') {
      final email = J.str(settings['support_email']);
      final phone = J.str(settings['support_number']);
      final address = J.str(settings['store_address']);
      html = [
        if (phone.isNotEmpty) '<p>$phone</p>',
        if (email.isNotEmpty) '<p>$email</p>',
        if (address.isNotEmpty) '<p>$address</p>',
      ].join();
    }
    return html;
  }

  String _newViewerKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

final appController = AppController();
