import "package:flutter/material.dart";

/// Placeholder — wire Clerk Flutter SDK components here.
/// After sign-in: store session token, call GET /auth/sync, route by role.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("LOSS DEFENDER V1", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text("Sign in with Clerk (embed SDK next)"),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // TODO: Clerk sign-in → token → /auth/sync → dashboard
              },
              child: const Text("Sign in"),
            ),
          ],
        ),
      ),
    );
  }
}