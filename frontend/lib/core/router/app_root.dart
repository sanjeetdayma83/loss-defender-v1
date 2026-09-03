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
    if (!Env.hasClerkKey) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "CLERK_PUBLISHABLE_KEY missing or placeholder.\n\n"
                "flutter run -d chrome \\\n"
                "  --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1 \\\n"
                "  --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...",
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
        child: _ClerkBootstrapGate(
          child: ClerkAuthBuilder(
            signedInBuilder: (context, authState) =>
                _RoutedApp(authState: authState),
            signedOutBuilder: (context, authState) =>
                _RoutedApp(authState: authState),
          ),
        ),
      ),
    );
  }
}

/// Agar Clerk 12s me ready nahi → error UI (white spinner forever nahi)
class _ClerkBootstrapGate extends StatefulWidget {
  const _ClerkBootstrapGate({required this.child});
  final Widget child;

  @override
  State<_ClerkBootstrapGate> createState() => _ClerkBootstrapGateState();
}

class _ClerkBootstrapGateState extends State<_ClerkBootstrapGate> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 12), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ClerkAuthBuilder jab ready hota hai child paint hota hai.
    // Timeout ke baad bhi sirf spinner ho to message dikhao.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_timedOut)
          ColoredBox(
            color: Colors.white,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      "Clerk failed to initialize",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Key prefix: ${Env.clerkPublishableKey.length >= 12 ? Env.clerkPublishableKey.substring(0, 12) : Env.clerkPublishableKey}…\n"
                      "Check: valid pk_test, network to *.clerk.accounts.dev,\n"
                      "Chrome Console errors, disable adblock on localhost.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "API_BASE_URL=${Env.apiBaseUrl}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
