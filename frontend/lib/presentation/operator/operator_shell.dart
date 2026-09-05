import "package:flutter/material.dart";
import "../../core/theme/app_theme.dart";

const kOperatorNav = [
  ("dashboard", "Dashboard", Icons.dashboard_outlined),
  ("orders", "Orders", Icons.inventory_2_outlined),
  ("scan", "Scan & Pack", Icons.qr_code_scanner),
  ("recording", "Recording", Icons.videocam_outlined),
  ("upload", "Upload", Icons.cloud_upload_outlined),
  ("history", "History", Icons.history),
  ("settings", "Settings", Icons.settings_outlined),
];

class OperatorShell extends StatelessWidget {
  final String currentId;
  final String title;
  final String? userName;
  final Widget body;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;

  const OperatorShell({
    super.key,
    required this.currentId,
    required this.title,
    required this.body,
    required this.onNavigate,
    required this.onSignOut,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final sidebar = Container(
      width: 220,
      color: AppColors.navy,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                SizedBox(width: 8),
                Text("LOSS DEFENDER",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: kOperatorNav.map((n) {
                final sel = n.$1 == currentId;
                return ListTile(
                  dense: true,
                  selected: sel,
                  selectedTileColor: Colors.white.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  leading: Icon(n.$3,
                      color: sel ? Colors.white : Colors.white70, size: 20),
                  title: Text(n.$2,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      )),
                  onTap: () => onNavigate(n.$1),
                );
              }).toList(),
            ),
          ),
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

    final content = Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.white,
          child: Row(
            children: [
              if (!wide)
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Text(userName ?? "",
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        Expanded(child: ColoredBox(color: AppColors.bg, child: body)),
      ],
    );

    if (wide) {
      return Scaffold(body: Row(children: [sidebar, Expanded(child: content)]));
    }
    return Scaffold(
      drawer: Drawer(child: sidebar),
      body: SafeArea(child: content),
    );
  }
}