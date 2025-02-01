import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
  return doc.exists ? doc.data() : null;
});