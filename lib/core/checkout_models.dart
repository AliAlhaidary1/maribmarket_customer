import 'json_util.dart';

class CheckoutConfig {
  CheckoutConfig({
    this.maxSellersPerCheckout = 5,
    this.distanceThreshold = 10,
    this.distanceFeePerKm = 2,
    this.platformFee = 0,
    this.baseFee = 0,
    this.maxDistanceKm = 50,
  });
  final int maxSellersPerCheckout;
  final double distanceThreshold;
  final double distanceFeePerKm;
  final double platformFee;
  final double baseFee;
  final double maxDistanceKm;

  static CheckoutConfig from(ApiResult res) {
    final m = res.dataMap.isNotEmpty ? res.dataMap : J.map(res.raw['data']);
    return CheckoutConfig(
      maxSellersPerCheckout: J.i(m['max_sellers_per_checkout'], 5),
      distanceThreshold: J.d(m['distance_threshold'], 10),
      distanceFeePerKm: J.d(m['distance_fee_per_km'], 2),
      platformFee: J.d(m['platform_fee'], 0),
      baseFee: J.d(m['base_fee'], 0),
      maxDistanceKm: J.d(m['max_distance_km'], 50),
    );
  }
  static CheckoutConfig defaults() => CheckoutConfig();
}

class SellerGroup {
  SellerGroup({required this.sellerId, this.storeName, this.items = const [], this.subtotal = 0});
  final dynamic sellerId;
  final String? storeName;
  final List<Map<String, dynamic>> items;
  final double subtotal;

  static List<SellerGroup> fromCheckout(ApiResult res) {
    final data = res.dataMap.isNotEmpty ? res.dataMap : J.map(res.raw['data']);
    final groupsRaw = J.list(data['seller_groups'] ?? data['sellerGroups'] ?? data['groups']);
    if (groupsRaw.isEmpty && data['cart'] is Map) {
      // fallback single group
      return [];
    }
    return groupsRaw.map((e) {
      final m = J.map(e);
      return SellerGroup(
        sellerId: m['seller_id'] ?? m['id'],
        storeName: m['store_name']?.toString(),
        items: J.maps(m['items']),
        subtotal: J.d(m['subtotal'] ?? m['sub_total']),
      );
    }).toList();
  }
}

class MultiSellerCheckout {
  MultiSellerCheckout({
    this.sellerGroups = const [],
    this.deliveryFees = const {},
    this.paymentSplit = const [],
    this.platformFee = 0,
    this.subtotal = 0,
    this.deliveryTotal = 0,
    this.finalTotal = 0,
  });
  final List<SellerGroup> sellerGroups;
  final Map<String, dynamic> deliveryFees;
  final List<Map<String, dynamic>> paymentSplit;
  final double platformFee;
  final double subtotal;
  final double deliveryTotal;
  final double finalTotal;

  static MultiSellerCheckout from(ApiResult res) {
    final data = res.dataMap.isNotEmpty ? res.dataMap : J.map(res.raw['data']);
    return MultiSellerCheckout(
      sellerGroups: SellerGroup.fromCheckout(res),
      deliveryFees: J.map(data['delivery_fees'] ?? data['deliveryFees']),
      paymentSplit: J.maps(data['payment_split'] ?? data['paymentSplit']),
      platformFee: J.d(data['platform_fee']),
      subtotal: J.d(data['sub_total'] ?? data['subtotal']),
      deliveryTotal: J.d(data['delivery_charge'] ?? data['delivery_fee']),
      finalTotal: J.d(data['final_total'] ?? data['total']),
    );
  }
}

class TimeSlot {
  TimeSlot({required this.title, this.from, this.to});
  final String title;
  final String? from;
  final String? to;
  static List<TimeSlot> parse(ApiResult res) {
    final list = res.dataMaps.isNotEmpty ? res.dataMaps : J.maps(res.raw['data']);
    return list.map((m) => TimeSlot(title: J.str(m['title'] ?? m['slot'] ?? m['name']), from: m['from']?.toString(), to: m['to']?.toString())).toList();
  }
}
