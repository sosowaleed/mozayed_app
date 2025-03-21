import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A StateNotifier that manages the current user's data.
class UserDataNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  UserDataNotifier() : super(const AsyncValue.loading()) {
    // Load the user data when the notifier is first created.
    loadUserData();
  }

  /// Loading the user data from Firestore.
  Future<void> loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      state = AsyncValue.data(doc.exists ? doc.data() : null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Updating the Firestore user document with the given [updates] and then reloads the user data.
  Future<void> updateUserData(Map<String, dynamic> updates) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update(updates);
      // After updating, reload the user data.
      await loadUserData();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the 'suspended' attribute for the current user.
  Future<bool?> fetchSuspended() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['suspended'] as bool?;
      }
      return null;
    } catch (e) {
      throw Exception("Error fetching suspended attribute: $e");
    }
  }

  /// Fetches the 'activated' attribute for the current user.
  Future<bool?> fetchActivated() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['activated'] as bool?;
      }
      return null;
    } catch (e) {
      throw Exception("Error fetching activated attribute: $e");
    }
  }
}

/// a Riverpod provider that exposes the [UserDataNotifier].
final userDataProvider =
StateNotifierProvider<UserDataNotifier, AsyncValue<Map<String, dynamic>?>>(
      (ref) => UserDataNotifier(),
);

// a stream provider that exposes the current user's authentication state.
final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
