import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth/session_provider.dart";
import "../../core/network/api_client.dart";

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _kpis;
  String? _err;

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  Future<void> _loadKpis() async {
    try {
      final res = await ApiClient.instance.dio.get("/analytics/kpis");
      setState(() => _kpis = Map<String, dynamic>.from(res.data["data"] as Map));
    } catch (e) {
      setState(() => _err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final role = session.role ?? "";

    final tiles = <_Tile>[
      _Tile("Orders", Icons.list_alt, "/orders", true),
      _Tile("Scanner", Icons.qr_code_scanner, "/orders", true),
      _Tile("Claims", Icons.report_problem, "/claims", true),
      _Tile("Returns", Icons.assignment_return, "/returns", true),
      _Tile("Analytics", Icons.insights, "/analytics",
          ["company_admin", "warehouse_manager", "supervisor", "viewer", "super_admin"].contains(role)),
      _Tile("Admin", Icons.admin_panel_settings, "/admin",
          ["company_admin", "super_admin"].contains(role)),
      _Tile("Settings", Icons.settings, "/settings", true),
    ].where((t) => t.show).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            tooltip: "Sign out",
            onPressed: () async {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) context.go("/login");
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("${session.email ?? ""} · ${session.role ?? ""}",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_kpis != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _kpiChip("Orders", "${_kpis!["ordersTotal"]}"),
                _kpiChip("Open claims", "${_kpis!["openClaims"]}"),
                _kpiChip("Evidence %", "${_kpis!["evidenceCoveragePercent"]}"),
              ],
            ),
          if (_err != null) Text(_err!, style: const TextStyle(color: Colors.orange)),
          const SizedBox(height: 16),
          ...tiles.map((t) => Card(
                child: ListTile(
                  leading: Icon(t.icon),
                  title: Text(t.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(t.path),
                ),
              )),
        ],
      ),
    );
  }

  Widget _kpiChip(String label, String value) => Chip(label: Text("$label: $value"));
}

class _Tile {
  _Tile(this.label, this.icon, this.path, this.show);
  final String label;
  final IconData icon;
  final String path;
  final bool show;
}