import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';

final bidsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userDataAsync = ref.watch(userDataProvider);

  // If user data isn't ready, return an empty stream.
  if (userDataAsync.asData == null ||
      userDataAsync.asData!.value == null ||
      userDataAsync.asData!.value?["id"] == null) {
    return Stream.value([]);
  }

  final userId = userDataAsync.asData!.value!["id"];

  // Listen to real-time updates in the "bids" collection.
  return FirebaseFirestore.instance
      .collection("bids")
      .snapshots()
      .map((snapshot) {
    // Map each document into its data.
    final allBids = snapshot.docs.map((doc) => doc.data()).toList();

    // Filter documents client-side.
    final userBids = allBids.where((bidData) {
      bool inHistory = false;
      if (bidData["bidHistory"] is List) {
        final history = bidData["bidHistory"] as List<dynamic>;
        inHistory = history.any((entry) {
          if (entry is Map<String, dynamic>) {
            return entry["bidderId"] == userId;
          }
          return false;
        });
      }
      bool isHighestBidder = bidData["currentHighestBidderId"] == userId;
      return inHistory || isHighestBidder;
    }).toList();

    return userBids;
  });
});