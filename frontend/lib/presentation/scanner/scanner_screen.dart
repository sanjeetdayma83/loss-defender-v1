import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _barcode = TextEditingController();
  String _log = "";
  bool _busy = false;

  Future<void> _validate() async {
    final code = _barcode.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await ApiClient.instance.dio.post("/scanner/validate", data: {
        "orderId": widget.orderId,
        "barcode": code,
      });
      final d = res.data["data"];
      setState(() {
        _log = "$d\n$_log";
        _barcode.clear();
      });
    } catch (e) {
      setState(() => _log = "ERROR: $e\n$_log");
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go("/orders/${widget.orderId}"),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Order: ${widget.orderId}", style: const TextStyle(fontSize: 12)),
            TextField(
              controller: _barcode,
              decoration: const InputDecoration(
                labelText: "Barcode / SKU (wedge or type)",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _validate(),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _validate,
              child: Text(_busy ? "..." : "Validate"),
            ),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: Text(_log))),
          ],
        ),
      ),
    );
  }
}