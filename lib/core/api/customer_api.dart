import 'dart:convert';

import 'package:dio/dio.dart';

import '../config.dart';
import '../json_util.dart';

class CustomerApi {
  CustomerApi({required String baseUrl, String? token, String? viewerKey}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBase(baseUrl),
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 40),
        sendTimeout: const Duration(seconds: 40),
        headers: {AppConfig.accessKeyHeader: AppConfig.accessKey},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    setToken(token);
    setViewerKey(viewerKey);
  }

  late final Dio _dio;

  static String _normalizeBase(String url) {
    var root = url.trim();
    if (root.endsWith('/')) root = root.substring(0, root.length - 1);
    var sub = AppConfig.apiSubUrl;
    if (!sub.startsWith('/')) sub = '/$sub';
    if (sub.endsWith('/')) sub = sub.substring(0, sub.length - 1);
    return '$root$sub/';
  }

  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  void setViewerKey(String? key) {
    if (key != null && key.isNotEmpty) {
      _dio.options.headers['X-Viewer-Key'] = key;
    } else {
      _dio.options.headers.remove('X-Viewer-Key');
    }
  }

  void setBaseUrl(String url) {
    _dio.options.baseUrl = _normalizeBase(url);
  }

  Options get _form =>
      Options(contentType: Headers.multipartFormDataContentType);

  Future<ApiResult> _guard(Future<Response> Function() request) async {
    try {
      return _parse(await request());
    } on DioException catch (error) {
      final offline =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
      return ApiResult({
        'status': 0,
        'message': offline
            ? 'تعذر الاتصال بالخادم'
            : (error.message ?? 'حدث خطأ ما'),
      });
    } catch (error) {
      return ApiResult({'status': 0, 'message': '$error'});
    }
  }

  Future<ApiResult> _get(String path, [Map<String, dynamic>? query]) {
    return _guard(() => _dio.get(path, queryParameters: _clean(query)));
  }

  Future<ApiResult> _post(String path, [Map<String, dynamic>? fields]) {
    return _guard(
      () => _dio.post(
        path,
        data: FormData.fromMap(_clean(fields) ?? {}),
        options: _form,
      ),
    );
  }

  Future<ApiResult> _postRaw(String path, FormData data) {
    return _guard(() => _dio.post(path, data: data, options: _form));
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? input) {
    if (input == null) return null;
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      out[key] = value;
    });
    return out;
  }

  ApiResult _parse(Response response) {
    final data = response.data;
    if (data is Map) return ApiResult(J.map(data));
    return ApiResult({
      'status': 0,
      'message': 'invalid_response',
      'data': data,
    });
  }

  // ---- Auth ----
  Future<ApiResult> register({
    required String name,
    String email = '',
    required String mobile,
    required String password,
    String type = 'phone',
    String fcm = '',
    String countryCode = AppConfig.countryDialCode,
  }) {
    return _post('register', {
      'name': name,
      'email': email,
      'mobile': mobile,
      'password': password,
      'type': type,
      'fcm_token': fcm,
      'country_code': countryCode,
      'platform': AppConfig.platform,
    });
  }

  Future<ApiResult> loginMobile({
    required String mobile,
    required String password,
    String fcm = '',
    String countryCode = AppConfig.countryDialCode,
  }) {
    return _post('login_mobile', {
      'mobile': mobile,
      'password': password,
      'fcm_token': fcm,
      'country_code': countryCode,
      'platform': AppConfig.platform,
    });
  }

  Future<ApiResult> login({
    String? id,
    String? type,
    String? email,
    String? password,
    String fcm = '',
  }) {
    return _post('login', {
      if (email != null) 'email': email,
      if (password != null) 'password': password,
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      'fcm_token': fcm,
      'platform': AppConfig.platform,
    });
  }

  Future<ApiResult> logout() => _post('logout');

  Future<ApiResult> deleteAccount(String uid) =>
      _post('delete_account', {'auth_uid': uid});

  Future<ApiResult> userDetails() => _get('user_details');

  Future<ApiResult> editProfile({
    required String name,
    String email = '',
    MultipartFile? profile,
  }) {
    final data = FormData.fromMap({'name': name, 'email': email});
    if (profile != null) data.files.add(MapEntry('profile', profile));
    return _postRaw('edit_profile', data);
  }

  Future<ApiResult> forgotPasswordOtp({
    required String mobile,
    String countryCode = AppConfig.countryDialCode,
  }) {
    return _post('forgot_password_otp', {
      'mobile': mobile,
      'country_code': countryCode,
    });
  }

  Future<ApiResult> resetPasswordOtp({
    required String mobile,
    required String otp,
    required String password,
    required String passwordConfirmation,
    String countryCode = AppConfig.countryDialCode,
  }) {
    return _post('reset_password_otp', {
      'mobile': mobile,
      'country_code': countryCode,
      'otp': otp,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  Future<ApiResult> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) {
    return _post('change_password', {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  Future<ApiResult> sendSms(String phone) =>
      _post('send_sms', {'phone': phone});

  Future<ApiResult> verifyUser({
    String? mobile,
    String? otp,
    String? countryCode,
  }) {
    return _post('verify_user', {
      if (mobile != null) 'phone': mobile,
      if (mobile != null) 'mobile': mobile,
      if (otp != null) 'otp': otp,
      if (countryCode != null) 'country_code': countryCode,
    });
  }

  // ---- Settings / location / shop ----
  Future<ApiResult> settings({bool withAuth = false}) =>
      _get('settings', {'is_web_setting': 1});

  Future<ApiResult> paymentMethods() => _get('settings/payment_methods');

  Future<ApiResult> timeSlots() => _get('settings/time_slots');

  Future<ApiResult> privacyPolicy() => _get('settings/privacy_policy');

  Future<ApiResult> termsConditions() => _get('settings/terms_conditions');

  Future<ApiResult> aboutUs() => _get('settings/about_us');

  Future<ApiResult> contactUs() => _get('settings/contact_us');

  Future<ApiResult> city({
    required double latitude,
    required double longitude,
  }) {
    return _get('city', {'latitude': latitude, 'longitude': longitude});
  }

  Future<ApiResult> cities({
    int limit = 100,
    int offset = 0,
    String search = '',
  }) {
    return _get('cities', {
      'limit': limit,
      'offset': offset,
      if (search.isNotEmpty) 'search': search,
    });
  }

  Future<ApiResult> shop({
    required double latitude,
    required double longitude,
  }) {
    return _get('shop', {
      'latitude': latitude,
      'longitude': longitude,
      if (_dio.options.headers['X-Viewer-Key'] != null)
        'viewer_key': _dio.options.headers['X-Viewer-Key'],
    });
  }

  Future<ApiResult> sliders() => _get('sliders');
  Future<ApiResult> offers() => _get('offers');
  Future<ApiResult> sections({
    int? cityId,
    double? latitude,
    double? longitude,
  }) {
    return _get('sections', {
      if (cityId != null) 'city_id': cityId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  Future<ApiResult> categories({
    dynamic categoryId,
    dynamic limit,
    dynamic offset,
    String? slug,
  }) {
    return _get('categories', {
      if (categoryId != null) 'category_id': categoryId,
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (slug != null) 'slug': slug,
    });
  }

  Future<ApiResult> brands({int limit = 20, int offset = 0}) {
    return _get('brands', {'limit': limit, 'offset': offset});
  }

  Future<ApiResult> sellers({
    double? latitude,
    double? longitude,
    int limit = 50,
    int offset = 0,
  }) {
    return _get('sellers', {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'limit': limit,
      'offset': offset,
    });
  }

  Future<ApiResult> sellerBySlug(String slug) => _get('seller/by-slug/$slug');
  Future<ApiResult> sellerById(String id) => _get('seller/by-id/$id');
  Future<ApiResult> countries({int limit = 50, int offset = 0}) {
    return _get('countries', {'limit': limit, 'offset': offset});
  }

  Future<ApiResult> faqs({int limit = 30, int offset = 0}) {
    return _get('faqs', {'limit': limit, 'offset': offset});
  }

  Future<ApiResult> assistantChat(
    String message, {
    List<Map<String, String>> history = const [],
    String? sellerId,
    String? sellerSlug,
  }) {
    return _post('assistant/chat', {
      'message': message,
      if (history.isNotEmpty) 'history': jsonEncode(history),
      if (sellerId != null && sellerId.isNotEmpty) 'seller_id': sellerId,
      if (sellerSlug != null && sellerSlug.isNotEmpty) 'seller_slug': sellerSlug,
    });
  }

  Future<ApiResult> flashSales({int limit = 20}) =>
      _get('flash_sales', {'limit': limit});
  Future<ApiResult> campaigns() => _get('campaigns');
  Future<ApiResult> deliveryOfferHint({double? amount, dynamic cityId}) {
    return _get('delivery_offers/hint', {
      if (amount != null) 'amount': amount,
      if (cityId != null) 'city_id': cityId,
    });
  }

  // ---- Products ----
  Future<ApiResult> products({
    required double latitude,
    required double longitude,
    Map<String, dynamic> filters = const {},
    String tagNames = '',
    String slug = '',
  }) {
    return _post('products', {
      'latitude': latitude,
      'longitude': longitude,
      if (tagNames.isNotEmpty) 'tag_names': tagNames,
      if (slug.isNotEmpty) 'slug': slug,
      ...filters,
    });
  }

  Future<ApiResult> productById({
    required double latitude,
    required double longitude,
    dynamic id,
    String slug = '',
  }) {
    return _post('product_by_id', {
      'latitude': latitude,
      'longitude': longitude,
      if (id != null) 'id': id,
      if (slug.isNotEmpty) 'slug': slug,
      if (_dio.options.headers['X-Viewer-Key'] != null)
        'viewer_key': _dio.options.headers['X-Viewer-Key'],
    });
  }

  Future<ApiResult> productsOffers({
    required double latitude,
    required double longitude,
    int limit = 10,
    int offset = 0,
  }) {
    return _get('products/offers', {
      'latitude': latitude,
      'longitude': longitude,
      'limit': limit,
      'offset': offset,
    });
  }

  Future<ApiResult> catalogOffers({
    required dynamic productId,
    String name = '',
    String sort = 'price',
  }) {
    return _post('products/catalog_offers', {
      'product_id': productId,
      if (name.isNotEmpty) 'name': name,
      'sort': sort,
    });
  }

  Future<ApiResult> productRatings({
    required dynamic productId,
    int limit = 10,
    int offset = 0,
  }) {
    return _get('products/ratings_list', {
      'product_id': productId,
      'limit': limit,
      'offset': offset,
    });
  }

  Future<ApiResult> addProductRating(Map<String, dynamic> fields) =>
      _post('products/rating/add', fields);
  Future<ApiResult> updateProductRating(Map<String, dynamic> fields) =>
      _post('products/rating/update', fields);
  Future<ApiResult> rateSeller(Map<String, dynamic> fields) =>
      _post('seller_rating/add', fields);
  Future<ApiResult> rateDeliveryBoy(Map<String, dynamic> fields) =>
      _post('delivery_boy_rating/add', fields);

  // ---- Cart ----
  Future<ApiResult> cart({
    required double latitude,
    required double longitude,
    int checkout = 0,
  }) {
    return _get('cart', {
      'latitude': latitude,
      'longitude': longitude,
      'is_checkout': checkout,
    });
  }

  Future<ApiResult> cartCount() => _get('cart/get_cart_count');

  Future<ApiResult> addToCart({
    required dynamic productId,
    required dynamic variantId,
    required dynamic qty,
  }) {
    return _post('cart/add', {
      'product_id': productId,
      'product_variant_id': variantId,
      'qty': qty,
    });
  }

  Future<ApiResult> removeFromCart({
    required dynamic productId,
    required dynamic variantId,
  }) {
    return _post('cart/remove', {
      'product_id': productId,
      'product_variant_id': variantId,
      'is_remove_all': 0,
    });
  }

  Future<ApiResult> clearCart() => _post('cart/remove', {'is_remove_all': 1});

  Future<ApiResult> guestCart({
    required double latitude,
    required double longitude,
    required String variantIds,
    required String quantities,
  }) {
    return _get('cart/guest_cart', {
      'latitude': latitude,
      'longitude': longitude,
      'variant_ids': variantIds,
      'quantities': quantities,
    });
  }

  Future<ApiResult> bulkAddToCart({
    required String variantIds,
    required String quantities,
  }) {
    return _post('cart/bulk_add_to_cart_items', {
      'variant_ids': variantIds,
      'quantities': quantities,
    });
  }

  Future<ApiResult> promoCodes(double amount) =>
      _get('promo_code', {'amount': amount});

  Future<ApiResult> validatePromo({
    required String promoCode,
    required double total,
  }) {
    return _post('promo_code/validate', {
      'promo_code': promoCode,
      'total': total,
    });
  }

  Future<ApiResult> placeOrder(Map<String, dynamic> fields) =>
      _post('place_order', fields);
  Future<ApiResult> deleteOrder(dynamic orderId) =>
      _post('delete_order', {'order_id': orderId});

  Future<ApiResult> orders({
    int limit = 10,
    int offset = 0,
    int type = 1,
    dynamic orderId,
  }) {
    return _get(
      'orders',
      orderId != null
          ? {'order_id': orderId}
          : {'limit': limit, 'offset': offset, 'type': type},
    );
  }

  Future<ApiResult> updateOrderStatus(Map<String, dynamic> fields) =>
      _post('update_order_status', fields);
  Future<ApiResult> initiateTransaction(Map<String, dynamic> fields) =>
      _post('initiate_transaction', fields);
  Future<ApiResult> addTransaction(Map<String, dynamic> fields) =>
      _post('add_transaction', fields);
  Future<ApiResult> transactions({
    int limit = 10,
    int offset = 0,
    String type = 'transactions',
  }) {
    return _get('get_user_transactions', {
      'limit': limit,
      'offset': offset,
      'type': type,
    });
  }

  Future<ApiResult> invoice(dynamic orderId) =>
      _post('invoice_download', {'order_id': orderId});

  // ---- Favorites / address / notifications ----
  Future<ApiResult> favorites({
    required double latitude,
    required double longitude,
  }) {
    return _get('favorites', {'latitude': latitude, 'longitude': longitude});
  }

  Future<ApiResult> addFavorite(dynamic productId) =>
      _post('favorites/add', {'product_id': productId});
  Future<ApiResult> removeFavorite(dynamic productId) =>
      _post('favorites/remove', {'product_id': productId});

  Future<ApiResult> addresses() => _get('address');
  Future<ApiResult> addAddress(Map<String, dynamic> fields) =>
      _post('address/add', fields);
  Future<ApiResult> updateAddress(Map<String, dynamic> fields) =>
      _post('address/update', fields);
  Future<ApiResult> deleteAddress(dynamic id) =>
      _post('address/delete', {'id': id});

  Future<ApiResult> notifications({int limit = 20, int offset = 0}) {
    return _get('notifications', {'limit': limit, 'offset': offset});
  }

  // ---- Haraj ----
  Future<ApiResult> harajCategories() => _get('haraj/categories');
  Future<ApiResult> harajCategoriesAll() => _get('haraj/categories/all');
  Future<ApiResult> harajPosts(Map<String, dynamic> params) =>
      _get('haraj/posts', params);
  Future<ApiResult> harajPost(dynamic id) => _get('haraj/posts/$id');
  Future<ApiResult> harajMyPosts(Map<String, dynamic> params) =>
      _get('haraj/my-posts', params);

  Future<ApiResult> harajCreate(FormData data) =>
      _postRaw('haraj/posts/create', data);
  Future<ApiResult> harajUpdate(dynamic id, FormData data) =>
      _postRaw('haraj/posts/$id/update', data);
  Future<ApiResult> harajDelete(dynamic id) => _post('haraj/posts/$id/delete');
  Future<ApiResult> harajMarkSold(dynamic id) =>
      _post('haraj/posts/$id/mark-sold');
  Future<ApiResult> harajComments(dynamic postId) =>
      _get('haraj/posts/$postId/comments');
  Future<ApiResult> harajAddComment(dynamic postId, String comment) {
    return _post('haraj/posts/$postId/comments', {'comment': comment});
  }

  Future<ApiResult> harajRate(Map<String, dynamic> fields) =>
      _post('haraj/ratings', fields);
  Future<ApiResult> harajBlock(Map<String, dynamic> fields) =>
      _post('haraj/blocks', fields);

  // ---- Akhdimni ----
  Future<ApiResult> akhdimniConfig() => _get('akhdimni/config');
  Future<ApiResult> akhdimniEstimate(Map<String, dynamic> fields) =>
      _post('akhdimni/estimate', fields);
  Future<ApiResult> akhdimniPlace(Map<String, dynamic> fields) =>
      _post('akhdimni/place', fields);
  Future<ApiResult> akhdimniOrders(Map<String, dynamic> params) =>
      _get('akhdimni/orders', params);
  Future<ApiResult> akhdimniOrder(dynamic id) => _get('akhdimni/orders/$id');
  Future<ApiResult> akhdimniCancel(dynamic id, [Map<String, dynamic>? fields]) {
    return _post('akhdimni/orders/$id/cancel', fields);
  }
}
