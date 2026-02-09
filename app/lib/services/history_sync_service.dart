import 'package:cloud_firestore/cloud_firestore.dart';

class HistorySyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mark a history entry as synced by the device
  static Future<void> markHistoryAsSynced(String boxId, String historyDocId) async {
    try {
      await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('history')
          .doc(historyDocId)
          .update({
            'synced': true,
            'syncedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error marking history as synced: $e');
    }
  }

  /// Get all unsynced history for device to upload
  static Future<List<Map<String, dynamic>>> getUnsyncedHistory(String boxId) async {
    try {
      final snapshot = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('history')
          .where('synced', isEqualTo: false)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'docId': doc.id})
          .toList();
    } catch (e) {
      print('Error fetching unsynced history: $e');
      return [];
    }
  }

  /// Check if a specific action with timestamp was synced
  static Future<bool> isHistorySynced(String boxId, String action, Timestamp timestamp) async {
    try {
      final snapshot = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('history')
          .where('action', isEqualTo: action)
          .where('timestamp', isEqualTo: timestamp)
          .where('synced', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking sync status: $e');
      return false;
    }
  }

  /// Get count of pending syncs
  static Future<int> getPendingSyncCount(String boxId) async {
    try {
      final snapshot = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('history')
          .where('synced', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting pending sync count: $e');
      return 0;
    }
  }

  /// Stream of unsynced history count
  static Stream<int> getPendingSyncStream(String boxId) {
    return _firestore
        .collection('boxes')
        .doc(boxId)
        .collection('history')
        .where('synced', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
