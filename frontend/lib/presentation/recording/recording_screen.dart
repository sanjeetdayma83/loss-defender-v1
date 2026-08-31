import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  String? _recordingId;
  String? _evidenceId;
  String _status = "idle";
  String? _error;

  Future<void> _start() async {
    setState(() { _error = null; _status = "starting"; });
    try {
      final res = await ApiClient.instance.dio.post("/recordings/start", data: {
        "orderId": widget.orderId,
      });
      final d = res.data["data"] as Map<String, dynamic>;
      setState(() {
        _recordingId = d["id"]?.toString();
        _status = d["status"]?.toString() ?? "started";
      });
    } catch (e) {
      setState(() { _error = e.toString(); _status = "idle"; });
    }
  }

  Future<void> _stop() async {
    if (_recordingId == null) return;
    setState(() => _status = "stopping");
    try {
      final res = await ApiClient.instance.dio.post("/recordings/$_recordingId/stop");
      final d = res.data["data"] as Map<String, dynamic>;
      setState(() {
        _status = "completed";
        _evidenceId = d["evidenceId"]?.toString();
      });
    } catch (e) {
      setState(() { _error = e.toString(); _status = "started"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recording"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go("/orders/${widget.orderId}"),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Order: ${widget.orderId}"),
            Text("Status: $_status"),
            if (_recordingId != null) Text("Recording: $_recordingId"),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            if (_status == "idle" || _status == "starting")
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(56)),
                onPressed: _status == "starting" ? null : _start,
                child: const Text("REC START"),
              ),
            if (_recordingId != null && _status != "completed")
              FilledButton(
                onPressed: _status == "stopping" ? null : _stop,
                child: const Text("STOP"),
              ),
            if (_evidenceId != null)
              OutlinedButton(
                onPressed: () => context.go("/evidence/$_evidenceId"),
                child: Text("View evidence $_evidenceId"),
              ),
          ],
        ),
      ),
    );
  }
}