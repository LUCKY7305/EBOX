import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../admin/admin_screen.dart';
import '../auth/login_screen.dart';
import '../../widgets/bottom_nav.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _ensureUserInRTDB(User user) async {
    final userRef =
        FirebaseDatabase.instance.ref().child('users').child(user.uid);

    final snap = await userRef.get();

    if (!snap.exists) {
      await userRef.set({
        'email': user.email ?? '',
        'boxId': '',
        'createdAt': ServerValue.timestamp,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;

        // 🔓 Not logged in
        if (user == null) {
          return const LoginScreen();
        }

        // ✅ ENSURE USER EXISTS IN RTDB
        return FutureBuilder(
          future: _ensureUserInRTDB(user),
          builder: (context, rtdbSnap) {
            if (rtdbSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 👑 Check admin role (Firestore stays as-is)
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('admins')
                  .doc(user.uid)
                  .get(),
              builder: (context, adminSnap) {
                if (adminSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // 👑 Admin
                if (adminSnap.hasData && adminSnap.data!.exists) {
                  return const AdminScreen();
                }

                // 👤 Normal user
                return const MainNav();
              },
            );
          },
        );
      },
    );
  }
}
