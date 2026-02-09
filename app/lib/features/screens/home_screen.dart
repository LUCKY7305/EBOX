import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:intl/intl.dart';

// Make sure you have your HistoryScreen file imported or defined
import 'history_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Refresh UI every 5 seconds to update Online/Offline status
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // ==========================================
  // UI WIDGETS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      // AppBar (Admin Button Removed)
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        actions: [
          // History Button
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black54),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  final username = snapshot.data?.get('username') ?? 'User';
                  return _buildHeader(username);
                },
              ),

              const SizedBox(height: 24),

              // Main Box Stream
              StreamBuilder<QuerySnapshot>(
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
                    return _buildNoBoxState(context, user.uid);
                  }

                  final boxDoc = boxSnap.data!.docs.first;
                  final internalId = boxDoc.id;
                  final data = boxDoc.data() as Map<String, dynamic>;
                  final displayId = data['publicBoxId'] ?? data['boxId'] ?? 'Unknown ID';
                  final isLocked = data['isLocked'] ?? true;

                  // Online Logic (60 Second Timeout)
                  bool isOnline = false;
                  if (data.containsKey('lastSeen') && data['lastSeen'] != null) {
                    try {
                      final Timestamp lastSeen = data['lastSeen'];
                      final int diff = DateTime.now().difference(lastSeen.toDate()).inSeconds;
                      if (diff < 60) isOnline = true;
                    } catch (e) {
                      isOnline = false;
                    }
                  }

                  return Column(
                    children: [
                      _buildModernDashboard(
                        context, 
                        internalId, 
                        displayId, 
                        isLocked, 
                        isOnline
                      ),
                      
                      const SizedBox(height: 24),

                      // OFFLINE OTP CARD
                      if (!isOnline) 
                        _buildOfflineCard(context, internalId),
                      
                      // Helper text when Online
                      if (isOnline)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "Device is Online. Use the standard Unlock button above.", 
                            style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(String username) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back,',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          username,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModernDashboard(BuildContext context, String internalId, String displayId, bool isLocked, bool isOnline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Box Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Box Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
                  Text("ID: $displayId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statusItem(
                    icon: Icons.wifi,
                    label: "Network",
                    value: isOnline ? "Online" : "Offline",
                    color: isOnline ? Colors.blue : Colors.grey,
                    bgColor: isOnline ? Colors.blue.shade50 : Colors.grey.shade100,
                  ),
                  _statusItem(
                    icon: isLocked ? Icons.lock : Icons.lock_open,
                    label: "Security",
                    value: isLocked ? "Locked" : "Unlocked",
                    color: isLocked ? Colors.green : Colors.orange,
                    bgColor: isLocked ? Colors.green.shade50 : Colors.orange.shade50,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Quick Access
        const Text(
          "Quick Access",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLocked ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isLocked ? Icons.lock : Icons.lock_open,
                  size: 32,
                  color: isLocked ? Colors.blue : Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLocked ? "Box is Locked" : "Box is Unlocked",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocked ? "Tap to unlock" : "Tap to secure box",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocked ? Colors.blue : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: isOnline 
                    ? () => _showPinVerifyPopup(context, internalId, isLocked)
                    : null, 
                child: Text(isLocked ? "Unlock" : "Lock"),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineCard(BuildContext context, String boxId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.password, color: Colors.purple.shade400),
              const SizedBox(width: 12),
              const Text(
                "Offline Access",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Box offline? Generate a temporary access code.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              // 🔥 UPDATED: Call the New Logic
              onPressed: () => _showOfflinePinDialog(context, boxId),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.purple.shade200),
                foregroundColor: Colors.purple,
              ),
              child: const Text("Get One-Time Code"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusItem({
    required IconData icon, 
    required String label, 
    required String value, 
    required Color color,
    required Color bgColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  // --- NEW OFFLINE PIN LOGIC (FETCH & POP) ---
  void _showOfflinePinDialog(BuildContext context, String boxId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        // Local state for the dialog
        String? fetchedPin;
        bool loading = false;
        String? errorMsg;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Logic to Fetch
            Future<void> fetchPin() async {
              setDialogState(() { loading = true; errorMsg = null; });
              try {
                final docRef = FirebaseFirestore.instance.collection('boxes').doc(boxId);
                
                await FirebaseFirestore.instance.runTransaction((transaction) async {
                  DocumentSnapshot snapshot = await transaction.get(docRef);
                  if (!snapshot.exists) throw Exception("Box not found");
                  
                  Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
                  List<dynamic> codes = data['offlineCodes'] ?? [];

                  if (codes.isEmpty) {
                    throw Exception("No codes available. Please connect box to WiFi to refill.");
                  }

                  String nextPin = codes.first.toString();
                  List<dynamic> newCodesList = codes.sublist(1);

                  transaction.update(docRef, {'offlineCodes': newCodesList});
                  
                  setDialogState(() { fetchedPin = nextPin; });
                });
              } catch (e) {
                setDialogState(() { errorMsg = e.toString().replaceAll("Exception:", ""); });
              } finally {
                setDialogState(() { loading = false; });
              }
            }

            return AlertDialog(
              title: const Text("Offline Access Code"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (fetchedPin == null && !loading && errorMsg == null)
                    const Text("Generate a one-time PIN? This will remove it from the database."),
                  
                  if (loading)
                    const CircularProgressIndicator(),

                  if (errorMsg != null)
                    Text(errorMsg!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),

                  if (fetchedPin != null) ...[
                    const Text("Enter this on Keypad:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    Text(fetchedPin!, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.blue)),
                    const SizedBox(height: 10),
                    const Text("Valid once. Previous unused codes will be invalidated by the device.", style: TextStyle(fontSize: 12, color: Colors.orange), textAlign: TextAlign.center),
                  ]
                ],
              ),
              actions: [
                if (fetchedPin == null && !loading)
                  ElevatedButton(onPressed: fetchPin, child: const Text("Generate")),
                
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- EXISTING CONNECT POPUPS ---
  Widget _buildNoBoxState(BuildContext context, String userId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Icon(Icons.add_link, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text("No Box Connected", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text("Enter your EBOX ID to get started", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showConnectPopup(context, userId),
              child: const Text("Connect Box"),
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectPopup(BuildContext context, String userId) {
    final boxIdCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;
    bool loading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Connect Box'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMsg != null) Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                  TextField(controller: boxIdCtrl, decoration: const InputDecoration(labelText: 'EBOX ID')),
                  TextField(controller: pinCtrl, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
                  TextField(controller: confirmCtrl, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Confirm PIN')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: loading ? null : () async {
                  setState(() { loading = true; errorMsg = null; });
                  try {
                      final publicId = boxIdCtrl.text.trim();
                      var query = await FirebaseFirestore.instance.collection('boxes').where('publicBoxId', isEqualTo: publicId).limit(1).get();
                      if (query.docs.isEmpty) query = await FirebaseFirestore.instance.collection('boxes').where('boxId', isEqualTo: publicId).limit(1).get();
                      
                      if (query.docs.isEmpty) { setState(() { loading = false; errorMsg = "Invalid ID"; }); return; }
                      
                      final boxDoc = query.docs.first;
                      final data = boxDoc.data();
                      if (data.containsKey('assignedTo') && data['assignedTo'] != null && data['assignedTo'] != "") {
                          setState(() { loading = false; errorMsg = "Assigned"; }); return;
                      }

                      await FirebaseFirestore.instance.collection('boxes').doc(boxDoc.id).update({
                        'assignedTo': userId, 
                        'pinHash': pinCtrl.text.trim(),
                        'isLocked': true,
                        'command': 'LOCK', 
                      });
                      if (context.mounted) Navigator.pop(dialogContext);
                  } catch (e) { setState(() { loading = false; errorMsg = "$e"; }); }
                },
                child: const Text('Connect'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showPinVerifyPopup(BuildContext context, String internalId, bool currentLockState) {
    final pinCtrl = TextEditingController();
    String? errorMsg;
    bool loading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(currentLockState ? 'Unlock' : 'Lock'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
               if (errorMsg != null) Text(errorMsg!, style: const TextStyle(color: Colors.red)),
               TextField(controller: pinCtrl, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: loading ? null : () async {
                  setState(() => loading = true);
                  try {
                    final boxRef = FirebaseFirestore.instance.collection('boxes').doc(internalId);
                    final boxSnap = await boxRef.get();
                    final data = boxSnap.data();
                    final storedPin = (data != null && data.containsKey('pinHash')) ? data['pinHash'] : null;
                    
                    if (pinCtrl.text.trim() != storedPin) { setState(() { loading = false; errorMsg = "Wrong PIN"; }); return; }

                    final newStatus = !currentLockState;
                    await boxRef.update({'isLocked': newStatus, 'command': newStatus ? 'LOCK' : 'UNLOCK'});
                    await boxRef.collection('history').add({'action': newStatus ? 'CLOSE' : 'OPEN', 'timestamp': FieldValue.serverTimestamp(), 'userId': FirebaseAuth.instance.currentUser!.uid});
                    if (context.mounted) Navigator.pop(dialogContext);
                  } catch (e) { setState(() { loading = false; errorMsg = "$e"; }); }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        });
      },
    );
  }
}