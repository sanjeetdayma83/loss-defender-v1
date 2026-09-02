import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth/clerk_auth_holder.dart";
import "../../core/providers/app_providers.dart";

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _status = "Starting…";

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 15), () {
      if (!mounted) return;
      setState(() => _status = "Taking too long — check API + Clerk key");
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(authSyncProvider);
    final signedIn = ClerkAuthHolder.isSignedIn;

    sync.when(
      data: (_) => _status = signedIn ? "Opening app…" : "Redirecting to login…",
      loading: () => _status = signedIn ? "Syncing account…" : "Loading session…",
      error: (e, _) => _status = "Sync error: $e",
    );

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                "LOSS DEFENDER",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await ClerkAuthHolder.signOut();
                  ref.invalidate(authSyncProvider);
                  if (context.mounted) context.go("/login");
                },
                child: const Text("Sign out / go to login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}