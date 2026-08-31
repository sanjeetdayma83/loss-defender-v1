import "package:clerk_flutter/clerk_flutter.dart";
import "package:flutter/material.dart";

/// One screen handles BOTH sign-in and sign-up — ClerkAuthentication renders
/// its own internal toggle ("Don't have an account? Sign up").
/// Both /login and /signup routes point here.
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    "LOSS DEFENDER",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Sign in to your warehouse account",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  // Official Clerk widget — owns the entire sign-in/sign-up
                  // flow (email/password, OTP/MFA if enabled, etc.)
                  const ClerkAuthentication(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}