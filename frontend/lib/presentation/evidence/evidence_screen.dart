import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key, required this.evidenceId});
  final String evidenceId;
  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.dio.get("/evidence/${widget.evidenceId}");
      setState(() => _data = Map<String, dynamic>.from(res.data["data"] as Map));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Evidence"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go("/dashboard")),
      ),
      body: _data == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_data.toString()),
            ),
    );
  }
}