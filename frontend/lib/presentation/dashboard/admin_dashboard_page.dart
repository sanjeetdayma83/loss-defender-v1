import "package:flutter/material.dart";
import "../../core/theme/app_theme.dart";

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final bool positive;
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(delta!,
                style: TextStyle(
                  fontSize: 12,
                  color: positive ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ],
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  final Map<String, dynamic>? kpis;
  final List<dynamic> recentOrders;

  const AdminDashboardPage({
    super.key,
    this.kpis,
    this.recentOrders = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("Dashboard",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1100
              ? 4
              : c.maxWidth > 700
                  ? 2
                  : 1;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: const [
              KpiCard(label: "Total Orders", value: "—", delta: "Load KPIs"),
              KpiCard(label: "Packed Orders", value: "—"),
              KpiCard(label: "Open Claims", value: "—"),
              KpiCard(label: "Storage Used", value: "—"),
            ],
          );
        }),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Recent activity",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (recentOrders.isEmpty)
                const Text("No recent orders yet — open Orders to load.",
                    style: TextStyle(color: AppColors.muted))
              else
                ...recentOrders.take(5).map((o) {
                  final m = o is Map ? o : <String, dynamic>{};
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text("${m["marketplaceOrderId"] ?? m["id"] ?? ""}"),
                    subtitle: Text("${m["status"] ?? ""}"),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}