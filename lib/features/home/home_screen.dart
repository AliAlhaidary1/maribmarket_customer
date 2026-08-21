import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/app_theme.dart';
import '../../core/json_util.dart';
import '../../core/promo_price.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../more/more_screens.dart';
import '../products/categories_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> sliders = [];
  List<Map<String, dynamic>> flash = [];
  List<Map<String, dynamic>> haraj = [];
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String? loadError;
  String? _cityKey;

  @override
  void initState() {
    super.initState();
    appController.addListener(_onApp);
    _load();
  }

  @override
  void dispose() {
    appController.removeListener(_onApp);
    super.dispose();
  }

  void _onApp() {
    final key =
        '${appController.city?['id']}-${appController.city?['latitude']}';
    if (key != _cityKey) {
      _cityKey = key;
      _load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    final app = appController;
    _cityKey = '${app.city?['id']}-${app.city?['latitude']}';
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final point = app.browseCoords;
      final sliderRes = await app.api.sliders();
      final flashRes = await app.api.flashSales();
      final harajRes = await app.api.harajPosts({
        'page': 1,
        'per_page': 4,
        if (app.city?['id'] != null) 'city_id': app.city!['id'],
      });
      if (app.rootCategories.isEmpty) {
        await app.loadRootCategories();
      }
      final sections = J.maps(app.shop?['sections']);
      final sectionProducts = sections
          .expand((section) => J.maps(section['products']))
          .toList();
      List<Map<String, dynamic>> extra = [];
      if (sectionProducts.isEmpty) {
        final productRes = await app.api.products(
          latitude: point.latitude,
          longitude: point.longitude,
          filters: {'limit': 20, 'offset': 0},
        );
        extra = productRes.dataMaps;
      }
      if (!mounted) return;
      setState(() {
        sliders = sliderRes.dataMaps.isNotEmpty
            ? sliderRes.dataMaps
            : J.maps(app.shop?['sliders']);
        flash = flashRes.dataMaps;
        haraj = harajRes.dataMaps;
        products = extra;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = '$error';
      });
    }
  }

  void _openOffer(Map<String, dynamic> item) {
    final type = J.str(item['type']);
    if (type == 'category' || item['category'] != null) {
      final category = J.map(item['category']);
      if (category.isNotEmpty) {
        openCategory(context, category);
        return;
      }
      context.push('/sellers?type=${item['type_id']}');
      return;
    }
    final slug = J.str(item['product']?['slug']);
    if (type == 'product' || slug.isNotEmpty) {
      if (slug.isNotEmpty) context.push('/product/$slug');
    }
  }

  List<Map<String, dynamic>> _offers(String position) {
    return J
        .maps(appController.shop?['offers'])
        .where((o) => J.str(o['position']) == position)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    final categories = J.maps(app.shop?['categories']).isNotEmpty
        ? J.maps(app.shop?['categories'])
        : app.rootCategories;
    final sellers = J.maps(app.shop?['sellers']);
    final sections = J.maps(app.shop?['sections']);
    final topOffers = _offers('top');
    final belowSlider = _offers('below_slider');
    final belowCategory = _offers('below_category');
    final hasContent =
        topOffers.isNotEmpty ||
        sliders.isNotEmpty ||
        categories.isNotEmpty ||
        flash.isNotEmpty ||
        sellers.isNotEmpty ||
        haraj.isNotEmpty ||
        sections.isNotEmpty ||
        products.isNotEmpty ||
        app.akhdimniEnabled;

    return RefreshIndicator(
      onRefresh: () async {
        await app.loadShop();
        await app.loadRootCategories();
        await _load();
      },
      child: CustomScrollView(
        slivers: [
          if (app.city == null)
            SliverToBoxAdapter(
              child: ListTile(
                leading: Icon(Icons.location_on, color: app.accentColor),
                title: Text(app.t('choose_city_to_browse')),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => const CityPickerSheet(),
                ),
              ),
            ),
          if (loadError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      app.t('network_error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _load, child: Text(app.t('retry'))),
                  ],
                ),
              ),
            ),
          if (loading && !hasContent)
            const SliverToBoxAdapter(child: HomeLoadingSkeleton()),
          if (topOffers.isNotEmpty) _bannerPage(topOffers, 140),
          if (sliders.isNotEmpty) _bannerPage(sliders, 170),
          if (belowSlider.isNotEmpty) _bannerPage(belowSlider, 140),
          if (categories.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                app.t('shop_by_store_type'),
                onSeeAll: () => context.push('/sellers'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 118,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    return GestureDetector(
                      onTap: () => openCategory(context, cat),
                      child: SizedBox(
                        width: 90,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: AppTheme.surfaceGrey,
                              child: ClipOval(
                                child: AppImage(
                                  J.str(cat['image_url'] ?? cat['image']),
                                  placeholder: app.placeholder,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              J.str(cat['name']),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          if (flash.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                app.t('flash_sale') == 'flash_sale'
                    ? 'عروض فلاش'
                    : app.t('flash_sale'),
                onSeeAll: () => context.push('/offers'),
              ),
            ),
            _productStrip(
              flash
                  .map((item) => J.map(item['product'] ?? item))
                  .where((p) => p.isNotEmpty)
                  .toList(),
            ),
          ],
          if (belowCategory.isNotEmpty) _bannerPage(belowCategory, 140),
          if (sellers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                app.t('sellers'),
                onSeeAll: () => context.push('/sellers'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: sellers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final seller = sellers[i];
                    return GestureDetector(
                      onTap: () {
                        final slug = J.str(seller['slug']);
                        context.push(
                          slug.isNotEmpty
                              ? '/store/$slug'
                              : '/seller/${seller['id']}',
                        );
                      },
                      child: SizedBox(
                        width: 92,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppTheme.surfaceGrey,
                              child: ClipOval(
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: AppImage(
                                    J.str(seller['logo_url']),
                                    placeholder: app.placeholder,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              J.str(seller['store_name'] ?? seller['name']),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          if (haraj.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                app.t('haraj') == 'haraj' ? 'حراج' : app.t('haraj'),
                onSeeAll: () => context.push('/haraj'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: haraj.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final post = haraj[i];
                    return GestureDetector(
                      onTap: () => context.push('/haraj/${post['id']}'),
                      child: SizedBox(
                        width: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppImage(
                                  J.str(post['image_url'] ?? post['thumbnail']),
                                  placeholder: app.placeholder,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              J.str(post['title']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              money(post['price'], app.currency, app.decimals),
                              style: TextStyle(
                                color: app.accentColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          if (app.akhdimniEnabled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  tileColor: app.accentColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Icon(Icons.delivery_dining, color: app.accentColor),
                  title: const Text('أخدمني'),
                  subtitle: const Text(
                    'اطلب خدمة من نقطة إلى نقطة أو أغراض خاصة',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/akhdimni'),
                ),
              ),
            ),
          for (final section in sections)
            if (J.maps(section['products']).isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                _sectionTitle(section),
                onSeeAll: () {
                  final type = J.str(section['product_type']);
                  if (type == 'for_you' || type == 'recently_viewed') {
                    context.push('/products');
                  } else {
                    context.push('/products?section=${section['id']}');
                  }
                },
              ),
            ),
            _productStrip(J.maps(section['products'])),
          ],
          if (products.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                app.t('products'),
                onSeeAll: () => context.push('/products'),
              ),
            ),
            _productGrid(products.take(8).toList()),
          ],
          if (!loading && !hasContent)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 64,
                        color: app.accentColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        app.t('no_products_found'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'تأكد من المدينة وعنوان الخادم، ثم اسحب للتحديث.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: Text(
                          app.t('retry') == 'retry'
                              ? 'إعادة المحاولة'
                              : app.t('retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  String _sectionTitle(Map<String, dynamic> section) {
    final type = J.str(section['product_type']);
    if (type == 'for_you') return appController.t('for_you');
    if (type == 'recently_viewed') return appController.t('recently_viewed');
    return J.str(section['title'] ?? section['short_description']);
  }

  Widget _bannerPage(List<Map<String, dynamic>> items, double height) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: height,
        child: PageView(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: GestureDetector(
                    onTap: () => _openOffer(item),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AppImage(
                        J.str(item['image_url'] ?? item['image']),
                        placeholder: appController.placeholder,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _productStrip(List<Map<String, dynamic>> items) {
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 250,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(
            width: 160,
            child: ProductCard(
              product: items[i],
              onTap: () => _openProduct(items[i]),
              onAdd: () => _quickAdd(items[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _productGrid(List<Map<String, dynamic>> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ProductCard(
            product: items[i],
            onTap: () => _openProduct(items[i]),
            onAdd: () => _quickAdd(items[i]),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  void _openProduct(Map<String, dynamic> product) {
    final slug = J.str(product['slug']);
    context.push(
      slug.isNotEmpty
          ? '/product/$slug'
          : '/product/${product['id']}?id=${product['id']}',
    );
  }

  Future<void> _quickAdd(Map<String, dynamic> product) async {
    final variants = J.maps(product['variants']);
    final variant = variants.isNotEmpty ? variants.first : product;
    final price = variantDisplayPrice(variant);
    final error = await appController.addToCart(
      productId: product['id'],
      variantId: variant['id'] ?? product['product_variant_id'],
      qty: 1,
      productPrice: price.finalPrice,
      sellerId: J.sellerId(product),
    );
    if (!mounted) return;
    if (error == 'same_seller') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appController.t('Oops')),
          content: const Text(
            'السلة تقبل منتجات بائع واحد فقط. هل تريد إفراغ السلة وإضافة هذا المنتج؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(appController.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(appController.t('confirm')),
            ),
          ],
        ),
      );
      if (ok == true) {
        await appController.addToCart(
          productId: product['id'],
          variantId: variant['id'] ?? product['product_variant_id'],
          qty: 1,
          productPrice: price.finalPrice,
          sellerId: J.sellerId(product),
          replaceSeller: true,
        );
      }
    } else if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appController.t('add_to_cart'))));
    }
  }
}
