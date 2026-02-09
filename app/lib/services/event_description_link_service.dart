import 'package:cloud_firestore/cloud_firestore.dart';
import 'description_queue_service.dart';

class EventDescriptionLinkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Link a pending description to the most recent OFFLINE_UNLOCK event
  /// Call this after an offline unlock is recorded by the device
  static Future<void> linkPendingDescriptionToLastOfflineUnlock(String boxId) async {
    try {
      // Select the oldest unsynced OFFLINE_UNLOCK (FIFO matching)
      final historyQuery = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('history')
          .where('action', isEqualTo: 'OFFLINE_UNLOCK')
          .where('synced', isEqualTo: false)
          .orderBy('timestamp', descending: false)
          .limit(1)
          .get();

      if (historyQuery.docs.isEmpty) {
        print('No unsynced OFFLINE_UNLOCK events found for box $boxId');
        return;
      }

      final lastOfflineUnlock = historyQuery.docs.first;

      // Try to find a queued description that matches the code used in the event.
      // Fallback to FIFO pop if no code-specific description exists.
      String? description;
      final codeUsed = lastOfflineUnlock.data().containsKey('codeUsed') ? lastOfflineUnlock['codeUsed'] as String? : null;
      print('[LinkService] Event historyDoc=${lastOfflineUnlock.id}, timestamp=${lastOfflineUnlock['timestamp']}, codeUsed=$codeUsed');
      
      if (codeUsed != null && codeUsed.isNotEmpty) {
        print('[LinkService] Attempting code-specific match for code: $codeUsed');
        description = await DescriptionQueueService.popDescriptionForCode(boxId, codeUsed);
        if (description != null) {
          print('[LinkService] ✓ Code-matched description: "$description"');
        } else {
          print('[LinkService] ✗ No code match found, falling back to FIFO pop');
        }
      }
      if (description == null) {
        print('[LinkService] Attempting FIFO pop (oldest queued description)');
        description = await DescriptionQueueService.popDescriptionFromQueue(boxId);
        if (description != null) {
          print('[LinkService] ✓ FIFO popped description: "$description"');
        } else {
          print('[LinkService] ✗ No description available in queue');
        }
      }

      final updateData = <String, dynamic>{'synced': true};
      if (description != null) updateData['description'] = description;

      await lastOfflineUnlock.reference.update(updateData);
    } catch (e) {
      throw Exception('Failed to link description to offline unlock: $e');
    }
  }

  /// Automatically link all pending descriptions to offline unlocks
  static Future<void> linkAllPendingDescriptions(String boxId) async {
    try {
      final pendingCount = await DescriptionQueueService.getPendingDescriptionsCount(boxId);
      
      for (int i = 0; i < pendingCount; i++) {
        await linkPendingDescriptionToLastOfflineUnlock(boxId);
      }
    } catch (e) {
      throw Exception('Failed to link all pending descriptions: $e');
    }
  }

  /// Listen for unsynced OFFLINE_UNLOCK events and automatically link descriptions
  static Stream<void> autoLinkDescriptionsStream(String boxId) {
    return _firestore
        .collection('boxes')
        .doc(boxId)
        .collection('history')
        .where('action', isEqualTo: 'OFFLINE_UNLOCK')
        .where('synced', isEqualTo: false)
        .snapshots()
        .asyncMap((_) async {
      // Automatically link pending description whenever new unsynced offline unlocks appear
      await linkPendingDescriptionToLastOfflineUnlock(boxId);
    });
  }
}

