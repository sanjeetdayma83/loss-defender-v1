import "package:dio/dio.dart";
import "package:clerk_flutter/clerk_flutter.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/auth/clerk_auth_holder.dart";
import "../../core/network/api_client.dart";
import "../../core/providers/app_providers.dart";

class PendingInviteScreen extends ConsumerStatefulWidget {
  const PendingInviteScreen({super.key});

  @override
  ConsumerState<PendingInviteScreen> createState() => _PendingInviteScreenState();
}

class _PendingInviteScreenState extends ConsumerState<PendingInviteScreen> {
  final _tokenCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _ok;
  int _tab = 0; // 0 = create company, 1 = accept invite

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _companyCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<(String clerkId, String email)> _clerkIdentity() async {
    final auth = ClerkAuthHolder.instance;
    if (auth == null) throw Exception("Clerk not ready — sign in again");
    String? clerkId;
    String? email;
    try {
      final dynamic u = (auth as dynamic).user;
      clerkId = u?.id?.toString();
      email = u?.primaryEmailAddress?.emailAddress?.toString() ??
          u?.emailAddresses?.first?.emailAddress?.toString() ??
          u?.email?.toString();
    } catch (_) {}
    if (clerkId == null || clerkId.isEmpty) {
      throw Exception("Could not read Clerk user id");
    }
    if (email == null || email.isEmpty) {
      throw Exception("Could not read email from Clerk");
    }
    return (clerkId, email);
  }

  Future<void> _createCompany() async {
    setState(() { _loading = true; _error = null; _ok = null; });
    try {
      final (_, email) = await _clerkIdentity();
      final companyName = _companyCtrl.text.trim();
      final ownerName = _nameCtrl.text.trim();
      if (companyName.length < 2) throw Exception("Company name required");
      if (ownerName.length < 2) throw Exception("Your name required");

      final token = await ClerkAuthHolder.getToken();
      if (token == null || token.isEmpty) throw Exception("No Clerk session token");

      final api = ApiClient.instance;
      final res = await api.dio.post(
        "/auth/register-company",
        data: {
          "companyName": companyName,
          "ownerName": ownerName,
          "email": email,
          "phone": _phoneCtrl.text.trim(),
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (res.data is Map && res.data["success"] == true) {
        setState(() => _ok = "Company created — opening app…");
        ref.invalidate(authSyncProvider);
      } else {
        throw Exception(res.data?["error"]?.toString() ?? "Register failed");
      }
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    setState(() { _loading = true; _error = null; _ok = null; });
    try {
      final (clerkId, email) = await _clerkIdentity();
      final inviteToken = _tokenCtrl.text.trim();
      if (inviteToken.isEmpty) throw Exception("Paste invite token");

      final res = await ApiClient.instance.dio.post("/auth/accept-invite", data: {
        "inviteToken": inviteToken,
        "clerkId": clerkId,
        "email": email,
      });

      if (res.data is Map && res.data["success"] == true) {
        setState(() => _ok = "Linked! Opening app…");
        ref.invalidate(authSyncProvider);
      } else {
        throw Exception(res.data?["error"]?.toString() ?? "Accept failed");
      }
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete setup")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Your Clerk account is signed in, but not linked to a warehouse company yet.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text("New company"), icon: Icon(Icons.business)),
                    ButtonSegment(value: 1, label: Text("Have invite"), icon: Icon(Icons.mail)),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
                const SizedBox(height: 20),
                if (_tab == 0) ...[
                  TextField(
                    controller: _companyCtrl,
                    decoration: const InputDecoration(
                      labelText: "Company name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Your name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: "Phone (optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _createCompany,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Create company & continue"),
                  ),
                ] else ...[
                  TextField(
                    controller: _tokenCtrl,
                    decoration: const InputDecoration(
                      labelText: "Invite token",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _accept,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Accept invite & continue"),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 12),
                  Text(_ok!, style: const TextStyle(color: Colors.green), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async => ClerkAuthHolder.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text("Sign out"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
