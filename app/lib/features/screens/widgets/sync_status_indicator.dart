import 'package:flutter/material.dart';
import '/services/history_sync_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  final String boxId;
  final bool showLabel;

  const SyncStatusIndicator({
    required this.boxId,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: HistorySyncService.getPendingSyncStream(boxId),
      builder: (context, snapshot) {
        int pendingCount = snapshot.data ?? 0;
        bool hasPending = pendingCount > 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hasPending ? Colors.orange.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasPending ? Colors.orange.shade200 : Colors.green.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPending)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                  ),
                )
              else
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
              const SizedBox(width: 8),
              if (showLabel)
                Text(
                  hasPending ? 'Pending Sync: $pendingCount' : 'All Synced',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasPending ? Colors.orange.shade700 : Colors.green.shade700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
