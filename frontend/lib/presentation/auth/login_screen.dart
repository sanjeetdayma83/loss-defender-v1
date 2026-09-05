import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";
import "../../config/env.dart";
import "../../core/auth/session_provider.dart";
// agar session_provider nahi: apna auth applyToken / signInWithToken path use karo

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _tokenCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  // Clerk Dashboard → Configure → Account Portal → Sign-in URL
  // Example: https://cute-lobster-2676.accounts.dev/sign-in
  static const clerkSignInUrl = String.fromEnvironment(
    "CLERK_SIGN_IN_URL",
    defaultValue: "https://cute-lobster-2676.accounts.dev/sign-in",
  );
  static const clerkSignUpUrl = String.fromEnvironment(
    "CLERK_SIGN_UP_URL",
    defaultValue: "https://cute-lobster-2676.accounts.dev/sign-up",
  );

  Future<void> _open(String url) async {
    final u = Uri.parse(url);
    if (!await launchUrl(u, mode: LaunchMode.externalApplication)) {
      setState(() => _error = "Could not open $url");
    }
  }

  Future<void> _continueWithToken() async {
    setState(() { _busy = true; _error = null; });
    try {
      final err = await ref.read(sessionProvider.notifier).signInWithToken(_tokenCtrl.text);
      if (!mounted) return;
      if (err != null) {
        setState(() { _error = err; _busy = false; });
        return;
      }
      context.go("/dashboard");
    } catch (e) {
      setState(() { _error = e.toString(); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("LOSS DEFENDER V1",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    "Sign in with Clerk (hosted). Then paste session token once.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _open(clerkSignInUrl),
                    icon: const Icon(Icons.login),
                    label: const Text("Sign in (Clerk)"),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _open(clerkSignUpUrl),
                    icon: const Icon(Icons.person_add),
                    label: const Text("Sign up (Clerk)"),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _open("$clerkSignInUrl#/factor-password"),
                    child: const Text("Forgot password"),
                  ),
                  const Divider(height: 32),
                  const Text(
                    "After Clerk sign-in, open that tab Console:\n"
                    "await window.Clerk.session.getToken()\n"
                    "Paste JWT below:",
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Session JWT",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _continueWithToken,
                    child: Text(_busy ? "…" : "Continue to app"),
                  ),
                  if (!kIsWeb && Env.hasClerkKey)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        "Mobile: embedded Clerk UI available in next build.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
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