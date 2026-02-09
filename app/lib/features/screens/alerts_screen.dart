import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. REVERSE LOOKUP: Find the box assigned to this user
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
            return _emptyState("No box connected.");
          }

          final boxDoc = boxSnap.data!.docs.first;
          final internalId = boxDoc.id;

          // 2. FETCH EVENTS: Listen to 'history' and display as Alerts
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('boxes')
                .doc(internalId)
                .collection('history')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, alertSnap) {
              if (alertSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!alertSnap.hasData || alertSnap.data!.docs.isEmpty) {
                return _emptyState("No new notifications.");
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: alertSnap.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = alertSnap.data!.docs[index];
                  final action = doc['action'];
                  final ts = doc['timestamp'] as Timestamp?;

                  // Format Time (e.g. 10:30 AM • 12 Oct)
                  final timeStr = ts != null
                      ? DateFormat('h:mm a • d MMM').format(ts.toDate())
                      : 'Just now';

                  // Determine Styling based on Event
                  // OPEN = Urgent/Warning (Orange)
                  // CLOSE = Info/Safe (Blue)
                  bool isUrgent = action == 'OPEN'; 
                  
                  return _AlertCard(
                    title: isUrgent ? "Box Accessed" : "Box Secured",
                    subtitle: isUrgent 
                        ? "Your box was unlocked." 
                        : "Your box was locked successfully.",
                    time: timeStr,
                    isUrgent: isUrgent,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final bool isUrgent;

  const _AlertCard({
    required this.title, 
    required this.subtitle, 
    required this.time,
    required this.isUrgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Add a subtle border for Urgent alerts
        border: isUrgent ? Border.all(color: Colors.orange.shade100) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.orange.shade50 : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUrgent ? Icons.lock_open : Icons.check_circle,
              color: isUrgent ? Colors.orange : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      time, 
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}