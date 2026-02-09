import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final oldPinCtrl = TextEditingController();
  final newPinCtrl = TextEditingController();
  final confirmPinCtrl = TextEditingController();
  
  bool loading = false;

  Future<void> _updatePin() async {
    setState(() => loading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final oldPin = oldPinCtrl.text.trim();
    final newPin = newPinCtrl.text.trim();
    final confirm = confirmPinCtrl.text.trim();

    if (newPin.length < 4) {
      _msg("New PIN must be at least 4 digits", isError: true);
      setState(() => loading = false);
      return;
    }

    if (newPin != confirm) {
      _msg("New PINs do not match", isError: true);
      setState(() => loading = false);
      return;
    }

    try {
      // 1. Find the User's Box (Reverse Lookup)
      final boxQuery = await FirebaseFirestore.instance
          .collection('boxes')
          .where('assignedTo', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (boxQuery.docs.isEmpty) {
        _msg("No box found linked to your account", isError: true);
        setState(() => loading = false);
        return;
      }

      final boxDoc = boxQuery.docs.first;
      final currentPin = boxDoc.data()['pinHash'];

      // 2. Verify Old PIN
      if (oldPin != currentPin) {
        _msg("Incorrect Old PIN", isError: true);
        setState(() => loading = false);
        return;
      }

      // 3. Update to New PIN
      await FirebaseFirestore.instance
          .collection('boxes')
          .doc(boxDoc.id)
          .update({'pinHash': newPin});

      _msg("PIN updated successfully!");
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _msg("Error: $e", isError: true);
    }

    if (mounted) setState(() => loading = false);
  }

  void _msg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Change PIN'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            _input(oldPinCtrl, 'Old PIN'),
            const SizedBox(height: 16),
            _input(newPinCtrl, 'New PIN'),
            const SizedBox(height: 16),
            _input(confirmPinCtrl, 'Confirm New PIN'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : _updatePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Update PIN', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}