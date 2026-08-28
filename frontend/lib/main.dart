import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "core/router/app_router.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LossDefenderApp()));
}

class LossDefenderApp extends StatelessWidget {
  const LossDefenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter(isSignedIn: false);
    return MaterialApp.router(
      title: "LOSS DEFENDER V1",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}