import 'package:cloud_firestore/cloud_firestore.dart';

class DescriptionQueueService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a description to the offline queue for a specific box
  static Future<void> addDescriptionToQueue(String boxId, String description, {String? code}) async {
    try {
      await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('descriptionQueue')
          .add({
        'description': description.isEmpty ? 'No description provided' : description,
        if (code != null) 'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'used': false,
      });
    } catch (e) {
      throw Exception('Failed to add description to queue: $e');
    }
  }

  /// Get the first unused description from the queue (prefer entries without a code field)
  /// Skip entries that have a code field set, as they're reserved for code-specific matching
  static Future<String?> popDescriptionFromQueue(String boxId) async {
    try {
      // Fetch all unused entries
      final allQuery = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('descriptionQueue')
          .where('used', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .get();

      if (allQuery.docs.isEmpty) {
        print('[DescQueue] No unused descriptions in queue (FIFO pop)');
        return null; // No description available
      }

      // Filter to find entries WITHOUT a code field (true generic queue items)
      var docWithoutCode = allQuery.docs.firstWhere(
        (d) => !d.data().containsKey('code') || d['code'] == null,
        orElse: () => allQuery.docs.first, // Fallback to first if all have codes
      );

      final docId = docWithoutCode.id;
      final description = docWithoutCode['description'];
      final codeField = docWithoutCode.data().containsKey('code') ? docWithoutCode['code'] : 'none';

      print('[DescQueue] Popping FIFO queueDoc=$docId, code=$codeField, desc="$description"');

      // Mark as used
      await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('descriptionQueue')
          .doc(docId)
          .update({'used': true, 'usedAt': FieldValue.serverTimestamp()});

      return description;
    } catch (e) {
      throw Exception('Failed to pop description from queue: $e');
    }
  }

  /// Try to pop a description that matches a specific generated code.
  /// If not found, returns null.
  static Future<String?> popDescriptionForCode(String boxId, String code) async {
    try {
      final query = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('descriptionQueue')
          .where('code', isEqualTo: code)
          .get();

      if (query.docs.isEmpty) {
        print('[DescQueue] No queue entry with code=$code');
        return null;
      }

      // Find first unused by createdAt (FIFO for that code)
      var docs = query.docs.where((d) => d.data().containsKey('used') ? d['used'] == false : true).toList();
      if (docs.isEmpty) {
        print('[DescQueue] All entries for code=$code are already used');
        return null;
      }

      docs.sort((a, b) {
        final aTs = a.data().containsKey('createdAt') ? (a['createdAt'] as Timestamp?) : null;
        final bTs = b.data().containsKey('createdAt') ? (b['createdAt'] as Timestamp?) : null;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return aTs.compareTo(bTs);
      });

      final doc = docs.first;
      final docId = doc.id;
      final description = doc['description'];

      print('[DescQueue] Popping code-matched queueDoc=$docId, code=$code, desc="$description"');

      await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('descriptionQueue')
          .doc(docId)
          .update({'used': true, 'usedAt': FieldValue.serverTimestamp()});

      return description;
    } catch (e) {
      throw Exception('Failed to pop description for code: $e');
    }
  }

  /// Get pending descriptions count
  static Future<int> getPendingDescriptionsCount(String boxId) async {
    try {
      final query = await _firestore
          .collection('boxes')
          .doc(boxId)
          .collection('descriptionQueue')
          .where('used', isEqualTo: false)
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get pending descriptions count: $e');
    }
  }

  /// Get stream of pending descriptions (for UI updates)
  static Stream<int> getPendingDescriptionsStream(String boxId) {
    return _firestore
        .collection('boxes')
        .doc(boxId)
        .collection('descriptionQueue')
        .where('used', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
