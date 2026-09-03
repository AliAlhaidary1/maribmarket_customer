import 'json_util.dart';

class BusinessHoursSlot {
  BusinessHoursSlot({required this.isOpen, this.nextOpeningAt});
  final bool isOpen;
  final String? nextOpeningAt;
  static BusinessHoursSlot? from(dynamic raw) {
    if (raw == null) return null;
    final m = J.map(raw);
    if (m.isEmpty) return null;
    return BusinessHoursSlot(
      isOpen: m['is_open'] == true || m['is_open'] == 1 || m['is_open'] == '1',
      nextOpeningAt: m['next_opening_at']?.toString(),
    );
  }
}

class BusinessHoursResult {
  BusinessHoursResult({this.platform, this.sellers = const {}});
  final BusinessHoursSlot? platform;
  final Map<String, BusinessHoursSlot> sellers;
  static BusinessHoursResult from(ApiResult res) {
    final data = res.dataMap.isNotEmpty ? res.dataMap : J.map(res.raw['data']);
    final platform = BusinessHoursSlot.from(data['platform']);
    final sellersRaw = J.map(data['sellers']);
    final sellers = <String, BusinessHoursSlot>{};
    sellersRaw.forEach((k, v) {
      final slot = BusinessHoursSlot.from(v);
      if (slot != null) sellers[k] = slot;
    });
    // also handle sellers as list with seller_id
    if (sellers.isEmpty && data['sellers'] is List) {
      for (final item in J.maps(data['sellers'])) {
        final sid = '${item['seller_id'] ?? item['id']}';
        final slot = BusinessHoursSlot.from(item);
        if (sid.isNotEmpty && slot != null) sellers[sid] = slot;
      }
    }
    return BusinessHoursResult(platform: platform, sellers: sellers);
  }
}

String formatBusinessTime(String? value) {
  if (value == null || value.isEmpty) return '';
  final parts = value.split(':');
  if (parts.length < 2) return value;
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}

String buildMarketplaceClosedMessage(BusinessHoursSlot? platform) {
  if (platform == null || platform.isOpen) return '';
  final t = formatBusinessTime(platform.nextOpeningAt);
  if (t.isNotEmpty) return 'المتجر مغلق حتى $t';
  return 'المتجر مغلق حالياً';
}

String buildSellerClosedMessage(BusinessHoursSlot? seller, String storeName) {
  if (seller == null || seller.isOpen) return '';
  final t = formatBusinessTime(seller.nextOpeningAt);
  if (t.isNotEmpty) return 'المتجر $storeName مغلق حتى $t';
  return 'المتجر $storeName مغلق';
}

class CanPlaceOrderResult {
  CanPlaceOrderResult({required this.allowed, this.reason, this.status});
  final bool allowed;
  final String? reason; // platform | seller | unavailable
  final BusinessHoursSlot? status;
}

CanPlaceOrderResult canPlaceOrderFromBusinessHours(BusinessHoursResult? bh) {
  if (bh == null) return CanPlaceOrderResult(allowed: false, reason: 'unavailable');
  if (bh.platform != null && !bh.platform!.isOpen) {
    return CanPlaceOrderResult(allowed: false, reason: 'platform', status: bh.platform);
  }
  for (final e in bh.sellers.values) {
    if (!e.isOpen) return CanPlaceOrderResult(allowed: false, reason: 'seller', status: e);
  }
  return CanPlaceOrderResult(allowed: true);
}

BusinessHoursSlot? closedSellerFromCheckout(BusinessHoursResult? bh) {
  if (bh == null) return null;
  for (final s in bh.sellers.values) {
    if (!s.isOpen) return s;
  }
  return null;
}
