import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/config.dart';
import '../../core/json_util.dart';
import '../../core/promo_price.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui_helpers.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    this.categoryId,
    this.sellerId,
    this.search,
    this.hasOffer = false,
    this.sectionId,
    this.sellerSectionId,
  });

  final String? categoryId;
  final String? sellerId;
  final String? search;
  final bool hasOffer;
  final String? sectionId;
  final String? sellerSectionId;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  int offset = 0;
  String sort = '';
  String? categoryId;
  bool inStock = false;
  bool onlyOffers = false;

  @override
  void initState() {
    super.initState();
    categoryId = widget.categoryId;
    onlyOffers = widget.hasOffer;
    _search.text = widget.search ?? '';
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _filters => {
    'limit': AppConfig.productPageSize,
    'offset': offset,
    if (categoryId != null && categoryId!.isNotEmpty)
      'category_ids': categoryId,
    if (widget.sellerId != null) 'seller_id': widget.sellerId,
    if (widget.sectionId != null && widget.sectionId!.isNotEmpty)
      'section_id': widget.sectionId,
    if (widget.sellerSectionId != null && widget.sellerSectionId!.isNotEmpty)
      'seller_section_id': widget.sellerSectionId,
    if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    if (sort.isNotEmpty) 'sort': sort,
    if (inStock) 'in_stock': 1,
    if (widget.hasOffer || onlyOffers) 'has_offer': 1,
  };

  Future<void> _load({bool reset = false}) async {
    if (!reset && (loadingMore || !hasMore)) return;
    final point = appController.browseCoords;
    if (reset) {
      offset = 0;
      hasMore = true;
      setState(() => loading = true);
    } else {
      setState(() => loadingMore = true);
    }
    final result = await appController.api.products(
      latitude: point.latitude,
      longitude: point.longitude,
      filters: _filters,
    );
    final next = result.dataMaps;
    if (!mounted) return;
    setState(() {
      items = reset ? next : [...items, ...next];
      offset = items.length;
      hasMore = next.length >= AppConfig.productPageSize;
      loading = false;
      loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(reset: true),
                  decoration: InputDecoration(
                    hintText: app.t('search'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(onPressed: _openFilters, icon: const Icon(Icons.tune)),
            ],
          ),
        ),
        if (app.rootCategories.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: app.rootCategories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  final selected = categoryId == null || categoryId!.isEmpty;
                  return ChoiceChip(
                    label: Text(app.t('all') == 'all' ? 'الكل' : app.t('all')),
                    selected: selected,
                    onSelected: (_) {
                      categoryId = null;
                      _load(reset: true);
                    },
                  );
                }
                final cat = app.rootCategories[i - 1];
                final selected = '${cat['id']}' == '$categoryId';
                return ChoiceChip(
                  label: Text(J.str(cat['name'])),
                  selected: selected,
                  onSelected: (_) {
                    categoryId = selected ? null : '${cat['id']}';
                    _load(reset: true);
                  },
                );
              },
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? EmptyState(message: app.t('no_products_found'))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 240 &&
                        !loadingMore &&
                        hasMore) {
                      _load();
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                    itemCount: items.length + (loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= items.length)
                        return const Center(child: CircularProgressIndicator());
                      final product = items[i];
                      return ProductCard(
                        product: product,
                        onTap: () {
                          final slug = J.str(product['slug']);
                          context.push(
                            slug.isNotEmpty
                                ? '/product/$slug'
                                : '/product/${product['id']}',
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openFilters() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        var localSort = sort;
        var stock = inStock;
        var offer = onlyOffers;
        return StatefulBuilder(
          builder: (context, setModal) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appController.t('filters'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                RadioListTile(
                  title: Text(appController.t('low_to_high')),
                  value: 'low',
                  groupValue: localSort,
                  onChanged: (v) => setModal(() => localSort = v ?? ''),
                ),
                RadioListTile(
                  title: Text(appController.t('high_to_low')),
                  value: 'high',
                  groupValue: localSort,
                  onChanged: (v) => setModal(() => localSort = v ?? ''),
                ),
                RadioListTile(
                  title: Text(appController.t('newest_first')),
                  value: 'new',
                  groupValue: localSort,
                  onChanged: (v) => setModal(() => localSort = v ?? ''),
                ),
                SwitchListTile(
                  title: const Text('المتوفر فقط'),
                  value: stock,
                  onChanged: (v) => setModal(() => stock = v),
                ),
                SwitchListTile(
                  title: Text(appController.t('offers')),
                  value: offer,
                  onChanged: (v) => setModal(() => offer = v),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'sort': localSort,
                    'stock': stock,
                    'offer': offer,
                  }),
                  child: Text(appController.t('apply')),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      sort = selected['sort'] ?? '';
      inStock = selected['stock'] == true;
      onlyOffers = selected['offer'] == true;
      _load(reset: true);
    }
  }
}

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.slug});
  final String slug;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? product;
  Map<String, dynamic>? variant;
  int qty = 1;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final point = appController.browseCoords;
    final id = int.tryParse(widget.slug);
    final result = await appController.api.productById(
      latitude: point.latitude,
      longitude: point.longitude,
      id: id,
      slug: id == null ? widget.slug : '',
    );
    if (!result.ok) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = result.message;
      });
      return;
    }
    final data = result.dataMap.isNotEmpty
        ? result.dataMap
        : (result.dataMaps.isNotEmpty
              ? result.dataMaps.first
              : <String, dynamic>{});
    final variants = J.maps(data['variants']);
    if (!mounted) return;
    setState(() {
      product = data;
      variant = variants.isNotEmpty ? variants.first : data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (product == null || product!.isEmpty)
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline,
          message: error ?? app.t('Oops'),
          actionLabel: app.t('retry'),
          onAction: () {
            setState(() {
              loading = true;
              error = null;
            });
            _load();
          },
        ),
      );
    final price = variantDisplayPrice(variant);
    final variants = J.maps(product!['variants']);
    final stock = J.i(variant?['stock']);
    final unlimited = J.flag(
      product!['is_unlimited_stock'] ?? variant?['is_unlimited_stock'],
    );
    final maxQty = J.i(
      product!['total_allowed_quantity'],
      unlimited ? 99 : stock,
    );
    final images = [
      J.str(product!['image_url'] ?? product!['main_image']),
      ...J
          .list(product!['images'])
          .map((e) => J.str(e is Map ? e['image_url'] ?? e['image'] : e)),
    ].where((e) => e.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(J.str(product!['name']), maxLines: 1),
        actions: [
          if (app.isLoggedIn)
            IconButton(
              icon: Icon(
                app.isFavorite(product!['id'])
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              onPressed: () async {
                await app.toggleFavorite(product!['id']);
                setState(() {});
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 280,
            child: images.isEmpty
                ? AppImage('', placeholder: app.placeholder)
                : PageView(
                    children: images
                        .map(
                          (url) => AppImage(url, placeholder: app.placeholder),
                        )
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  J.str(product!['name']),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      money(price.finalPrice, app.currency, app.decimals),
                      style: TextStyle(
                        fontSize: 20,
                        color: app.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (price.hasDiscount)
                      Text(
                        money(price.original, app.currency, app.decimals),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    if (price.isFlash) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('فلاش'),
                        backgroundColor: Colors.red.shade50,
                      ),
                    ],
                  ],
                ),
                if (variants.length > 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: variants
                        .map(
                          (item) => ChoiceChip(
                            label: Text(
                              J.str(
                                item['measurement'] ??
                                    item['name'] ??
                                    item['id'],
                              ),
                            ),
                            selected: '${item['id']}' == '${variant?['id']}',
                            onSelected: (_) => setState(() => variant = item),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: qty > 1 ? () => setState(() => qty--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$qty',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: qty < (maxQty == 0 ? 99 : maxQty)
                          ? () => setState(() => qty++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const Spacer(),
                    if (!unlimited && stock <= 0)
                      Text(
                        app.t('out_of_stock'),
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                HtmlText(J.str(product!['description'])),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: (!unlimited && stock <= 0)
                ? null
                : () async {
                    final err = await app.addToCart(
                      productId: product!['id'],
                      variantId: variant?['id'],
                      qty: qty,
                      productPrice: price.finalPrice,
                      sellerId: J.sellerId(product),
                    );
                    if (!context.mounted) return;
                    if (err == 'same_seller') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          content: const Text(
                            'السلة تقبل منتجات بائع واحد فقط. إفراغ السلة؟',
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
                      if (ok == true) {
                        await app.addToCart(
                          productId: product!['id'],
                          variantId: variant?['id'],
                          qty: qty,
                          productPrice: price.finalPrice,
                          sellerId: J.sellerId(product),
                          replaceSeller: true,
                        );
                      }
                    } else if (err != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(app.t('add_to_cart'))),
                      );
                    }
                  },
            child: Text(app.t('add_to_cart')),
          ),
        ),
      ),
    );
  }
}
