import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/city_mode.dart';
import '../../core/device_location.dart';
import '../../core/json_util.dart';
import '../../core/promo_price.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';
import '../../core/app_theme.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/ui_helpers.dart';
import '../products/products_screens.dart';

class SellersScreen extends StatefulWidget {
  const SellersScreen({super.key, this.typeId});
  final String? typeId;

  @override
  State<SellersScreen> createState() => _SellersScreenState();
}

class _SellersScreenState extends State<SellersScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? selectedType;
  String sort = 'nearest';
  ({double latitude, double longitude}) origin = (latitude: 0, longitude: 0);

  @override
  void initState() {
    super.initState();
    selectedType = widget.typeId;
    _load();
  }

  @override
  void didUpdateWidget(covariant SellersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.typeId != widget.typeId) {
      selectedType = widget.typeId;
    }
  }

  double? _distanceKm(Map<String, dynamic> seller) {
    final stored = seller['distance'];
    if (stored != null) {
      final parsed = double.tryParse('$stored');
      if (parsed != null) return parsed;
    }
    final lat = double.tryParse('${seller['latitude']}');
    final lng = double.tryParse('${seller['longitude']}');
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    if (origin.latitude == 0 && origin.longitude == 0) return null;
    return Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          lat,
          lng,
        ) /
        1000;
  }

  Future<void> _load() async {
    final device = await currentDevicePoint();
    origin = device ?? appController.browseCoords;
    final res = await appController.api.sellers(
      latitude: origin.latitude,
      longitude: origin.longitude,
      limit: 500,
    );
    if (!mounted) return;
    setState(() {
      items = res.dataMaps;
      loading = false;
    });
  }

  List<int> _sellerTypeIds(Map<String, dynamic> seller) {
    final ids = seller['category_ids'];
    if (ids is List) {
      return ids
          .map((e) => int.tryParse('$e') ?? 0)
          .where((e) => e > 0)
          .toList();
    }
    final csv = J.str(seller['categories']);
    if (csv.isEmpty) return [];
    return csv
        .split(',')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }

  void _selectType(String? id) {
    setState(() => selectedType = id);
    context.go(id == null || id.isEmpty ? '/sellers' : '/sellers?type=$id');
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    final types = app.rootCategories.isNotEmpty
        ? app.rootCategories
        : J.maps(app.shop?['categories']);
    final visible = items.where((seller) {
      if (selectedType == null || selectedType!.isEmpty) return true;
      return _sellerTypeIds(seller).contains(int.tryParse(selectedType!) ?? 0);
    }).toList()
      ..sort((a, b) {
        if (sort != 'nearest') return 0;
        final da = _distanceKm(a);
        final db = _distanceKm(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return Scaffold(
      backgroundColor: AppTheme.surfaceGrey,
      appBar: AppBar(title: Text(app.t('sellers'))),
      body: loading
          ? ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const SellerCardSkeleton(),
            )
          : Column(
              children: [
                if (types.isNotEmpty)
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: types.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          final selected =
                              selectedType == null || selectedType!.isEmpty;
                          return ChoiceChip(
                            label: Text(
                              app.t('all') == 'all' ? 'الكل' : app.t('all'),
                            ),
                            selected: selected,
                            onSelected: (_) => _selectType(null),
                          );
                        }
                        final cat = types[i - 1];
                        final id = '${cat['id']}';
                        return ChoiceChip(
                          label: Text(J.str(cat['name'])),
                          selected: selectedType == id,
                          onSelected: (_) =>
                              _selectType(selectedType == id ? null : id),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: visible.isEmpty
                      ? EmptyState(message: app.t('no_stores_found'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final seller = visible[i];
                            final distance = _distanceKm(seller);
                            final rating = double.tryParse(
                              '${seller['rating'] ?? seller['average_rating'] ?? 0}',
                            );
                            return _SellerCard(
                              seller: seller,
                              distance: distance,
                              rating: rating,
                              productCount:
                                  '${seller['product_count'] ?? 0}',
                              onTap: () {
                                final slug = J.str(seller['slug']);
                                context.push(
                                  slug.isNotEmpty
                                      ? '/store/$slug'
                                      : '/seller/${seller['id']}',
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class SellerPageScreen extends StatefulWidget {
  const SellerPageScreen({super.key, this.id, this.slug});
  final String? id;
  final String? slug;

  @override
  State<SellerPageScreen> createState() => _SellerPageScreenState();
}

class _SellerPageScreenState extends State<SellerPageScreen> {
  Map<String, dynamic>? seller;
  bool loading = true;
  String? sectionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = widget.slug != null
        ? await appController.api.sellerBySlug(widget.slug!)
        : await appController.api.sellerById('${widget.id}');
    if (!mounted) return;
    setState(() {
      seller = result.dataMap;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (seller == null || seller!.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          message: appController.t('no_stores_found'),
          actionLabel: appController.t('retry'),
          onAction: () {
            setState(() => loading = true);
            _load();
          },
        ),
      );
    }
    final id = '${seller?['id'] ?? widget.id}';
    final sections = J.maps(seller?['sections']);
    return Scaffold(
      appBar: AppBar(
        title: Text(J.str(seller?['store_name'] ?? seller?['name'])),
      ),
      body: Column(
        children: [
          ListTile(
            leading: SellerAvatar(
              J.str(seller?['logo_url']),
              radius: 28,
              placeholder: appController.placeholder,
            ),
            title: Text(J.str(seller?['store_name'] ?? seller?['name'])),
            subtitle: Text(
              J.str(seller?['store_description'] ?? seller?['description']),
            ),
          ),
          if (sections.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: sectionId == null,
                    onSelected: (_) => setState(() => sectionId = null),
                  ),
                  ...sections.map(
                    (section) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ChoiceChip(
                        label: Text(J.str(section['name'])),
                        selected: sectionId == '${section['id']}',
                        onSelected: (_) => setState(() => sectionId = '${section['id']}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ProductsScreen(
              key: ValueKey('store-$id-${sectionId ?? 'all'}'),
              sellerId: id,
              sellerSectionId: sectionId,
            ),
          ),
        ],
      ),
    );
  }
}

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<Map<String, dynamic>> flash = [];
  List<Map<String, dynamic>> offers = [];
  Map<String, dynamic> campaigns = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final point = appController.browseCoords;
    final f = await appController.api.flashSales();
    final o = await appController.api.productsOffers(
      latitude: point.latitude,
      longitude: point.longitude,
      limit: 30,
    );
    final c = await appController.api.campaigns();
    if (!mounted) return;
    setState(() {
      flash = f.dataMaps;
      offers = o.dataMaps;
      campaigns = c.dataMap;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    final products = [
      ...flash.map((item) => J.map(item['product'] ?? item)),
      ...offers,
    ].where((item) => item.isNotEmpty).toList();
    final categoryCards = J.maps(campaigns['category_discounts']);
    final bxgyCards = J.maps(campaigns['bxgy']);
    final promoCards = J.maps(campaigns['promo_codes']);
    final deliveryCards = J.maps(campaigns['delivery']);
    return Scaffold(
      appBar: AppBar(title: Text(app.t('offers'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (categoryCards.isNotEmpty ||
                    bxgyCards.isNotEmpty ||
                    promoCards.isNotEmpty ||
                    deliveryCards.isNotEmpty)
                  Text(
                    app.t('active_campaigns_title') == 'active_campaigns_title'
                        ? 'العروض الحالية'
                        : app.t('active_campaigns_title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ...categoryCards.map(
                  (item) => Card(
                    child: ListTile(
                      leading: Icon(Icons.percent, color: app.accentColor),
                      title: Text(J.str(item['category_name'])),
                      subtitle: Text(
                        '${item['discount']}${J.str(item['discount_type']) == 'percentage' ? '%' : ''}',
                      ),
                      onTap: () => context.push(
                        '/sellers?type=${item['category_id']}',
                      ),
                    ),
                  ),
                ),
                ...promoCards.map(
                  (item) => Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.confirmation_number_outlined,
                        color: app.accentColor,
                      ),
                      title: Text(J.str(item['promo_code'])),
                      subtitle: Text(J.str(item['message'])),
                    ),
                  ),
                ),
                ...deliveryCards.map(
                  (item) => Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.local_shipping_outlined,
                        color: app.accentColor,
                      ),
                      title: Text(
                        J.str(
                          item['title'] ?? item['customer_message'],
                          'توصيل مجاني',
                        ),
                      ),
                    ),
                  ),
                ),
                if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        app.t('no_offers_available') == 'no_offers_available'
                            ? 'لا توجد عروض'
                            : app.t('no_offers_available'),
                      ),
                    ),
                  )
                else ...[
                  const SizedBox(height: 12),
                  Text(
                    app.t('discounted_products') == 'discounted_products'
                        ? 'منتجات مخفضة'
                        : app.t('discounted_products'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                    itemCount: products.length,
                    itemBuilder: (_, i) => ProductCard(
                      product: products[i],
                      onTap: () => context.push(
                        '/product/${products[i]['slug'] ?? products[i]['id']}',
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class AkhdimniHomeScreen extends StatelessWidget {
  const AkhdimniHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أخدمني')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            tileColor: Colors.white,
            title: const Text('من نقطة إلى نقطة'),
            onTap: () => context.push('/akhdimni/create?type=point_to_point'),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            title: const Text('أغراض خاصة'),
            onTap: () => context.push('/akhdimni/create?type=special_items'),
          ),
          ListTile(
            title: const Text('طلباتي'),
            onTap: () {
              if (!appController.isLoggedIn) {
                context.push('/login');
                return;
              }
              context.push('/akhdimni/orders');
            },
          ),
        ],
      ),
    );
  }
}

class AkhdimniCreateScreen extends StatefulWidget {
  const AkhdimniCreateScreen({super.key, required this.type});
  final String type;

  @override
  State<AkhdimniCreateScreen> createState() => _AkhdimniCreateScreenState();
}

class _AkhdimniCreateScreenState extends State<AkhdimniCreateScreen> {
  final pickup = TextEditingController();
  final dropoff = TextEditingController();
  final details = TextEditingController();
  Map<String, dynamic>? estimate;
  bool busy = false;
  ({double latitude, double longitude})? pickupPoint;
  ({double latitude, double longitude})? dropoffPoint;

  @override
  void initState() {
    super.initState();
    dropoffPoint = appController.coords;
    final address = appController.selectedAddress;
    if (address != null) {
      dropoff.text = J.str(address['address']);
      final lat = double.tryParse('${address['latitude']}');
      final lng = double.tryParse('${address['longitude']}');
      if (lat != null && lng != null)
        dropoffPoint = (latitude: lat, longitude: lng);
    }
  }

  @override
  void dispose() {
    pickup.dispose();
    dropoff.dispose();
    details.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _fields {
    final city = appController.city;
    final pick = pickupPoint ?? appController.coords;
    final drop = dropoffPoint ?? appController.coords;
    return {
      'type': widget.type,
      'pickup_address': pickup.text.trim(),
      'dropoff_address': dropoff.text.trim(),
      'details': details.text.trim(),
      'city_id': city?['id'],
      'pickup_latitude': pick?.latitude,
      'pickup_longitude': pick?.longitude,
      'dropoff_latitude': drop?.latitude,
      'dropoff_longitude': drop?.longitude,
      'payment_method': 'COD',
    };
  }

  Future<void> _useMyLocation() async {
    final app = appController;
    final allowed = await confirmAction(
      context,
      title: app.t('location_disclosure_title'),
      body: app.t('location_disclosure_body'),
    );
    if (!allowed || !mounted) return;
    setState(() => busy = true);
    final point = await currentDevicePoint();
    if (!mounted) return;
    setState(() {
      busy = false;
      if (point != null) {
        pickupPoint = point;
        if (pickup.text.trim().isEmpty)
          pickup.text = appController.t('pickup_my_location');
      }
    });
    if (point == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appController.t('location_permission_denied'))),
      );
    }
  }

  Future<void> _estimate() async {
    final app = appController;
    if (pickup.text.trim().isEmpty || dropoff.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(app.t('enter_pickup_dropoff'))));
      return;
    }
    if (widget.type == 'point_to_point' && pickupPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.t('location_permission_denied'))),
      );
      return;
    }
    setState(() => busy = true);
    final result = await app.api.akhdimniEstimate(_fields);
    if (!mounted) return;
    setState(() {
      busy = false;
      estimate = result.ok ? result.dataMap : null;
    });
    if (!result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _place() async {
    final app = appController;
    if (!app.isLoggedIn) {
      context.push('/login');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('confirm_order')),
        content: Text(
          money(
            estimate?['total'] ??
                estimate?['fare'] ??
                estimate?['delivery_charge'],
            app.currency,
            app.decimals,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(app.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(app.t('confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    final result = await app.api.akhdimniPlace(_fields);
    if (!mounted) return;
    setState(() => busy = false);
    if (result.ok) {
      context.go('/akhdimni/orders');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Scaffold(
      appBar: AppBar(title: const Text('طلب أخدمني')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: pickup,
            decoration: const InputDecoration(labelText: 'نقطة الاستلام'),
          ),
          if (widget.type == 'point_to_point')
            TextButton.icon(
              onPressed: busy ? null : _useMyLocation,
              icon: const Icon(Icons.my_location),
              label: Text(app.t('pickup_my_location')),
            ),
          TextField(
            controller: dropoff,
            decoration: const InputDecoration(labelText: 'نقطة التسليم'),
          ),
          TextField(
            controller: details,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'التفاصيل'),
          ),
          if (estimate != null) ...[
            const SizedBox(height: 8),
            Text(
              money(
                estimate?['total'] ??
                    estimate?['fare'] ??
                    estimate?['delivery_charge'],
                app.currency,
                app.decimals,
              ),
              style: TextStyle(
                color: app.accentColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : _estimate,
            child: Text(app.t('estimate_fare')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy || estimate == null ? null : _place,
            child: busy ? const BusySpinner() : Text(app.t('place_order')),
          ),
        ],
      ),
    );
  }
}

class AkhdimniOrdersScreen extends StatefulWidget {
  const AkhdimniOrdersScreen({super.key});

  @override
  State<AkhdimniOrdersScreen> createState() => _AkhdimniOrdersScreenState();
}

class _AkhdimniOrdersScreenState extends State<AkhdimniOrdersScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!appController.isLoggedIn) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final res = await appController.api.akhdimniOrders({});
    if (!mounted) return;
    setState(() {
      items = res.dataMaps;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات أخدمني')),
      body: !app.isLoggedIn
          ? const LoginRequired()
          : loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? EmptyState(message: app.t('akhdimni_no_orders'))
          : ListView(
              children: items
                  .map(
                    (item) => ListTile(
                      title: Text('#${item['id']}'),
                      subtitle: Text(J.str(item['status'])),
                      trailing: Text(
                        money(
                          item['total'] ?? item['fare'],
                          appController.currency,
                          appController.decimals,
                        ),
                      ),
                      onTap: () =>
                          context.push('/akhdimni/orders/${item['id']}'),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class AkhdimniOrderDetailsScreen extends StatefulWidget {
  const AkhdimniOrderDetailsScreen({super.key, required this.id});
  final String id;

  @override
  State<AkhdimniOrderDetailsScreen> createState() =>
      _AkhdimniOrderDetailsScreenState();
}

class _AkhdimniOrderDetailsScreenState
    extends State<AkhdimniOrderDetailsScreen> {
  Map<String, dynamic>? order;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    appController.api.akhdimniOrder(widget.id).then((res) {
      if (!mounted) return;
      setState(() {
        order = res.dataMap.isNotEmpty ? res.dataMap : J.map(res.raw);
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Scaffold(
      appBar: AppBar(title: Text('طلب #${widget.id}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('الحالة'),
                  subtitle: Text(J.str(order?['status'])),
                ),
                ListTile(
                  title: const Text('الاستلام'),
                  subtitle: Text(J.str(order?['pickup_address'])),
                ),
                ListTile(
                  title: const Text('التسليم'),
                  subtitle: Text(J.str(order?['dropoff_address'])),
                ),
                ListTile(
                  title: const Text('التفاصيل'),
                  subtitle: Text(J.str(order?['details'] ?? order?['notes'])),
                ),
                ListTile(
                  title: const Text('الإجمالي'),
                  subtitle: Text(
                    money(
                      order?['total'] ?? order?['fare'],
                      app.currency,
                      app.decimals,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool searched = false;
  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        items = [];
        searched = false;
      });
      return;
    }
    setState(() => loading = true);
    final point = appController.browseCoords;
    final result = await appController.api.products(
      latitude: point.latitude,
      longitude: point.longitude,
      filters: {'search': q, 'limit': 20, 'offset': 0},
    );
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      searched = true;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: appController.t('search'),
            border: InputBorder.none,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : !searched
          ? EmptyState(icon: Icons.search, message: appController.t('search'))
          : items.isEmpty
          ? EmptyState(message: appController.t('no_search_results'))
          : ListView(
              children: items
                  .map(
                    (item) => ListTile(
                      leading: SizedBox(
                        width: 48,
                        child: AppImage(
                          J.str(item['image_url']),
                          placeholder: appController.placeholder,
                        ),
                      ),
                      title: Text(J.str(item['name'])),
                      onTap: () => context.push(
                        '/product/${item['slug'] ?? item['id']}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class CmsScreen extends StatefulWidget {
  const CmsScreen({super.key, required this.title, required this.settingKey});
  final String title;
  final String settingKey;

  @override
  State<CmsScreen> createState() => _CmsScreenState();
}

class _CmsScreenState extends State<CmsScreen> {
  String html = '';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final content = await appController.cmsHtml(widget.settingKey);
      if (!mounted) return;
      setState(() {
        html = content;
        loading = false;
        if (content.trim().isEmpty) error = appController.t('no_content_yet');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = appController.t('network_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: Text(appController.t('retry')),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HtmlText(html),
            ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.seller,
    required this.onTap,
    this.distance,
    this.rating,
    required this.productCount,
  });

  final Map<String, dynamic> seller;
  final VoidCallback onTap;
  final double? distance;
  final double? rating;
  final String productCount;

  @override
  Widget build(BuildContext context) {
    final app = appController;
    final name = J.str(seller['store_name'] ?? seller['name']);
    final hasDelivery = J.flag(seller['delivery']) ||
        J.str(seller['delivery_type']).isNotEmpty;

    return Material(
      color: AppTheme.backgroundWhite,
      elevation: 2,
      shadowColor: AppTheme.primaryNavy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: AppImage(
                    J.str(seller['logo_url']),
                    placeholder: app.placeholder,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (rating != null && rating! > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppTheme.accentOrange,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '$productCount ${app.t('products')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (hasDelivery)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrange
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.delivery_dining,
                                  size: 12,
                                  color: AppTheme.accentOrange,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  app.t('delivery') == 'delivery'
                                      ? 'توصيل'
                                      : app.t('delivery'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.accentOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (distance != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.near_me,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${distance!.toStringAsFixed(1)} كم',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CityPickerSheet extends StatelessWidget {
  const CityPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return ListView(
      children: app.cities
          .map(
            (city) => ListTile(
              title: Text(J.str(city['name'])),
              selected: '${app.city?['id']}' == '${city['id']}',
              onTap: () {
                app.selectCity(normalizeCity(city));
                Navigator.pop(context);
              },
            ),
          )
          .toList(),
    );
  }
}
