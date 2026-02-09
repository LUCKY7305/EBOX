import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import the screens we navigate to
import 'history_screen.dart';
import 'change_pin_screen.dart'; // ✅ Added for Phase 6

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------------------------------------------------------
            // 1. USER HEADER (Standard User Data)
            // ---------------------------------------------------------
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, userSnap) {
                final username = userSnap.data?.get('username') ?? 'User';
                return _card(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.blue.shade800,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        username,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(user.email ?? '', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ---------------------------------------------------------
            // 2. BOX DETAILS (Reverse Lookup Logic)
            // ---------------------------------------------------------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('boxes')
                  .where('assignedTo', isEqualTo: user.uid)
                  .limit(1)
                  .snapshots(),
              builder: (context, boxSnap) {
                // Default values if not connected
                String displayId = "Not Connected";
                bool isLocked = false;
                bool hasBox = false;

                if (boxSnap.hasData && boxSnap.data!.docs.isNotEmpty) {
                  final data = boxSnap.data!.docs.first.data() as Map<String, dynamic>;
                  // Safe fallback: check both field names for ID
                  displayId = data['publicBoxId'] ?? data['boxId'] ?? "Unknown ID";
                  isLocked = data['isLocked'] ?? true;
                  hasBox = true;
                }

                return _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        icon: Icons.inventory_2,
                        label: 'Box ID',
                        value: displayId,
                      ),
                      const SizedBox(height: 8),
                      // Only show lock status if actually connected
                      if (hasBox)
                        _infoRow(
                          icon: Icons.lock,
                          label: 'Security',
                          value: isLocked ? 'Locked' : 'Unlocked',
                          valueColor: isLocked ? Colors.red : Colors.green,
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ---------------------------------------------------------
            // 3. ACTIONS
            // ---------------------------------------------------------
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  
                  // View History Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: const Text('View History'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      );
                    },
                  ),

                  // Change PIN Button (✅ Phase 6 Update)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pin),
                    title: const Text('Change PIN'),
                    subtitle: const Text('Update security code'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to the new Change PIN Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePinScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ---------------------------------------------------------
            // 4. LOGOUT
            // ---------------------------------------------------------
            _card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Card Style
  static Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
        ],
      ),
      child: child,
    );
  }

  // Helper Widget for Information Rows
  static Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}