import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AdminSetupScreen extends StatefulWidget {
  final String boxId; // The internal Document ID of the box (e.g., 'box_123')
  const AdminSetupScreen({super.key, required this.boxId});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  bool _isLoading = false;
  String _status = "";

  // 1. GENERATOR FUNCTION
  List<String> _generateCodes(int count) {
    final rng = Random();
    final Set<String> codes = {};
    while (codes.length < count) {
      // Generate 6-digit number
      String code = (100000 + rng.nextInt(900000)).toString(); 
      codes.add(code);
    }
    return codes.toList();
  }

  // 2. UPLOAD LOGIC
  Future<void> _initializeBoxDatabase() async {
    setState(() { _isLoading = true; _status = "Generating 500 codes..."; });

    try {
      // A. Generate Master List
      List<String> allCodes = _generateCodes(500);
      
      // B. Split: First 10 (Current Batch) vs Remaining 490 (Reserve)
      List<String> currentBatch = allCodes.sublist(0, 10);
      List<String> reservePool = allCodes.sublist(10);

      // C. Update Firestore
      await FirebaseFirestore.instance.collection('boxes').doc(widget.boxId).update({
        // The active codes for Box/App to download
        'offlineCodes': currentBatch, 
        
        // The reserve pool (hidden from normal view)
        'codePool': reservePool,
        
        // SYNC FLAGS (Critical for your logic)
        'boxSynced': false, // Box hasn't downloaded these yet
        'appSynced': false, // App hasn't downloaded these yet
        
        // Reset Indices
        'offlineIndex': 0, // App starts at 0
      });

      setState(() { _status = "Success! 500 codes generated.\n10 are Active.\n490 are in Reserve."; });

    } catch (e) {
      setState(() { _status = "Error: $e"; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Setup")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Phase 14: System Initialization", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("This will generate 500 codes and set up the Sync Flags (appSynced/boxSynced)."),
              const SizedBox(height: 30),
              if (_isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _initializeBoxDatabase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)
                ),
                child: const Text("GENERATE 500 CODES"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}