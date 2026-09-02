import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  /// OAuth only when backend ready
  static const bool showOAuth = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.dio.post(
        '/auth/login',
        data: {
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
        },
      );

      final body = res.data;
      final data = body is Map && body['data'] != null ? body['data'] : body;
      final access = data['accessToken']?.toString();
      final refresh = data['refreshToken']?.toString();
      final user = data['user'];

      if (access == null || access.isEmpty) {
        throw Exception('No access token');
      }

      await TokenStorage.saveTokens(
        accessToken: access,
        refreshToken: refresh,
        userJson: user,
      );

      if (!mounted) return;
      context.go('/dashboard');
    } on DioException catch (e) {
      String msg = 'Login failed. Please try again.';
      final d = e.response?.data;
      if (d is Map) {
        msg = (d['message'] ?? d['error'] ?? msg).toString();
      } else if (e.response?.statusCode == 401) {
        msg = 'Invalid email or password';
      }
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (isWide) const Expanded(flex: 5, child: _LoginBrandPanel()),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isWide) ...[
                          const _AuthMobileLogo(),
                          const SizedBox(height: 28),
                        ],
                        const Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account to continue',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: 16),
                        ],
                        const _FieldLabel('Email Address'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: authInputDeco(
                            hint: 'Enter your email',
                            prefix: Icons.mail_outline,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: authInputDeco(
                            hint: 'Enter your password',
                            prefix: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    ],
                                  ),
                          ),
                        ),
                        if (showOAuth) ...[
                          const SizedBox(height: 24),
                          const _OrDivider(label: 'or continue with'),
                          const SizedBox(height: 16),
                          const _OAuthButton(label: 'Continue with Google', icon: Icons.g_mobiledata),
                          const SizedBox(height: 10),
                          const _OAuthButton(label: 'Continue with Microsoft', icon: Icons.window),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            GestureDetector(
                              onTap: () => context.push('/register'),
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1B3A), Color(0xFF0F2A5C)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandHeader(light: true),
          const Spacer(),
          const Text(
            'Every Shipment.\nEvery Scan.\nEvery Proof.',
            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: 16),
          Text(
            'AI-powered evidence and analytics\nto protect your business from losses,\ndisputes and chargebacks.',
            style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          _StatusPill(Icons.verified, 'Scan Verified', 'ORD-88942-XTQ'),
          const SizedBox(height: 10),
          _StatusPill(Icons.videocam, 'Evidence Recorded', '05 Aug 2026, 10:24 AM'),
          const SizedBox(height: 10),
          _StatusPill(Icons.cloud_done, 'Upload Complete', '24.5 MB'),
          const Spacer(),
          Row(
            children: [
              _FeatureIcon(Icons.shield_outlined, 'Tamper Proof\nEvidence'),
              const SizedBox(width: 24),
              _FeatureIcon(Icons.cloud_outlined, 'Secure Cloud\nStorage'),
              const SizedBox(width: 24),
              _FeatureIcon(Icons.analytics_outlined, 'Powerful\nAnalytics'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© 2026 Loss Defender Pro. All rights reserved.',
            style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _StatusPill(this.icon, this.title, this.sub);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF34D399), size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              Text(sub, style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureIcon(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11, height: 1.3),
        ),
      ],
    );
  }
}

// ─── Shared auth UI helpers ───────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  final bool light;
  const _BrandHeader({this.light = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shield, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOSS DEFENDER PRO',
              style: TextStyle(
                color: light ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              'Warehouse Intelligence Platform',
              style: TextStyle(
                color: light ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuthMobileLogo extends StatelessWidget {
  const _AuthMobileLogo();

  @override
  Widget build(BuildContext context) {
    return const _BrandHeader(light: false);
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  const _OAuthButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null, // disabled until OAuth ready
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade800),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

InputDecoration authInputDeco({
  required String hint,
  required IconData prefix,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    prefixIcon: Icon(prefix, size: 20, color: Colors.grey.shade500),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDC2626)),
    ),
  );
}