import "package:flutter/material.dart";
import "../../core/theme/app_theme.dart";

class OrdersListPage extends StatelessWidget {
  final List<dynamic> orders;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpen;

  const OrdersListPage({
    super.key,
    required this.orders,
    required this.loading,
    required this.onRefresh,
    required this.onCreate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text("Orders",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Create Order"),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : orders.isEmpty
                  ? const Center(
                      child: Text("No orders",
                          style: TextStyle(color: AppColors.muted)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text("Order ID")),
                            DataColumn(label: Text("Marketplace")),
                            DataColumn(label: Text("Status")),
                            DataColumn(label: Text("Warehouse")),
                            DataColumn(label: Text("Items")),
                          ],
                          rows: orders.map((o) {
                            final m = Map<String, dynamic>.from(o as Map);
                            final id = m["id"]?.toString() ?? "";
                            final items = m["items"];
                            final count = items is List ? items.length : "—";
                            return DataRow(
                              onSelectChanged: (_) => onOpen(id),
                              cells: [
                                DataCell(Text(m["marketplaceOrderId"]?.toString() ?? id)),
                                DataCell(Text(m["marketplace"]?.toString() ?? "—")),
                                DataCell(_statusChip(m["status"]?.toString() ?? "")),
                                DataCell(Text(
                                    (m["warehouseId"]?.toString() ?? "—").length > 8
                                        ? "${m["warehouseId"].toString().substring(0, 8)}…"
                                        : m["warehouseId"]?.toString() ?? "—")),
                                DataCell(Text("$count")),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = AppColors.muted;
    if (status.contains("complete") || status == "shipped" || status == "closed") {
      bg = const Color(0xFFECFDF5);
      fg = AppColors.success;
    } else if (status.contains("progress") || status == "packing" || status == "recording") {
      bg = const Color(0xFFEFF6FF);
      fg = AppColors.primary;
    } else if (status.contains("claim") || status == "issue") {
      bg = const Color(0xFFFEF2F2);
      fg = AppColors.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}