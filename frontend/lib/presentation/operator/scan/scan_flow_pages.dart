import "package:flutter/material.dart";
import "../../../core/theme/app_theme.dart";

/// 01 — Scanner Home
class ScannerHomePage extends StatefulWidget {
  final Future<void> Function(String orderOrAwb) onStart;
  const ScannerHomePage({super.key, required this.onStart});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _go() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _error = "Enter Order ID or AWB");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onStart(v);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Scan & Pack",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text("Scan order / AWB to start packing",
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 28),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.qr_code_scanner,
                      size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _go,
                  child: Text(_busy ? "Loading…" : "Start Scanning"),
                ),
                const SizedBox(height: 16),
                const Text("or", style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _busy ? null : _go(),
                  decoration: InputDecoration(
                    hintText: "Enter Order ID / AWB",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _busy ? null : _go,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Feature(Icons.bolt, "Fast"),
                    _Feature(Icons.verified, "Accurate"),
                    _Feature(Icons.security, "Secure"),
                    _Feature(Icons.videocam, "Evidence Ready"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    );
  }
}

/// 03 — Order loaded success
class OrderScannedPage extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onStartPacking;

  const OrderScannedPage({
    super.key,
    required this.order,
    required this.onStartPacking,
  });

  @override
  Widget build(BuildContext context) {
    final items = order["items"];
    final count = items is List ? items.length : 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 64, color: AppColors.success),
                const SizedBox(height: 12),
                const Text("Order Scanned Successfully",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _row("Order ID", order["marketplaceOrderId"]?.toString() ??
                    order["id"]?.toString() ?? "—"),
                _row("Status", order["status"]?.toString() ?? "—"),
                _row("Marketplace", order["marketplace"]?.toString() ?? "—"),
                _row("Total Items", "$count"),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onStartPacking,
                  child: const Text("Start Packing →"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
                width: 110,
                child: Text(k, style: const TextStyle(color: AppColors.muted))),
            Expanded(
                child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

/// 04 + 05 + 06 — Item scan list + feedback + complete
class ItemScanPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final Future<Map<String, dynamic>> Function(String sku) onValidate;
  final VoidCallback onAllDone;

  const ItemScanPage({
    super.key,
    required this.order,
    required this.onValidate,
    required this.onAllDone,
  });

  @override
  State<ItemScanPage> createState() => _ItemScanPageState();
}

class _ItemScanPageState extends State<ItemScanPage> {
  final _sku = TextEditingController();
  String? _feedback; // success | wrong | duplicate
  String? _feedbackMsg;
  bool _busy = false;

  List<Map<String, dynamic>> get _items {
    final raw = widget.order["items"];
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  int get _done =>
      _items.where((i) => (i["scannedQty"] as num? ?? 0) >= (i["qty"] as num? ?? 1)).length;

  Future<void> _scan() async {
    final sku = _sku.text.trim();
    if (sku.isEmpty) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final res = await widget.onValidate(sku);
      final status = res["status"]?.toString() ?? "ok";
      setState(() {
        if (status == "wrong") {
          _feedback = "wrong";
          _feedbackMsg = res["message"]?.toString() ?? "Wrong item";
        } else if (status == "duplicate") {
          _feedback = "duplicate";
          _feedbackMsg = res["message"]?.toString() ?? "Already scanned";
        } else {
          _feedback = "success";
          _feedbackMsg = "Scan successful";
          // optimistic local bump if API returns updated order
          if (res["order"] is Map) {
            widget.order.clear();
            widget.order.addAll(Map<String, dynamic>.from(res["order"] as Map));
          } else {
            for (final i in _items) {
              if (i["sku"] == sku) {
                i["scannedQty"] = ((i["scannedQty"] as num?) ?? 0) + 1;
              }
            }
          }
        }
      });
      _sku.clear();
    } catch (e) {
      setState(() {
        _feedback = "wrong";
        _feedbackMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _sku.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final pct = total == 0 ? 0.0 : _done / total;

    if (total > 0 && _done >= total) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 72, color: AppColors.success),
              const SizedBox(height: 12),
              const Text("All Items Scanned!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text("$_done of $total items verified",
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.onAllDone,
                child: const Text("Continue to Recording →"),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(value: pct, minHeight: 6),
          const SizedBox(height: 8),
          Text("$_done / $total items · ${(pct * 100).toStringAsFixed(0)}%"),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = _items[i];
                final need = (it["qty"] as num?)?.toInt() ?? 1;
                final got = (it["scannedQty"] as num?)?.toInt() ?? 0;
                final done = got >= need;
                return ListTile(
                  leading: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done ? AppColors.success : AppColors.muted,
                  ),
                  title: Text(it["name"]?.toString() ?? it["sku"]?.toString() ?? ""),
                  subtitle: Text("SKU: ${it["sku"]}"),
                  trailing: Text("$got / $need"),
                );
              },
            ),
          ),
          if (_feedback != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _feedback == "success"
                    ? const Color(0xFFECFDF5)
                    : _feedback == "duplicate"
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _feedbackMsg ?? "",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _feedback == "success"
                      ? AppColors.success
                      : _feedback == "duplicate"
                          ? const Color(0xFFD97706)
                          : AppColors.danger,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sku,
                  decoration: const InputDecoration(
                    hintText: "Scan / type SKU",
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  onSubmitted: (_) => _busy ? null : _scan(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _scan,
                child: const Text("Validate"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}