import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:clerk_flutter/clerk_flutter.dart";
import "../../config/env.dart";
import "../../core/auth/session_provider.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _linkError;
  bool _linking = false;

  Future<void> _linkBackend(ClerkAuthState authState) async {
    if (_linking) return;
    setState(() {
      _linking = true;
      _linkError = null;
    });
    try {
      final sessionToken = await authState.sessionToken();
      final jwt = sessionToken.jwt;
      final err = await ref.read(sessionProvider.notifier).applyToken(
            jwt,
            clerkUserId: authState.user?.id,
          );
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _linkError = err;
          _linking = false;
        });
        return;
      }
      context.go("/dashboard");
    } catch (e) {
      if (mounted) {
        setState(() {
          _linkError = e.toString();
          _linking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.hasClerkKey) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Set CLERK_PUBLISHABLE_KEY.\n\n"
              "Either edit lib/config/env.dart defaultValue, or run:\n"
              "flutter run -d chrome --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_xxx",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "LOSS DEFENDER V1",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text("Sign in or create account"),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClerkErrorListener(
                      child: ClerkAuthBuilder(
                        signedOutBuilder: (context, authState) {
                          // Full Clerk UI: sign-in, sign-up, forgot password flows
                          return const SingleChildScrollView(
                            child: ClerkAuthentication(),
                          );
                        },
                        signedInBuilder: (context, authState) {
                          // Auto-link Nest user via /auth/sync
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _linkBackend(authState);
                          });
                          if (_linkError != null) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_linkError!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                const Text(
                                  "If account is not invited, ask admin to invite your email first.",
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () async {
                                    await authState.signOut();
                                    setState(() {
                                      _linkError = null;
                                      _linking = false;
                                    });
                                  },
                                  child: const Text("Sign out & try again"),
                                ),
                              ],
                            );
                          }
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text("Connecting to LOSS DEFENDER..."),
                            ],
                          );
                        },
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