import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/auth/clerk_auth_holder.dart";
import "../../core/providers/app_providers.dart";

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(authSyncProvider);
    final signedIn = ClerkAuthHolder.isSignedIn;

    final status = sync.when(
      data: (p) {
        if (!signedIn) return "Redirecting to login…";
        if (p == null) return "Account not linked — opening invite screen…";
        return "Opening app…";
      },
      loading: () => signedIn ? "Syncing with API…" : "Loading Clerk session…",
      error: (e, _) => "Sync error: $e",
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
              if (sync.isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(status, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                "API: check 127.0.0.1:3000 · Clerk key via --dart-define",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (signedIn && !sync.isLoading && sync.valueOrNull == null) ...[
                const SizedBox(height: 16),
                const Text(
                  "If this stays: backend 403/401 or clerkId mismatch.\n"
                  "See pending-invite or Nest logs.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.orange),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
