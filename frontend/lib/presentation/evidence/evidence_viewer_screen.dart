import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../core/network/api_client.dart";

class EvidenceViewerScreen extends StatefulWidget {
  final String evidenceId;
  const EvidenceViewerScreen({super.key, required this.evidenceId});
  @override
  State<EvidenceViewerScreen> createState() => _EvidenceViewerScreenState();
}

class _EvidenceViewerScreenState extends State<EvidenceViewerScreen> {
  Map<String, dynamic>? _evidence;
  List<dynamic>? _frames;
  bool _loading = true;
  bool _loadingLinks = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get("/evidence/${widget.evidenceId}");
      setState(() => _evidence = ApiClient.instance.unwrap<Map<String, dynamic>>(res));
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _getDownloadLinks() async {
    setState(() => _loadingLinks = true);
    try {
      final res = await ApiClient.instance.dio.get("/evidence/${widget.evidenceId}/download");
      final data = ApiClient.instance.unwrap<Map<String, dynamic>>(res);
      setState(() => _frames = data["frames"] as List<dynamic>?);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.instance.friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingLinks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Evidence")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text("Status: ${_evidence?["status"]}"),
                    Text("Frame count: ${_evidence?["frameCount"]}"),
                    Text("Checksum: ${_evidence?["checksum"] ?? "-"}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadingLinks ? null : _getDownloadLinks,
                      icon: const Icon(Icons.link),
                      label: Text(_loadingLinks ? "Loading..." : "Get signed download links"),
                    ),
                    const SizedBox(height: 12),
                    if (_frames != null)
                      ...(_frames!.map((f) => Card(
                            child: ListTile(
                              title: Text("Frame ${f["index"]}"),
                              subtitle: Text(f["b2Key"] ?? "",
                                  style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () async {
                                  final url = f["url"] as String?;
                                  if (url != null) {
                                    await launchUrl(Uri.parse(url));
                                  }
                                },
                              ),
                            ),
                          ))),
                  ],
                ),
    );
  }
}