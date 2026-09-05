import "package:flutter/material.dart";
import "../../core/theme/app_theme.dart";

class NavItem {
  final String id;
  final String label;
  final IconData icon;
  const NavItem(this.id, this.label, this.icon);
}

const kAdminNav = <NavItem>[
  NavItem("dashboard", "Dashboard", Icons.dashboard_outlined),
  NavItem("orders", "Orders", Icons.inventory_2_outlined),
  NavItem("evidence", "Evidence", Icons.videocam_outlined),
  NavItem("claims", "Claims", Icons.gavel_outlined),
  NavItem("returns", "Returns", Icons.assignment_return_outlined),
  NavItem("users", "Users", Icons.people_outline),
  NavItem("warehouses", "Warehouses", Icons.warehouse_outlined),
  NavItem("marketplace", "Marketplace", Icons.storefront_outlined),
  NavItem("analytics", "Analytics", Icons.bar_chart_outlined),
  NavItem("audit", "Audit Logs", Icons.history),
  NavItem("billing", "Billing", Icons.credit_card_outlined),
  NavItem("settings", "Settings", Icons.settings_outlined),
];

class AppShell extends StatelessWidget {
  final String currentId;
  final String title;
  final String? userName;
  final String? roleLabel;
  final Widget body;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;
  final List<Widget>? actions;

  const AppShell({
    super.key,
    required this.currentId,
    required this.title,
    required this.body,
    required this.onNavigate,
    required this.onSignOut,
    this.userName,
    this.roleLabel,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    final sidebar = Container(
      width: 240,
      color: AppColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("LOSS DEFENDER",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      )),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: kAdminNav.map((n) {
                final selected = n.id == currentId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(n.icon,
                          color: selected ? Colors.white : Colors.white70, size: 20),
                      title: Text(n.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13,
                          )),
                      onTap: () => onNavigate(n.id),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout, color: Colors.white70, size: 20),
            title: const Text("Sign out",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            onTap: onSignOut,
          ),
        ],
      ),
    );

    final topBar = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          ...?actions,
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              (userName ?? "U").isNotEmpty ? (userName![0].toUpperCase()) : "U",
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          if (wide)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName ?? "",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(roleLabel ?? "",
                    style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
        ],
      ),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            Expanded(
              child: Column(
                children: [
                  topBar,
                  Expanded(child: ColoredBox(color: AppColors.bg, child: body)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(child: sidebar),
      body: Column(
        children: [
          SafeArea(bottom: false, child: topBar),
          Expanded(child: ColoredBox(color: AppColors.bg, child: body)),
        ],
      ),
    );
  }
}