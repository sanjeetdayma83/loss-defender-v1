import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth/session_provider.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _tokenCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    final err = await ref.read(sessionProvider.notifier).signInWithToken(_tokenCtrl.text);
    if (!mounted) return;
    setState(() { _busy = false; _error = err; });
    if (err == null) context.go("/dashboard");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("LOSS DEFENDER V1", textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text("Paste Clerk session JWT (dev). Production: embedded Clerk UI.",
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _tokenCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Clerk session token",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? "Signing in..." : "Continue"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}