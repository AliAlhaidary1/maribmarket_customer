import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
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
    return Column(
      children: [
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
    final result = await appController.refreshCart(checkout: 1);
    if (!mounted) return;
    setState(() => checkout = result.dataMap);
  }

  bool _methodOn(String key) =>
      J.str(appController.paymentSettings[key]) == '1';

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(app.t('checkout'))),
        body: const LoginRequired(),
      );
    }
    final items = J.maps(
      checkout?['cart'] ?? checkout?['items'] ?? app.cartProducts,
    );
    final subTotal = J.d(checkout?['sub_total'] ?? app.cartSubTotal);
    final delivery = J.d(checkout?['delivery_charge']);
    final discount = J.d(
      app.promoCode?['discount'] ?? checkout?['promo_discount'],
    );
    var finalTotal = J.d(
      checkout?['final_total'],
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

    return Scaffold(
      appBar: AppBar(title: Text(app.t('checkout'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          ...items.map(
            (item) => ListTile(
              title: Text(J.str(item['name'] ?? item['product_name'])),
              trailing: Text('x${item['qty'] ?? item['quantity']}'),
            ),
          ),
          const Divider(),
          _row(app.t('sub_total'), money(subTotal, app.currency, app.decimals)),
          _row(app.t('amount'), money(delivery, app.currency, app.decimals)),
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
            decoration: InputDecoration(labelText: app.t('order')),
          ),
          const SizedBox(height: 16),
          if (address == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                app.t('add_address_first'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          FilledButton(
            onPressed: placing
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
                        : app.t('place_order'),
                  ),
          ),
        ],
      ),
    );
  }

  bool _paymentConfigured() {
    final pay = appController.paymentSettings;
    return pay.isNotEmpty;
  }

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
        content: Text(money(finalTotal, app.currency, app.decimals)),
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
    final variantIds = items
        .map((e) => '${e['product_variant_id'] ?? e['id']}')
        .join(',');
    final qtys = items.map((e) => '${e['qty'] ?? e['quantity']}').join(',');
    final payMethod = (walletUsed && finalTotal == 0) ? 'Wallet' : method;
    final result = await app.api.placeOrder({
      'product_variant_id': variantIds,
      'quantity': qtys,
      'total': subTotal,
      'delivery_charge': delivery,
      'final_total': finalTotal,
      'payment_method': payMethod,
      'address_id': address['id'],
      'delivery_time': 'N/A',
      if (note.text.trim().isNotEmpty) 'order_note': note.text.trim(),
      if (walletUsed) 'wallet_used': 1,
      if (walletUsed) 'wallet_balance': wallet,
      if (app.promoCode != null)
        'promocode_id': app.promoCode?['id'] ?? app.promoCode?['promo_code_id'],
      'status': (payMethod == 'COD' || payMethod == 'Wallet') ? 2 : 1,
    });
    if (!mounted) return;
    setState(() => placing = false);
    if (!result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    app.clearPromo();
    await app.refreshCart();
    if (!mounted) return;
    context.go('/orders');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(app.t('place_order'))));
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
