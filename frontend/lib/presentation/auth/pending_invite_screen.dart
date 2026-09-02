import "package:clerk_flutter/clerk_flutter.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/auth/clerk_auth_holder.dart";
import "../../core/network/api_client.dart";
import "../../core/providers/app_providers.dart";

/// Shown when Clerk is signed in but no User row is linked yet.
/// Paste the invite token from seed / admin email and link the account.
class PendingInviteScreen extends ConsumerStatefulWidget {
  const PendingInviteScreen({super.key});

  @override
  ConsumerState<PendingInviteScreen> createState() => _PendingInviteScreenState();
}

class _PendingInviteScreenState extends ConsumerState<PendingInviteScreen> {
  final _tokenCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() {
      _loading = true;
      _error = null;
      _ok = null;
    });

    try {
      final auth = ClerkAuthHolder.instance;
      if (auth == null) {
        throw Exception("Clerk not ready — sign in again");
      }

      // clerk_flutter beta: user id / email from auth state
      String? clerkId;
      String? email;
      try {
        final dynamic u = (auth as dynamic).user;
        clerkId = u?.id?.toString();
        email = u?.email?.toString() ??
            u?.primaryEmailAddress?.toString() ??
            u?.emailAddresses?.first?.emailAddress?.toString();
      } catch (_) {}

      if (clerkId == null || clerkId.isEmpty) {
        throw Exception("Could not read Clerk user id from session");
      }
      if (email == null || email.isEmpty) {
        throw Exception("Could not read email from Clerk session");
      }

      final inviteToken = _tokenCtrl.text.trim();
      if (inviteToken.isEmpty) {
        throw Exception("Paste invite token from seed / admin");
      }

      final api = ApiClient.instance;
      final res = await api.dio.post("/auth/accept-invite", data: {
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  "Link your warehouse account",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You are signed in with Clerk, but this email is not linked yet.\n"
                  "Paste the invite token (from npm run seed / admin), then Accept.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(
                    labelText: "Invite token",
                    border: OutlineInputBorder(),
                    hintText: "Paste token from seed output",
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                if (_ok != null)
                  Text(_ok!, style: const TextStyle(color: Colors.green), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _accept,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Accept invite & continue"),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ClerkAuthHolder.signOut();
                  },
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