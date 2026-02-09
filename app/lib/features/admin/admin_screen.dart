import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool loading = false;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  // 1. GENERATE PUBLIC ID (EBOX-XXXX)
  Future<void> _generatePublicId(String internalId) async {
    setState(() => loading = true);
    try {
      const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      Random rnd = Random();
      String part1 = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
      String part2 = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
      
      String newPublicId = "EBOX-$part1-$part2";

      await FirebaseFirestore.instance.collection('boxes').doc(internalId).update({
        'publicBoxId': newPublicId,
        'status': 'ready_to_claim', 
      });
      _msg("Generated ID: $newPublicId");
    } catch (e) {
      _msg("Error: $e");
    }
    setState(() => loading = false);
  }

  // 2. GENERATE 500 OFFLINE CODES
  // We use only 0,1,2,4,5,7,8 (Skipping 3,6,9,# due to hardware damage)
  Future<void> _generateOfflineCodes(String internalId) async {
    setState(() => loading = true);
    try {
      List<String> codes = [];
      Random rnd = Random();
      // Safe digits for your keypad
      const safeDigits = ['0','1','2','4','5','7','8']; 

      for (int i = 0; i < 500; i++) {
        String code = "";
        for (int j = 0; j < 6; j++) {
          code += safeDigits[rnd.nextInt(safeDigits.length)];
        }
        codes.add(code);
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('boxes').doc(internalId).update({
        'offlineCodes': codes,
        'offlineIndex': 0, // Start at the beginning
        'isCodesSynced': false, // Flag to tell ESP it needs to download
      });

      _msg("Success! 500 Offline Codes generated.");
    } catch (e) {
      _msg("Error: $e");
    }
    setState(() => loading = false);
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: loading 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('boxes').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;

            if (docs.isEmpty) {
              return const Center(child: Text("No boxes detected."));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final internalId = docs[i].id;
                final publicId = data['publicBoxId'];
                final assignedTo = data['assignedTo'];
                
                // Check if codes exist
                final List<dynamic>? codes = data['offlineCodes'];
                final bool hasCodes = codes != null && codes.isNotEmpty;
                final bool isSynced = data['isCodesSynced'] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Icon(Icons.inventory_2, color: Colors.blue.shade800),
                            const SizedBox(width: 8),
                            Text(
                              publicId ?? "New Device ($internalId)",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("Owner: ${assignedTo ?? 'Unassigned'}"),
                        
                        const Divider(height: 24),

                        // Action Buttons
                        if (publicId == null)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.settings),
                            label: const Text("Initialize Box ID"),
                            onPressed: () => _generatePublicId(internalId),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          )
                        else ...[
                          // Status of Codes
                          Row(
                            children: [
                              Icon(
                                hasCodes ? Icons.check_circle : Icons.warning,
                                color: hasCodes ? Colors.green : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasCodes 
                                  ? "500 Codes Ready ${isSynced ? '(Synced)' : '(Pending Download)'}"
                                  : "No Offline Codes",
                                style: TextStyle(color: hasCodes ? Colors.green : Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Generate Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.download_for_offline),
                              label: const Text("Generate/Reset Offline Codes"),
                              onPressed: () => _generateOfflineCodes(internalId),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
    );
  }
}