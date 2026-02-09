import 'package:cloud_firestore/cloud_firestore.dart';
import 'description_queue_service.dart';

class AutoDescriptionLinker {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Automatically link pending descriptions to unsynced offline unlocks
  /// Call this periodically (e.g., on heartbeat) to ensure descriptions are linked
  static Future<void> linkAllUnlinkedOfflineUnlocks(String boxId) async {
    try {
      // Get all unsynced OFFLINE_UNLOCK events
      final unlinkedQuery = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('history')
          .where('action', isEqualTo: 'OFFLINE_UNLOCK')
          .where('synced', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      if (unlinkedQuery.docs.isEmpty) {
        return;
      }

      // For each unsynced offline unlock, link a description if available
      for (var doc in unlinkedQuery.docs) {
        final description = await DescriptionQueueService.popDescriptionFromQueue(boxId);
        
        if (description != null) {
          // Update with description and mark as synced
          await doc.reference.update({
            'description': description,
            'synced': true,
          });
          print('[AutoLink] Linked description to offline unlock: $description');
        } else {
          // No description available, but mark as synced anyway
          await doc.reference.update({
            'synced': true,
          });
          print('[AutoLink] No description available, marked as synced');
          break; // Stop if queue is empty
        }
      }
    } catch (e) {
      print('[AutoLink] Error: $e');
    }
  }

  /// Check pending descriptions count for a box
  static Future<int> getPendingDescriptionsCount(String boxId) async {
    try {
      return await DescriptionQueueService.getPendingDescriptionsCount(boxId);
    } catch (e) {
      print('[AutoLink] Error getting pending count: $e');
      return 0;
    }
  }

  /// Check unsynced offline unlocks count
  static Future<int> getUnsyncedOfflineUnlocksCount(String boxId) async {
    try {
      final snap = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('history')
          .where('action', isEqualTo: 'OFFLINE_UNLOCK')
          .where('synced', isEqualTo: false)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('[AutoLink] Error getting unsynced count: $e');
      return 0;
    }
  }
}
