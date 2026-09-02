import "package:clerk_flutter/clerk_flutter.dart";
import "package:flutter/material.dart";

/// Sign-in + sign-up (Clerk toggles internally).
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.shield_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    "LOSS DEFENDER",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Sign in to your warehouse account",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  // Must get bounded height or Clerk UI can paint zero size
                  Expanded(
                    child: SingleChildScrollView(
                      child: ClerkErrorListener(
                        child: const ClerkAuthentication(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}