import "package:flutter/material.dart";
import "package:clerk_flutter/clerk_flutter.dart";

class ClerkAuthGate extends StatelessWidget {
  const ClerkAuthGate({super.key, required this.onSessionToken});

  final Future<void> Function(String token, String? clerkUserId) onSessionToken;

  @override
  Widget build(BuildContext context) {
    return ClerkErrorListener(
      child: ClerkAuthBuilder(
        signedOutBuilder: (context, authState) {
          return const SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: ClerkAuthentication(),
            ),
          );
        },
        signedInBuilder: (context, authState) {
          return _SyncToBackend(
            authState: authState,
            onSessionToken: onSessionToken,
          );
        },
      ),
    );
  }
}

class _SyncToBackend extends StatefulWidget {
  const _SyncToBackend({required this.authState, required this.onSessionToken});
  final ClerkAuthState authState;
  final Future<void> Function(String token, String? clerkUserId) onSessionToken;

  @override
  State<_SyncToBackend> createState() => _SyncToBackendState();
}

class _SyncToBackendState extends State<_SyncToBackend> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    try {
      // clerk_flutter 0.0.18: sessionToken() returns SessionToken with .jwt
      final sessionToken = await widget.authState.sessionToken();
      final token = sessionToken.jwt;
      if (token.isEmpty) {
        setState(() => _error = "Empty session JWT from Clerk");
        return;
      }
      final clerkId = widget.authState.user?.id;
      await widget.onSessionToken(token, clerkId);
    } catch (e) {
      // Fallback: lastActiveToken on Session
      try {
        final jwt = widget.authState.session?.lastActiveToken?.jwt;
        if (jwt != null && jwt.isNotEmpty) {
          await widget.onSessionToken(jwt, widget.authState.user?.id);
          return;
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _error =
            "Token sync failed: $e\nUse JWT paste on login screen.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text("Linking to LOSS DEFENDER..."),
      ],
    );
  }
}