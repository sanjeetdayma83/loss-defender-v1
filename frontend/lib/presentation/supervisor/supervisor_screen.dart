import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class SupervisorScreen extends StatefulWidget {
  const SupervisorScreen({super.key});
  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  List<dynamic> _active = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.instance.dio.get("/orders", queryParameters: {"status": "packing", "limit": 50}),
        ApiClient.instance.dio.get("/orders", queryParameters: {"status": "recording", "limit": 50}),
      ]);
      final packing = ApiClient.instance.unwrap<List<dynamic>>(results[0]);
      final recording = ApiClient.instance.unwrap<List<dynamic>>(results[1]);
      setState(() => _active = [...packing, ...recording]);
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live floor view"),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _active.isEmpty
                  ? const Center(child: Text("No stations actively packing/recording"))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _active.length,
                        itemBuilder: (context, i) {
                          final o = _active[i];
                          final isRecording = o["status"] == "recording";
                          return Card(
                            color: isRecording ? Colors.red.shade50 : Colors.amber.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(isRecording ? Icons.fiber_manual_record : Icons.inventory_2,
                                      color: isRecording ? Colors.red : Colors.amber.shade800),
                                  const SizedBox(height: 8),
                                  Text(o["marketplaceOrderId"] ?? o["id"],
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(o["status"], style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}