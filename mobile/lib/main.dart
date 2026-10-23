import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'auth/session.dart';
import 'config.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Hold the native launch screen until the app's own splash (which looks the
  // same, plus a loader) has drawn its first frame. That screen removes it.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final session = Session(const SecureTokenStore());

  final api = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    token: () => session.token,
    onUnauthorized: session.signOut,
  );

  runApp(DykbApp(session: session, api: api));
}

class DykbApp extends StatefulWidget {
  const DykbApp({super.key, required this.session, required this.api});

  final Session session;
  final ApiClient api;

  @override
  State<DykbApp> createState() => _DykbAppState();
}

class _DykbAppState extends State<DykbApp> {
  late final GoRouter _router = createRouter(widget.session);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.session),
        Provider.value(value: widget.api),
      ],
      child: MaterialApp.router(
        title: 'Do You Know Ball?',
        theme: buildTheme(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
