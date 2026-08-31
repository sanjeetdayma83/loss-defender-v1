import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../config/env.dart";
import "../../core/auth/session_provider.dart";
import "clerk_auth_gate.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _tokenCtrl = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showTokenFallback = kIsWeb;

  Future<void> _submitToken() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err =
        await ref.read(sessionProvider.notifier).signInWithToken(_tokenCtrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) context.go("/dashboard");
  }

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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "LOSS DEFENDER V1",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Env.hasClerkKey
                        ? "Sign in with Clerk"
                        : "Set CLERK_PUBLISHABLE_KEY or paste session JWT",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (Env.hasClerkKey && !_showTokenFallback)
                    Expanded(
                      child: ClerkAuthGate(
                        onSessionToken: (token, clerkUserId) async {
                          final err = await ref
                              .read(sessionProvider.notifier)
                              .applyToken(token, clerkUserId: clerkUserId);
                          if (!mounted) return;
                          if (err != null) {
                            setState(() => _error = err);
                          } else {
                            context.go("/dashboard");
                          }
                        },
                      ),
                    ),
                  if (_showTokenFallback || !Env.hasClerkKey) ...[
                    TextField(
                      controller: _tokenCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Clerk session JWT",
                        border: OutlineInputBorder(),
                        helperText:
                            "Browser: await window.Clerk.session.getToken()",
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _submitToken,
                      child: Text(_busy ? "Signing in..." : "Continue with token"),
                    ),
                  ],
                  if (Env.hasClerkKey)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showTokenFallback = !_showTokenFallback),
                      child: Text(
                        _showTokenFallback
                            ? "Use Clerk sign-in form"
                            : "Use JWT paste instead",
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