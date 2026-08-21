import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'core/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  GoRouter? router;
  final apiUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    apiUrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await appController.bootstrap();
    apiUrl.text = appController.apiUrl;
    if (!mounted) return;
    final failed =
        appController.bootstrapError != null && appController.cities.isEmpty;
    setState(() => router = failed ? null : buildRouter());
  }

  @override
  Widget build(BuildContext context) {
    if (router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('مجمع مأرب'),
                if (appController.bootstrapError != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      appController.bootstrapError!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (kDebugMode) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: apiUrl,
                        decoration: const InputDecoration(labelText: 'API URL'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: () async {
                      if (kDebugMode)
                        await appController.setApiUrl(apiUrl.text);
                      await _start();
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return MaribCustomerApp(router: router!);
  }
}
