import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'core/json_util.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/cart/cart_screens.dart';
import 'features/haraj/haraj_screens.dart';
import 'features/home/home_screen.dart';
import 'features/more/more_screens.dart';
import 'features/products/categories_screen.dart';
import 'features/products/products_screens.dart';
import 'widgets/ui_helpers.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: appController,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/product/:slug',
        builder: (_, state) =>
            ProductDetailsScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderDetailsScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/addresses', builder: (_, __) => const AddressesScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => SimpleListScreen(
          title: appController.t('notification'),
          loader: () async =>
              (await appController.api.notifications()).dataMaps,
        ),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, __) => SimpleListScreen(
          title: appController.t('wallet'),
          loader: () async =>
              (await appController.api.transactions(type: 'wallet')).dataMaps,
        ),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, __) => SimpleListScreen(
          title: appController.t('transactions'),
          loader: () async => (await appController.api.transactions()).dataMaps,
        ),
      ),
      GoRoute(
        path: '/sellers',
        builder: (_, state) => SellersScreen(
          typeId: state.uri.queryParameters['type'] ??
              state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: '/seller/:id',
        builder: (_, state) => SellerPageScreen(id: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/store/:slug',
        builder: (_, state) =>
            SellerPageScreen(slug: state.pathParameters['slug']),
      ),
      GoRoute(path: '/offers', builder: (_, __) => const OffersScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(
        path: '/category/:slug',
        builder: (_, state) =>
            CategoriesScreen(slug: state.pathParameters['slug'] ?? 'all'),
      ),
      GoRoute(
        path: '/akhdimni/orders/:id',
        builder: (_, state) =>
            AkhdimniOrderDetailsScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/haraj', builder: (_, __) => const HarajListScreen()),
      GoRoute(
        path: '/haraj/mine',
        builder: (_, __) => const HarajListScreen(mine: true),
      ),
      GoRoute(
        path: '/haraj/create',
        builder: (_, __) => const HarajCreateScreen(),
      ),
      GoRoute(
        path: '/haraj/:id',
        builder: (_, state) =>
            HarajDetailsScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/akhdimni',
        builder: (_, __) => const AkhdimniHomeScreen(),
      ),
      GoRoute(
        path: '/akhdimni/create',
        builder: (_, state) => AkhdimniCreateScreen(
          type: state.uri.queryParameters['type'] ?? 'point_to_point',
        ),
      ),
      GoRoute(
        path: '/akhdimni/orders',
        builder: (_, __) => const AkhdimniOrdersScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, __) => CmsScreen(
          title: appController.t('privacy_policy'),
          settingKey: 'privacy_policy',
        ),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, __) => CmsScreen(
          title: appController.t('terms_of_service'),
          settingKey: 'terms_conditions',
        ),
      ),
      GoRoute(
        path: '/about',
        builder: (_, __) => CmsScreen(
          title: appController.t('about_us'),
          settingKey: 'about_us',
        ),
      ),
      GoRoute(path: '/contact', builder: (_, __) => CmsScreen(
          title: appController.t('contact_us'),
          settingKey: 'contact_us',
        ),
      ),
      GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/products',
            builder: (_, state) => ProductsScreen(
              categoryId: state.uri.queryParameters['category'],
              search: state.uri.queryParameters['search'],
              hasOffer: state.uri.queryParameters['offer'] == '1',
              sectionId: state.uri.queryParameters['section'],
              sellerId: state.uri.queryParameters['seller'],
            ),
          ),
          GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
        ],
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  int get index {
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/cart')) return 2;
    if (location.startsWith('/account')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (app.maintenance) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.cloud_off_outlined,
          message: app.t('maintenance_message'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/brand/logo.webp',
            errorBuilder: (_, __, ___) => const Icon(Icons.storefront),
          ),
        ),
        title: Text(J.str(app.webSettings['site_title'], 'مجمع مأرب')),
        actions: [
          TextButton.icon(
            onPressed: app.cities.isEmpty
                ? null
                : () => showModalBottomSheet(
                    context: context,
                    builder: (_) => const CityPickerSheet(),
                  ),
            icon: const Icon(Icons.location_on_outlined, color: Colors.white),
            label: Text(
              J.str(app.city?['name'], app.t('city')),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: () => context.push('/sellers'),
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/offers'),
            icon: const Icon(Icons.local_offer_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/haraj'),
            icon: const Icon(Icons.campaign_outlined),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/products');
            case 2:
              context.go('/cart');
            case 3:
              context.go('/account');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: app.t('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: app.t('products'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: app.cartCount > 0,
              label: Text('${app.cartCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: app.t('cart'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: app.t('my_account'),
          ),
        ],
      ),
    );
  }
}

class MaribCustomerApp extends StatelessWidget {
  const MaribCustomerApp({super.key, required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appController,
      builder: (context, _) {
        final color = appController.brandColor;
        return MaterialApp.router(
          title: J.str(appController.webSettings['site_title'], 'مجمع مأرب'),
          debugShowCheckedModeBanner: false,
          locale: appController.i18n.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: appController.i18n.direction,
            child: child ?? const SizedBox.shrink(),
          ),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: color, primary: color),
            scaffoldBackgroundColor: const Color(0xFFF3F5F7),
            appBarTheme: AppBarTheme(
              backgroundColor: color,
              foregroundColor: Colors.white,
              centerTitle: true,
            ),
            navigationBarTheme: NavigationBarThemeData(
              indicatorColor: color.withValues(alpha: 0.18),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected))
                  return IconThemeData(color: color);
                return const IconThemeData();
              }),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
