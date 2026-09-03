import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/business_hours.dart';
import '../../core/json_util.dart';
import '../../core/promo_price.dart';
import '../../widgets/app_image.dart';
import '../../widgets/ui_helpers.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    await appController.refreshCart();
    if (mounted) setState(() => loading = false);
  }

  List<Map<String, dynamic>> get lines => appController.isLoggedIn
      ? appController.cartProducts
      : appController.guestCart;

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (loading) return const Center(child: CircularProgressIndicator());
    if (lines.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        message: app.t('empty_cart'),
        actionLabel: app.t('shop_now'),
        onAction: () => context.go('/products'),
      );
    }
    final total = app.isLoggedIn ? app.cartSubTotal : app.guestCartTotal;
    // multi-seller info if available
    final groups = app.sellerGroups;
    return Column(
      children: [
        if (groups.isNotEmpty)
          Container(
            color: Colors.orange.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Text('${groups.length} متاجر', style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Text('الحد ${app.checkoutConfig.maxSellersPerCheckout}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final item = lines[i];
              final qty = J.i(item['qty'] ?? item['quantity'], 1);
              final name = J.str(item['name'] ?? item['product_name']);
              final image = J.str(item['image_url'] ?? item['image']);
              final price = variantDisplayPrice(item);
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: AppImage(image, placeholder: app.placeholder),
                ),
                title: Text(name, maxLines: 2),
                subtitle: Text(
                  money(price.finalPrice, app.currency, app.decimals),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: qty <= 1
                          ? () => app
                                .removeCartLine(
                                  productId: item['product_id'] ?? item['id'],
                                  variantId:
                                      item['product_variant_id'] ?? item['id'],
                                )
                                .then((_) {
                                  if (mounted) setState(() {});
                                })
                          : () => app
                                .addToCart(
                                  productId: item['product_id'] ?? item['id'],
                                  variantId:
                                      item['product_variant_id'] ?? item['id'],
                                  qty: qty - 1,
                                  sellerId:
                                      item['seller_id'] ?? J.sellerId(item),
                                )
                                .then((_) {
                                  if (mounted) setState(() {});
                                }),
                    ),
                    Text('$qty'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => app
                          .addToCart(
                            productId: item['product_id'] ?? item['id'],
                            variantId: item['product_variant_id'] ?? item['id'],
                            qty: qty + 1,
                            sellerId: item['seller_id'] ?? J.sellerId(item),
                          )
                          .then((_) {
                            if (mounted) setState(() {});
                          }),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 8,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(app.t('sub_total')),
                      const Spacer(),
                      Text(
                        money(total, app.currency, app.decimals),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () {
                      if (!app.isLoggedIn) {
                        context.push('/login');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(app.t('please_login_continue')),
                          ),
                        );
                        return;
                      }
                      // stock / seller limit guard like front
                      if (app.sellerGroups.length > app.checkoutConfig.maxSellersPerCheckout) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('الحد الأقصى ${app.checkoutConfig.maxSellersPerCheckout} متاجر للطلب الواحد')),
                        );
                        return;
                      }
                      context.push('/checkout');
                    },
                    child: Text(app.t('checkout')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Map<String, dynamic>? checkout;
  String method = 'COD';
  bool walletUsed = false;
  bool placing = false;
  final note = TextEditingController();
  final promo = TextEditingController();
  String? deliveryTime; // "D-M-YYYY title" like front
  DateTime? selectedDay;
  String? selectedSlot;
  bool loadingCheckout = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    note.dispose();
    promo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loadingCheckout = true);
    final result = await appController.refreshCart(checkout: 1);
    // also load multi seller if needed
    if (appController.sellerGroups.length > 1) {
      await appController.loadMultiSellerCheckout();
    }
    if (!mounted) return;
    setState(() {
      checkout = result.dataMap.isNotEmpty ? result.dataMap : appController.cart;
      loadingCheckout = false;
    });
  }

  bool _methodOn(String key) =>
      J.str(appController.paymentSettings[key]) == '1';

  bool _paymentConfigured() => appController.paymentSettings.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(app.t('checkout'))),
        body: const LoginRequired(),
      );
    }
    if (loadingCheckout) return Scaffold(appBar: AppBar(title: Text(app.t('checkout'))), body: const Center(child: CircularProgressIndicator()));
    final items = J.maps(
      checkout?['cart'] ?? checkout?['items'] ?? app.cartProducts,
    );
    final subTotal = J.d(checkout?['sub_total'] ?? app.cartSubTotal);
    final delivery = J.d(checkout?['delivery_charge'] ?? checkout?['delivery_fee'] ?? app.multiSellerCheckout?.deliveryTotal);
    final discount = J.d(
      app.promoCode?['discount'] ?? checkout?['promo_discount'],
    );
    var finalTotal = J.d(
      checkout?['final_total'] ?? checkout?['total'],
      subTotal + delivery - discount,
    );
    final wallet = J.d(
      app.user?['balance'] ??
          app.user?['wallet'] ??
          app.settings['user_balance'],
    );
    if (walletUsed) {
      finalTotal = (finalTotal - wallet).clamp(0, double.infinity);
      if (finalTotal == 0) method = 'Wallet';
    }
    final codAllowed = J.flag(checkout?['cod_allowed'] ?? 1);
    final address = app.selectedAddress;
    final bh = app.businessHours;
    final canPlace = app.canPlaceOrder();
    final sellerGroups = app.sellerGroups;
    final deliveryFees = app.deliveryFees;

    return Scaffold(
      appBar: AppBar(title: Text(app.t('checkout'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Business hours banner parity with front BusinessHoursBanner
          if (bh != null && !canPlace.allowed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    canPlace.reason == 'platform'
                        ? buildMarketplaceClosedMessage(canPlace.status)
                        : buildSellerClosedMessage(canPlace.status, ''),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  )),
                ],
              ),
            ),
          if (bh != null && !canPlace.allowed) const SizedBox(height: 12),
          // seller groups like front
          if (sellerGroups.isNotEmpty)
            ...sellerGroups.map((g) => Card(
              child: ListTile(
                leading: const Icon(Icons.store),
                title: Text(J.str(g['store_name'] ?? g['seller_id'])),
                subtitle: Text('${J.maps(g['items']).length} منتجات'),
                trailing: Text(money(deliveryFees['${g['seller_id']}']?['amount'] ?? 0, app.currency, app.decimals)),
              ),
            )),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(app.t('deliver_to')),
            subtitle: Text(
              address == null
                  ? app.t('new_address')
                  : J.str(address['address'] ?? address['formatted_address']),
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () async {
              await context.push('/addresses');
              setState(() {});
              await _load();
            },
          ),
          const SizedBox(height: 12),
          // time slots picker like front Checkout.js
          if (app.timeSlots.isNotEmpty) ...[
            Text('وقت التوصيل', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final day = DateTime.now().add(Duration(days: idx));
                  final isSel = selectedDay != null && selectedDay!.day == day.day && selectedDay!.month == day.month;
                  return ChoiceChip(
                    label: Text('${day.day}/${day.month}'),
                    selected: isSel,
                    onSelected: (_) => setState(() {
                      selectedDay = day;
                      // rebuild deliveryTime
                      if (selectedSlot != null) deliveryTime = '${day.day}-${day.month}-${day.year} $selectedSlot';
                    }),
                  );
                },
              ),
            ),
            Wrap(
              spacing: 8,
              children: app.timeSlots.map((s) => ChoiceChip(
                label: Text(s.title),
                selected: selectedSlot == s.title,
                onSelected: (_) => setState(() {
                  selectedSlot = s.title;
                  if (selectedDay != null) deliveryTime = '${selectedDay!.day}-${selectedDay!.month}-${selectedDay!.year} $s.title';
                  else deliveryTime = s.title;
                }),
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
          ...items.map(
            (item) => ListTile(
              title: Text(J.str(item['name'] ?? item['product_name'])),
              trailing: Text('x${item['qty'] ?? item['quantity']}'),
            ),
          ),
          const Divider(),
          _row(app.t('sub_total'), money(subTotal, app.currency, app.decimals)),
          _row('التوصيل', money(delivery, app.currency, app.decimals)),
          if (app.platformFee > 0) _row('رسوم المنصة', money(app.platformFee, app.currency, app.decimals)),
          if (discount > 0)
            _row(
              app.t('discount'),
              '- ${money(discount, app.currency, app.decimals)}',
            ),
          _row(
            app.t('total'),
            money(finalTotal, app.currency, app.decimals),
            bold: true,
          ),
          const SizedBox(height: 12),
          if (wallet > 0)
            SwitchListTile(
              title: Text(
                '${app.t('wallet')} (${money(wallet, app.currency, app.decimals)})',
              ),
              value: walletUsed,
              onChanged: (v) => setState(() => walletUsed = v),
            ),
          // Payment methods parity with front (9 gateways)
          if (codAllowed &&
              (_methodOn('cod_payment_method') || !_paymentConfigured()))
            RadioListTile(
              title: const Text('الدفع عند الاستلام'),
              value: 'COD',
              groupValue: method,
              onChanged: walletUsed && finalTotal == 0
                  ? null
                  : (v) => setState(() => method = '$v'),
            ),
          if (_methodOn('wallet_payment_method') || walletUsed)
            RadioListTile(
              title: Text(app.t('wallet')),
              value: 'Wallet',
              groupValue: method,
              onChanged: (v) => setState(() => method = '$v'),
            ),
          if (_methodOn('stripe_payment_method') || _methodOn('stripe'))
            RadioListTile(title: const Text('Stripe'), value: 'Stripe', groupValue: method, onChanged: (v) => setState(() => method = '$v')),
          if (_methodOn('paypal_payment_method') || _methodOn('paypal'))
            RadioListTile(title: const Text('PayPal'), value: 'Paypal', groupValue: method, onChanged: (v) => setState(() => method = '$v')),
          if (_methodOn('paystack_payment_method') || _methodOn('paystack'))
            RadioListTile(title: const Text('Paystack'), value: 'Paystack', groupValue: method, onChanged: (v) => setState(() => method = '$v')),
          if (_methodOn('razorpay_payment_method') || _methodOn('razorpay'))
            RadioListTile(title: const Text('Razorpay'), value: 'Razorpay', groupValue: method, onChanged: (v) => setState(() => method = '$v')),
          if (_methodOn('cashfree_payment_method'))
            RadioListTile(title: const Text('Cashfree'), value: 'Cashfree', groupValue: method, onChanged: (v) => setState(() => method = '$v')),
          if (_methodOn('midtrans_payment_method'))
            RadioListTile(title: const Text('Midtrans'), value: 'Midtrans', groupValue: method, onChanged: (v) => setState(() => method = '$v')),
          if (_methodOn('phonepe_payment_method'))
            RadioListTile(title: const Text('PhonePe'), value: 'Phonepe', groupValue: method, onChanged: (v) => setState(() => method = '$v')),
          TextField(
            controller: promo,
            decoration: InputDecoration(
              labelText: app.t('promo_code'),
              suffixIcon: TextButton(
                onPressed: () async {
                  final error = await app.applyPromo(
                    promo.text.trim(),
                    subTotal,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error ?? app.t('apply'))),
                  );
                  setState(() {});
                },
                child: Text(app.t('apply')),
              ),
            ),
          ),
          TextField(
            controller: note,
            decoration: InputDecoration(labelText: 'ملاحظة الطلب'),
          ),
          if (deliveryTime != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('وقت التوصيل: $deliveryTime', style: const TextStyle(fontSize: 12, color: Colors.grey))),
          const SizedBox(height: 16),
          if (address == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                app.t('add_address_first'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (!canPlace.allowed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                canPlace.reason == 'platform' ? buildMarketplaceClosedMessage(canPlace.status) : buildSellerClosedMessage(canPlace.status, ''),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          FilledButton(
            onPressed: placing || !canPlace.allowed
                ? null
                : () {
                    if (address == null) {
                      context.push('/addresses');
                      return;
                    }
                    _placeOrder(
                      app,
                      items,
                      subTotal,
                      delivery,
                      finalTotal,
                      wallet,
                      address,
                    );
                  },
            child: placing
                ? const BusySpinner()
                : Text(
                    address == null
                        ? app.t('add_address_first')
                        : _isGateway(method) ? 'ادفع عبر $method' : app.t('place_order'),
                  ),
          ),
        ],
      ),
    );
  }

  bool _isGateway(String m) => ['Stripe','Paypal','Paystack','Razorpay','Cashfree','Midtrans','Phonepe'].contains(m);

  Future<void> _placeOrder(
    AppController app,
    List<Map<String, dynamic>> items,
    double subTotal,
    double delivery,
    double finalTotal,
    double wallet,
    Map<String, dynamic> address,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('confirm_order')),
        content: Text('${money(finalTotal, app.currency, app.decimals)}\n${deliveryTime ?? ''}\n$method'),
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
    setState(() => placing = true);
    final idempotencyKey = app.buildIdempotencyKey();
    final payMethod = (walletUsed && finalTotal == 0) ? 'Wallet' : method;
    // try multi-seller first if groups >1 like front placeMultiSellerOrder
    ApiResult result;
    if (app.sellerGroups.length > 1) {
      result = await app.api.placeMultiSellerOrder({
        'address_id': address['id'],
        'payment_method': payMethod,
        'use_wallet': walletUsed ? '1' : '0',
        if (deliveryTime != null && deliveryTime!.isNotEmpty) 'delivery_time': deliveryTime,
        if (note.text.trim().isNotEmpty) 'order_note': note.text.trim(),
        if (app.promoCode != null) 'promocode_id': app.promoCode?['id'] ?? app.promoCode?['promo_code_id'],
        'idempotency_key': idempotencyKey,
        'latitude': address['latitude'] ?? app.browseCoords.latitude,
        'longitude': address['longitude'] ?? app.browseCoords.longitude,
      });
    } else {
      result = await app.api.checkout(
        addressId: address['id'],
        paymentMethod: payMethod,
        useWallet: walletUsed,
        promocodeId: app.promoCode?['id'] ?? app.promoCode?['promo_code_id'],
        deliveryTime: deliveryTime ?? 'N/A',
        orderNote: note.text.trim(),
        idempotencyKey: idempotencyKey,
      );
    }
    if (!mounted) return;
    if (!result.ok) {
      setState(() => placing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    // gateway handling like front initiate_transaction
    if (_isGateway(payMethod)) {
      final checkoutGroupId = result.dataMap['checkout_group_id'] ?? result.dataMap['id'] ?? result.dataMap['group_id'];
      if (checkoutGroupId != null) {
        final init = await app.api.initiateTransactionForCheckoutGroup(checkoutGroupId: checkoutGroupId, paymentMethod: payMethod);
        if (!mounted) return;
        if (!init.ok) {
          setState(() => placing = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(init.message)));
          return;
        }
        // front would open StripeModal/Paypal redirect etc. Here we show success with transaction url
        final data = init.dataMap;
        final url = data['url'] ?? data['redirect_url'] ?? data['snap_url'] ?? data['payment_url'];
        if (url != null && url.toString().isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('افتح رابط الدفع: $url')));
        }
      }
    }
    setState(() => placing = false);
    app.clearPromo();
    await app.refreshCart();
    if (!mounted) return;
    context.go('/orders');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('place_order'))));
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
