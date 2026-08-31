import "package:clerk_flutter/clerk_flutter.dart";
import "package:flutter/material.dart";
import "../../core/auth/clerk_auth_holder.dart";

class PendingInviteScreen extends StatelessWidget {
  const PendingInviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline, size: 56),
              const SizedBox(height: 16),
              const Text(
                "No account is linked to this sign-in yet.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "Ask your company admin to invite this email address, "
                "then accept the invite link and come back here.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
    );
  }
}