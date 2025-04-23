import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// A Riverpod StreamProvider that listens to the 'users' collection in Firestore
// and provides a stream of a list of UserModel objects.

final usersProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users') // Access the 'users' collection in Firestore
      .snapshots() // Listen to real-time updates from Firestore
      .map((snapshot) => snapshot.docs // Map each document in the snapshot
      .map((doc) => UserModel.fromMap(doc.data())) // Convert Firestore data to UserModel
      .toList()); // Collect all UserModel objects into a list
});
