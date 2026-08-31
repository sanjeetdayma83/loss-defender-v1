import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../config/env.dart";
import "../../core/auth/session_provider.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go("/dashboard")),
      ),
      body: ListView(
        children: [
          ListTile(title: const Text("API"), subtitle: Text(Env.apiBaseUrl)),
          ListTile(title: const Text("User"), subtitle: Text("${s.email} · ${s.role}")),
          ListTile(title: const Text("Company ID"), subtitle: Text(s.companyId ?? "-")),
          ListTile(
            title: const Text("Sign out"),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) context.go("/login");
            },
          ),
        ],
      ),
    );
  }
}