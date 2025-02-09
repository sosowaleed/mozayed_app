import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';

final ordersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userDataAsync = ref.watch(userDataProvider);

  // If user data isn't available yet, return an empty stream.
  if (userDataAsync.asData == null ||
      userDataAsync.asData!.value == null ||
      userDataAsync.asData!.value?["id"] == null) {
    return Stream.value([]);
  }

  final userId = userDataAsync.asData!.value!["id"];

  // Listen to real-time updates in the "orders" collection for the current user.
  return FirebaseFirestore.instance
      .collection("orders")
      .where("userId", isEqualTo: userId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});