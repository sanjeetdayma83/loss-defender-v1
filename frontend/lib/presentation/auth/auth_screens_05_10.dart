import "package:flutter/material.dart";
import "../../core/theme/app_theme.dart";
import "../../core/widgets/auth_widgets.dart";

// ========== 05 FORGOT PASSWORD ==========
class ForgotPasswordScreen extends StatefulWidget {
  final Future<void> Function(String email) onSendLink;
  final VoidCallback onBackToSignIn;

  const ForgotPasswordScreen({
    super.key,
    required this.onSendLink,
    required this.onBackToSignIn,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSendLink(_email.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "Reset your password",
      sideSubtitle: "Get back to your account quickly and securely.",
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 16),
            const Icon(Icons.mail_lock_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text("Forgot your password?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              "No worries! Enter your email and we'll send a link to reset your password.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_sent)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "If an account exists for that email, a reset link has been sent.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.success, fontSize: 13),
                ),
              )
            else ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email address",
                  prefixIcon: Icon(Icons.mail_outline, size: 20),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? "Sending…" : "Send Reset Link"),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onBackToSignIn,
              child: const Text("← Back to sign in"),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 06 RESET PASSWORD ==========
class ResetPasswordScreen extends StatefulWidget {
  final Future<void> Function(String password) onReset;
  final VoidCallback onBackToSignIn;

  const ResetPasswordScreen({
    super.key,
    required this.onReset,
    required this.onBackToSignIn,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _len => _pass.text.length >= 8;
  bool get _num => RegExp(r"[0-9]").hasMatch(_pass.text);
  bool get _special => RegExp(r"[^A-Za-z0-9]").hasMatch(_pass.text);

  Future<void> _submit() async {
    if (_pass.text != _confirm.text) {
      setState(() => _error = "Passwords do not match");
      return;
    }
    if (!_len || !_num || !_special) {
      setState(() => _error = "Password does not meet requirements");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onReset(_pass.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _rule(bool ok, String text) => Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.circle_outlined,
              size: 16, color: ok ? AppColors.success : AppColors.muted),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12, color: ok ? AppColors.success : AppColors.muted)),
        ],
      );

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "Stronger password security",
      sideSubtitle: "A strong password keeps your account and business data safe.",
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 16),
            const Icon(Icons.lock_reset, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text("Create a new password",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              "Your new password must be different from previous passwords.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pass,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "New password",
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm new password",
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            _rule(_len, "At least 8 characters"),
            _rule(_num, "Include a number"),
            _rule(_special, "Include a special character"),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? "Saving…" : "Reset Password"),
            ),
            TextButton(
              onPressed: widget.onBackToSignIn,
              child: const Text("← Back to sign in"),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 07 ACCEPT INVITE ==========
class AcceptInviteScreen extends StatefulWidget {
  final String inviterName;
  final String companyName;
  final String role;
  final String? message;
  final Future<void> Function() onAccept;
  final VoidCallback onDecline;

  const AcceptInviteScreen({
    super.key,
    required this.inviterName,
    required this.companyName,
    required this.role,
    this.message,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "You're invited",
      sideSubtitle: "Join your team on Loss Defender.",
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 16),
            const Text("You're invited!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              "${widget.inviterName} has invited you to join ${widget.companyName} on Loss Defender.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _infoTile(Icons.business, "Company", widget.companyName),
            _infoTile(Icons.badge_outlined, "Role", widget.role),
            if (widget.message != null && widget.message!.isNotEmpty)
              _infoTile(Icons.chat_bubble_outline, "Message", widget.message!),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _accept,
              child: Text(_busy ? "Accepting…" : "Accept Invitation"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : widget.onDecline,
              child: const Text("Decline"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 08 PENDING / NO COMPANY ==========
class PendingInviteScreen extends StatelessWidget {
  final VoidCallback onContactAdmin;
  final VoidCallback onSignOut;

  const PendingInviteScreen({
    super.key,
    required this.onContactAdmin,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "Almost there",
      sideSubtitle: "Your account needs a company association.",
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 16),
            const Icon(Icons.mark_email_unread_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text("No Company Access",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              "You don't have a company associated with your account yet.\n"
              "Please contact your administrator or accept an invitation to get started.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onContactAdmin,
              child: const Text("Contact Admin"),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onSignOut, child: const Text("Sign out")),
          ],
        ),
      ),
    );
  }
}

// ========== 09 REGISTER COMPANY ==========
class RegisterCompanyScreen extends StatefulWidget {
  final Future<void> Function({
    required String companyName,
    required String industry,
    required String country,
    required String companySize,
  }) onCreate;
  final VoidCallback onSignIn;

  const RegisterCompanyScreen({
    super.key,
    required this.onCreate,
    required this.onSignIn,
  });

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _name = TextEditingController();
  String _industry = "E-commerce / Retail";
  String _country = "India";
  String _size = "1-10 people";
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "Company name required");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCreate(
        companyName: _name.text.trim(),
        industry: _industry,
        country: _country,
        companySize: _size,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      sideTitle: "Start Your Journey",
      sideSubtitle: "Set up your company and start protecting orders with video evidence.",
      sideBullets: const [
        "Quick setup",
        "Secure and scalable",
        "Invite your team",
        "Start packing with confidence",
      ],
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 16),
            const Text("Register your company",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: "Company name",
                prefixIcon: Icon(Icons.business, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _industry,
              decoration: const InputDecoration(labelText: "Industry"),
              items: const [
                "E-commerce / Retail",
                "3PL / Logistics",
                "Manufacturing",
                "Other",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _industry = v ?? _industry),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _country,
              decoration: const InputDecoration(labelText: "Country"),
              items: const ["India", "UAE", "USA", "Other"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _country = v ?? _country),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _size,
              decoration: const InputDecoration(labelText: "Company size"),
              items: const ["1-10 people", "11-50 people", "51-200 people", "200+ people"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _size = v ?? _size),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? "Creating…" : "Create Company"),
            ),
            const SizedBox(height: 12),
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

// ========== 10 ONBOARDING ==========
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSkip;

  const OnboardingScreen({
    super.key,
    required this.onGetStarted,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.home_work_outlined, "Add Warehouse", "Set up your warehouse location."),
      (Icons.group_add_outlined, "Invite Your Team", "Add operators and staff."),
      (Icons.settings_outlined, "Configure Settings", "Set your preferences."),
      (Icons.inventory_2_outlined, "Start Packing", "Begin recording and securing your orders."),
    ];

    return AuthScaffold(
      darkSide: false,
      sideTitle: "Welcome to Loss Defender!",
      sideSubtitle: "Let's get you set up in a few simple steps.",
      form: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 36)),
            const SizedBox(height: 12),
            const Text("Welcome to Loss Defender!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text("Let's get you set up in a few simple steps.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 20),
            ...List.generate(steps.length, (i) {
              final s = steps[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(s.$1, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${i + 1}. ${s.$2}",
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(s.$3, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onGetStarted,
              child: const Text("Get Started →"),
            ),
            TextButton(onPressed: onSkip, child: const Text("Skip for now")),
          ],
        ),
      ),
    );
  }
}