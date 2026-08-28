import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text("Orders"),
            onTap: () => context.go("/orders"),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text("Scanner"),
            onTap: () => context.go("/scanner"),
          ),
        ],
      ),
    );
  }
}