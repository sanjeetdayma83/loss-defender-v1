import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../config/env.dart";
import "../../core/auth/clerk_auth_holder.dart";
import "../../core/auth/clerk_js_bridge.dart";
import "../../core/providers/app_providers.dart";

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _isSignUp = false;
  bool _need2fa = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _finish(String jwt) async {
    ClerkAuthHolder.setManualToken(jwt);
    ref.read(authRefreshProvider).ping();
    ref.invalidate(authSyncProvider);
    if (mounted) context.go("/splash");
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!Env.hasClerkKey) {
        throw Exception("Pass CLERK_PUBLISHABLE_KEY via --dart-define");
      }
      final email = _email.text.trim();
      final password = _password.text;
      if (email.isEmpty || password.isEmpty) {
        throw Exception("Email and password required");
      }

      if (!kIsWeb) {
        throw Exception("Native path: use Windows/Android build with clerk_auth");
      }

      final jwt = _isSignUp
          ? await ClerkJsBridge.signUpWithPassword(
              email: email, password: password)
          : await ClerkJsBridge.signInWithPassword(
              email: email, password: password);
      await _finish(jwt);
    } catch (e) {
      final msg = e.toString().replaceAll("Exception: ", "");
      if (msg.startsWith("NEED_2FA:")) {
        setState(() {
          _need2fa = true;
          _error = msg.replaceFirst("NEED_2FA:", "");
          _busy = false;
        });
        return;
      }
      setState(() {
        _error = msg;
        _busy = false;
      });
    }
  }

  Future<void> _submit2fa() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final jwt = await ClerkJsBridge.completeSecondFactor(_code.text.trim());
      await _finish(jwt);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    "LOSS DEFENDER",
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _need2fa
                        ? "Enter verification code"
                        : (_isSignUp
                            ? "Create your account"
                            : "Sign in to your warehouse account"),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 28),
                  if (!_need2fa) ...[
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                  ] else ...[
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Verification code",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin),
                      ),
                      onSubmitted: (_) => _busy ? null : _submit2fa(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : (_need2fa ? _submit2fa : _submit),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _busy
                            ? "Please wait…"
                            : (_need2fa
                                ? "Verify"
                                : (_isSignUp ? "Sign up" : "Sign in")),
                      ),
                    ),
                  ),
                  if (!_need2fa)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                      child: Text(
                        _isSignUp
                            ? "Already have an account? Sign in"
                            : "Need an account? Sign up",
                      ),
                    ),
                  if (_need2fa)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _need2fa = false;
                                _error = null;
                              }),
                      child: const Text("Back"),
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