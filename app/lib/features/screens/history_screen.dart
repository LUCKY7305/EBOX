import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'models/event_details_model.dart';
import 'widgets/history_card.dart';
import 'widgets/event_details_sheet.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('boxes')
            .where('assignedTo', isEqualTo: user.uid)
            .limit(1)
            .snapshots(),
        builder: (context, boxSnap) {
          if (boxSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!boxSnap.hasData || boxSnap.data!.docs.isEmpty) {
            return _emptyState(message: "No box connected.\nConnect a box to see history.");
          }

          final boxDoc = boxSnap.data!.docs.first;
          final internalId = boxDoc.id;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('boxes')
                .doc(internalId)
                .collection('history')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, historySnap) {
              if (historySnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!historySnap.hasData || historySnap.data!.docs.isEmpty) {
                return _emptyState(message: "No history yet.\nOpen/Close events will appear here.");
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: historySnap.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = historySnap.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final action = data['action'] ?? 'UNKNOWN';
                  final ts = data['timestamp'] as Timestamp?;
                  final codeUsed = data['codeUsed'] ?? ''; 
                  final description = data['description'] ?? 'No description provided';

                  final date = ts != null
                      ? DateFormat('dd MMM yyyy • hh:mm a').format(ts.toDate())
                      : 'Unknown time';

                  bool isOpen = false;
                  String title = "Unknown Event";
                  String mode = "Unknown";

                  if (action == 'OPEN') {
                    isOpen = true;
                    title = "Box Unlocked";
                    mode = "Online";
                  } else if (action == 'OFFLINE_UNLOCK') {
                    isOpen = true;
                    title = "Box Unlocked";
                    mode = "Offline";
                  } else if (action == 'CLOSE' || action == 'LOCK') {
                    isOpen = false;
                    title = "Box Locked";
                    mode = "Online";
                  }

                  final eventDetails = EventDetailsModel(
                    title: title,
                    mode: mode,
                    code: codeUsed,
                    description: description,
                    dateTime: date,
                    action: action,
                  );

                  return HistoryCard(
                    isOpen: isOpen,
                    title: title,
                    subtitle: date,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => EventDetailsSheet(event: eventDetails),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static Widget _emptyState({required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}