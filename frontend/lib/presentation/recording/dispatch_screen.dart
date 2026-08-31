import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class DispatchScreen extends StatefulWidget {
  final String orderId;
  const DispatchScreen({super.key, required this.orderId});
  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final _awbCtrl = TextEditingController();
  final _courierCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_awbCtrl.text.trim().isEmpty || _courierCtrl.text.trim().isEmpty) {
      setState(() => _error = "AWB and courier are required");
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ApiClient.instance.dio.post("/orders/${widget.orderId}/dispatch", data: {
        "awb": _awbCtrl.text.trim(),
        "courier": _courierCtrl.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dispatch confirm")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Order: ${widget.orderId}", style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _courierCtrl,
              decoration: const InputDecoration(labelText: "Courier"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _awbCtrl,
              decoration: const InputDecoration(labelText: "AWB / Tracking number"),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.local_shipping),
              label: _saving
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Confirm dispatch"),
            ),
          ],
        ),
      ),
    );
  }
}