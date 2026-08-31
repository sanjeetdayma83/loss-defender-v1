import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:clerk_flutter/clerk_flutter.dart";
import "config/env.dart";
import "core/router/app_router.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LossDefenderApp()));
}

class LossDefenderApp extends ConsumerWidget {
  const LossDefenderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final app = MaterialApp.router(
      title: "LOSS DEFENDER V1",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );

    // clerk_flutter uses path_provider — not reliable on web
    if (kIsWeb || !Env.hasClerkKey) return app;

    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: Env.clerkPublishableKey),
      child: app,
    );
  }
}