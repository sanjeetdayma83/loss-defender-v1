import "package:flutter/material.dart";

/// Placeholder screen. The blueprint calls for a Drift (SQLite) offline
/// queue that stores scans/recordings locally when there is no connectivity,
/// then auto-syncs. That local-storage layer is NOT wired yet — this screen
/// exists so the route/nav entry is real, but it does not fabricate data.
/// Next step: add `drift` tables for pending scans + pending upload segments,
/// and have scanner/recording screens write here first before calling the API.
class OfflineQueueScreen extends StatelessWidget {
  const OfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Offline queue")),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48),
              SizedBox(height: 12),
              Text(
                "Offline queue not yet wired to local storage.",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                "Currently the app requires connectivity for scans and "
                "recordings. Drift-based local queueing is planned next.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}