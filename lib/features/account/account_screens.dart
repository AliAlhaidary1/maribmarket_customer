import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/city_mode.dart';
import '../../core/json_util.dart';
import '../../core/promo_price.dart';
import '../../widgets/app_image.dart';
import '../../core/app_theme.dart';
import '../../widgets/order_tracker.dart';
import '../../widgets/ui_helpers.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FilledButton(
            onPressed: () => context.push('/login'),
            child: Text(app.t('login')),
          ),
          const SizedBox(height: 16),
          _cmsTile(
            context,
            Icons.privacy_tip_outlined,
            app.t('privacy_policy'),
            '/privacy',
          ),
          _cmsTile(
            context,
            Icons.article_outlined,
            app.t('terms_of_service'),
            '/terms',
          ),
          _cmsTile(context, Icons.info_outline, app.t('about_us'), '/about'),
          _cmsTile(
            context,
            Icons.mail_outline,
            app.t('contact_us'),
            '/contact',
          ),
          _cmsTile(
            context,
            Icons.chat_bubble_outline,
            app.t('assistant_title'),
            '/assistant',
          ),
        ],
      );
    }
    final name = J.str(app.user?['name']);
    final mobile = J.str(app.user?['mobile']);
    return ListView(
      children: [
        const SizedBox(height: 12),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: app.accentColor,
            child: Text(name.isEmpty ? 'م' : name.substring(0, 1)),
          ),
          title: Text(name),
          subtitle: Text(mobile),
        ),
        _tile(context, Icons.receipt_long, app.t('orders'), '/orders'),
        _tile(context, Icons.favorite, app.t('wishlist'), '/wishlist'),
        _tile(context, Icons.location_on, app.t('myAddress'), '/addresses'),
        _tile(
          context,
          Icons.notifications,
          app.t('notification'),
          '/notifications',
        ),
        _tile(
          context,
          Icons.account_balance_wallet,
          app.t('wallet'),
          '/wallet',
        ),
        _tile(
          context,
          Icons.swap_horiz,
          app.t('transactions'),
          '/transactions',
        ),
        _tile(context, Icons.campaign, 'حراج', '/haraj/mine'),
        if (app.akhdimniEnabled)
          _tile(context, Icons.delivery_dining, 'أخدمني', '/akhdimni/orders'),
        _tile(context, Icons.person, app.t('editProfile'), '/profile'),
        const Divider(),
        _cmsTile(
          context,
          Icons.privacy_tip_outlined,
          app.t('privacy_policy'),
          '/privacy',
        ),
        _cmsTile(
          context,
          Icons.article_outlined,
          app.t('terms_of_service'),
          '/terms',
        ),
        _cmsTile(context, Icons.info_outline, app.t('about_us'), '/about'),
        _cmsTile(context, Icons.mail_outline, app.t('contact_us'), '/contact'),
        _cmsTile(
          context,
          Icons.chat_bubble_outline,
          app.t('assistant_title'),
          '/assistant',
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(app.i18n.code == 'ar' ? 'English' : 'العربية'),
          onTap: () => app.setLanguage(app.i18n.code == 'ar' ? 'en' : 'ar'),
        ),
        if (kDebugMode)
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('عنوان الخادم'),
            subtitle: Text(app.apiUrl),
            onTap: () async {
              final controller = TextEditingController(text: app.apiUrl);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('API URL'),
                  content: TextField(controller: controller),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(app.t('cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(app.t('save_info')),
                    ),
                  ],
                ),
              );
              if (ok == true) await app.setApiUrl(controller.text);
            },
          ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(app.t('logout')),
          onTap: () async {
            final ok = await confirmAction(
              context,
              title: app.t('logout'),
              body: app.t('logout_confirm'),
            );
            if (!ok || !context.mounted) return;
            await app.logout();
            if (context.mounted) context.go('/');
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: Text(app.t('delete_account')),
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String path) {
    return ListTile(
      leading: Icon(icon, color: appController.accentColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => context.push(path),
    );
  }

  Widget _cmsTile(
    BuildContext context,
    IconData icon,
    String title,
    String path,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => context.push(path),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final app = appController;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('delete_account')),
        content: Text(app.t('delete_user_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(app.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(app.t('delete_account')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await app.deleteAccount();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.go('/');
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final tab = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> active = [];
  List<Map<String, dynamic>> previous = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!appController.isLoggedIn) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final a = await appController.api.orders(type: 1, limit: 30);
    final p = await appController.api.orders(type: 0, limit: 30);
    if (!mounted) return;
    setState(() {
      active = a.dataMaps;
      previous = p.dataMaps;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(app.t('orders'))),
        body: const LoginRequired(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(app.t('orders')),
        bottom: TabBar(
          controller: tab,
          tabs: [
            Tab(text: app.t('all_orders')),
            Tab(text: app.t('status')),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: tab,
              children: [_list(active), _list(previous)],
            ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return Center(child: Text(appController.t('no_order')));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final order = items[i];
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('${appController.t('id')}${order['id']}'),
          subtitle: Text(
            '${order['status_name'] ?? order['active_status']} • ${money(order['final_total'], appController.currency, appController.decimals)}',
          ),
          onTap: () => context.push('/orders/${order['id']}'),
        );
      },
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.id});
  final String id;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? order;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await appController.api.orders(orderId: widget.id);
    if (!mounted) return;
    setState(() {
      order = result.dataMaps.isNotEmpty
          ? result.dataMaps.first
          : result.dataMap;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text('${app.t('order')} ${widget.id}')),
        body: const LoginRequired(),
      );
    }
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (order == null || order!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${app.t('order')} ${widget.id}')),
        body: EmptyState(
          message: app.t('no_order'),
          actionLabel: app.t('retry'),
          onAction: () {
            setState(() => loading = true);
            _load();
          },
        ),
      );
    }
    final items = J.maps(order?['items'] ?? order?['order_items']);
    return Scaffold(
      appBar: AppBar(title: Text('${app.t('order')} ${widget.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OrderTracker(
            status: J.str(order?['active_status'] ?? order?['status'] ?? ''),
            statusLabel: J.str(
              order?['status_name'] ?? order?['active_status'],
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => ListTile(
              title: Text(J.str(item['product_name'] ?? item['name'])),
              subtitle: Text('x${item['quantity']}'),
              trailing: Text(
                money(
                  item['sub_total'] ?? item['price'],
                  app.currency,
                  app.decimals,
                ),
              ),
            ),
          ),
          const Divider(),
          Text(
            money(order?['final_total'], app.currency, app.decimals),
            style: const TextStyle(
              color: AppTheme.accentOrange,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    appController.loadAddresses();
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(app.t('myAddress'))),
        body: const LoginRequired(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(app.t('myAddress'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          if (app.addresses.isEmpty) {
            return EmptyState(
              icon: Icons.location_on_outlined,
              message: app.t('new_address'),
              actionLabel: app.t('new_address'),
              onAction: _edit,
            );
          }
          return ListView(
            children: app.addresses
                .map(
                  (address) => RadioListTile(
                    value: '${address['id']}',
                    groupValue: '${app.selectedAddress?['id']}',
                    title: Text(J.str(address['type'] ?? address['name'])),
                    subtitle: Text(J.str(address['address'])),
                    onChanged: (_) {
                      app.selectAddress(address);
                      final next = cityFromAddress(address, app.cities);
                      if (next != null) app.selectCity(next);
                    },
                    secondary: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: app.t('delete_address_confirm'),
                        );
                        if (!ok) return;
                        await app.api.deleteAddress(address['id']);
                        await app.loadAddresses();
                      },
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _edit() async {
    final app = appController;
    final name = TextEditingController(text: J.str(app.user?['name']));
    final mobile = TextEditingController(text: J.str(app.user?['mobile']));
    final address = TextEditingController();
    final city = app.city;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('new_address')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: app.t('Name')),
            ),
            TextField(
              controller: mobile,
              decoration: InputDecoration(labelText: app.t('mobile')),
            ),
            TextField(
              controller: address,
              decoration: InputDecoration(labelText: app.t('address')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(app.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(app.t('save_info')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (address.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(app.t('fill_required_fields'))));
      return;
    }
    await app.api.addAddress({
      'name': name.text,
      'mobile': mobile.text,
      'type': 'Home',
      'address': address.text.trim(),
      'landmark': '',
      'area': J.str(city?['name']),
      'pincode': '',
      'city': J.str(city?['name']),
      'city_id': city?['id'],
      'state': J.str(city?['state']),
      'country': 'Yemen',
      'latitude': city?['latitude'],
      'longitude': city?['longitude'],
      'is_default': app.addresses.isEmpty ? 1 : 0,
    });
    await app.loadAddresses();
  }
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
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
    final point = appController.coords ?? (latitude: 0.0, longitude: 0.0);
    final result = await appController.api.favorites(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Scaffold(
      appBar: AppBar(title: Text(app.t('wishlist'))),
      body: !app.isLoggedIn
          ? const LoginRequired()
          : loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border,
              message: app.t('wishlist'),
              actionLabel: app.t('shop_now'),
              onAction: () => context.go('/products'),
            )
          : ListView(
              children: items
                  .map(
                    (item) => ListTile(
                      leading: SizedBox(
                        width: 56,
                        child: AppImage(
                          J.str(item['image_url']),
                          placeholder: app.placeholder,
                        ),
                      ),
                      title: Text(J.str(item['name'])),
                      onTap: () => context.push(
                        '/product/${item['slug'] ?? item['id']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await app.toggleFavorite(
                            item['id'] ?? item['product_id'],
                          );
                          if (mounted) _load();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class SimpleListScreen extends StatefulWidget {
  const SimpleListScreen({
    super.key,
    required this.title,
    required this.loader,
  });
  final String title;
  final Future<List<Map<String, dynamic>>> Function() loader;

  @override
  State<SimpleListScreen> createState() => _SimpleListScreenState();
}

class _SimpleListScreenState extends State<SimpleListScreen> {
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
    try {
      final value = await widget.loader();
      if (!mounted) return;
      setState(() {
        items = value;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: !app.isLoggedIn
          ? const LoginRequired()
          : loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? EmptyState(message: app.t('no_notifications'))
          : ListView(
              children: items
                  .map(
                    (item) => ListTile(
                      title: Text(
                        J.str(
                          item['title'] ??
                              item['message'] ??
                              item['txn_id'] ??
                              item['id'],
                        ),
                      ),
                      subtitle: Text(
                        J.str(
                          item['date'] ?? item['created_at'] ?? item['type'],
                        ),
                      ),
                      trailing: Text(
                        J.str(item['amount'] ?? item['latest_message'] ?? ''),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final name = TextEditingController(
    text: J.str(appController.user?['name']),
  );
  late final email = TextEditingController(
    text: J.str(appController.user?['email']),
  );

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(app.t('editProfile'))),
        body: const LoginRequired(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(app.t('editProfile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: app.t('Name')),
          ),
          TextField(
            controller: email,
            decoration: InputDecoration(labelText: app.t('email')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final result = await app.api.editProfile(
                name: name.text,
                email: email.text,
              );
              if (result.ok) {
                await app.reloadSettings();
                final me = await app.api.userDetails();
                if (me.ok)
                  app.setUser(me.user.isNotEmpty ? me.user : me.dataMap);
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.message.isEmpty ? app.t('update') : result.message,
                  ),
                ),
              );
            },
            child: Text(app.t('update')),
          ),
        ],
      ),
    );
  }
}
