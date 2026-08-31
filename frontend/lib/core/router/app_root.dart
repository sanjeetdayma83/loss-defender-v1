import "package:clerk_flutter/clerk_flutter.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../config/env.dart";
import "../auth/clerk_auth_holder.dart";
import "app_router.dart";

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // Fail loudly instead of hanging silently on a blank "processing" screen.
    if (Env.clerkPublishableKey.isEmpty) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "CLERK_PUBLISHABLE_KEY is missing.\n\n"
                "Run with:\n"
                "flutter run -d chrome "
                "--dart-define=API_BASE_URL=http://localhost:3000/api/v1 "
                "--dart-define=CLERK_PUBLISHABLE_KEY=pk_test_xxx",
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: Env.clerkPublishableKey),
      child: ClerkErrorListener(
        child: ClerkAuthBuilder(
          signedInBuilder: (context, authState) => _RoutedApp(authState: authState),
          signedOutBuilder: (context, authState) => _RoutedApp(authState: authState),
        ),
      ),
    );
  }
}

class _RoutedApp extends ConsumerStatefulWidget {
  final ClerkAuthState authState;
  const _RoutedApp({required this.authState});

  @override
  ConsumerState<_RoutedApp> createState() => _RoutedAppState();
}

class _RoutedAppState extends ConsumerState<_RoutedApp> {
  late final router = buildRouter(ref, widget.authState);

  @override
  void initState() {
    super.initState();
    ClerkAuthHolder.instance = widget.authState;
  }

  @override
  void didUpdateWidget(covariant _RoutedApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    ClerkAuthHolder.instance = widget.authState;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "LOSS DEFENDER V1",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}