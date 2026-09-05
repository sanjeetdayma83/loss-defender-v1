import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../../core/theme/app_theme.dart";
import "../../core/widgets/auth_widgets.dart";

// ========== 01 SPLASH ==========
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1F3A), Color(0xFF1E3A5F), Color(0xFF2563EB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(light: true, size: 48),
              const SizedBox(height: 24),
              const Text(
                "Record Today. Defend Tomorrow.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Secure packing. Verified evidence. Stronger business.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== 02 SIGN IN ==========
class SignInScreen extends StatefulWidget {
  final Future<void> Function(String email, String password) onSignIn;
  final VoidCallback onForgot;
  final VoidCallback onSignUp;
  final Future<void> Function()? onGoogle;
  final Future<void> Function()? onMicrosoft;

  const SignInScreen({
    super.key,
    required this.onSignIn,
    required this.onForgot,
    required this.onSignUp,
    this.onGoogle,
    this.onMicrosoft,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignIn(_email.text.trim(), _password.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "Secure packing.\nVerified evidence.",
      sideSubtitle: "Trusted by e-commerce sellers across India.",
      sideBullets: const [
        "Video evidence for every order",
        "Reduce false claims",
        "Multi-warehouse ready",
      ],
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 20),
            const Text("Sign in to your account",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text("Welcome back! Please sign in to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email address",
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onSubmitted: (_) => _busy ? null : _submit(),
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: widget.onForgot, child: const Text("Forgot password?")),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? "Signing in…" : "Sign In"),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("or continue with", style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 22),
              label: const Text("Sign in with Google"),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.onMicrosoft,
              icon: const Icon(Icons.grid_view, size: 18),
              label: const Text("Sign in with Microsoft"),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? ", style: TextStyle(color: AppColors.muted)),
                GestureDetector(
                  onTap: widget.onSignUp,
                  child: const Text("Sign up",
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 03 SIGN UP ==========
class SignUpScreen extends StatefulWidget {
  final Future<void> Function({
    required String name,
    required String email,
    required String password,
  }) onSignUp;
  final VoidCallback onSignIn;

  const SignUpScreen({super.key, required this.onSignUp, required this.onSignIn});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _terms = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_terms) {
      setState(() => _error = "Accept Terms & Privacy Policy");
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = "Passwords do not match");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "Join thousands of businesses",
      sideSubtitle: "Protect orders with video evidence.",
      sideBullets: const [
        "Secure your business",
        "Reduce false claims",
        "Build customer trust",
      ],
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 16),
            const Text("Create your account",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: "Full name",
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email address",
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm password",
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v ?? false),
                ),
                const Expanded(
                  child: Text("I agree to the Terms of Service and Privacy Policy",
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              ],
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? "Creating…" : "Create Account"),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? ", style: TextStyle(color: AppColors.muted)),
                GestureDetector(
                  onTap: widget.onSignIn,
                  child: const Text("Sign in",
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 04 VERIFICATION / 2FA ==========
class VerificationScreen extends StatefulWidget {
  final String email;
  final Future<void> Function(String code) onVerify;
  final Future<void> Function()? onResend;
  final VoidCallback? onDifferentMethod;

  const VerificationScreen({
    super.key,
    required this.email,
    required this.onVerify,
    this.onResend,
    this.onDifferentMethod,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _digits = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  bool _busy = false;
  String? _error;
  int _seconds = 24;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_seconds > 0) {
        setState(() => _seconds--);
        _tick();
      }
    });
  }

  String get _code => _digits.map((c) => c.text).join();

  Future<void> _submit() async {
    if (_code.length != 6) {
      setState(() => _error = "Enter 6-digit code");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onVerify(_code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "Keep your account secure",
      sideSubtitle: "Two-factor authentication helps protect your business data.",
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 16),
            const Text("Enter verification code",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text("We've sent a 6-digit code to\n${widget.email}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 44,
                  child: TextField(
                    controller: _digits[i],
                    focusNode: _focus[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: ""),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) _focus[i + 1].requestFocus();
                      if (v.isEmpty && i > 0) _focus[i - 1].requestFocus();
                      if (i == 5 && v.isNotEmpty) _submit();
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Text(
              _seconds > 0 ? "Resend in 00:${_seconds.toString().padLeft(2, '0')}" : "Didn't receive the code?",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (_seconds == 0)
              TextButton(
                onPressed: widget.onResend == null
                    ? null
                    : () async {
                        await widget.onResend!();
                        setState(() => _seconds = 30);
                        _tick();
                      },
                child: const Text("Resend code"),
              ),
            if (_error != null)
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? "Verifying…" : "Verify Code"),
            ),
            if (widget.onDifferentMethod != null)
              TextButton(
                onPressed: widget.onDifferentMethod,
                child: const Text("Try a different method"),
              ),
          ],
        ),
      ),
    );
  }
}