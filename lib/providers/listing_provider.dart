import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';

class ListingsNotifier extends StateNotifier<AsyncValue<List<ListingItem>>> {
  ListingsNotifier() : super(const AsyncValue.loading()) {
    fetchListings();
  }

  Future<void> fetchListings() async {
    try {
      final querySnapshot =
      await FirebaseFirestore.instance.collection('listings').get();
      final listings = querySnapshot.docs
          .map((doc) => ListingItem.fromMap(doc.data()))
          .toList();
      state = AsyncValue.data(listings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addListing(ListingItem listing) async {
    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(listing.id)
          .set(listing.toMap());
      // If the listing is a bid listing, add a corresponding document in "bids".
      if (listing.saleType == SaleType.bid) {
        await FirebaseFirestore.instance
            .collection('bids')
            .doc(listing.id)
            .set({
          'listingId': listing.id,
          'ownerId': listing.ownerId,
          'bidEndTime': listing.bidEndTime?.toIso8601String(),
          'currentHighestBid': listing.startingBid ?? listing.price,
          'currentHighestBidderId': null,
          'bidHistory': [],
          'bidFinalized': false,
        });
      }
      // we have two options
      // Option 1: Re-fetch all listings
      await fetchListings();
      // Option 2: or, append the new listing to the current list.
    } catch (e) {
      rethrow;
    }
  }
  // updating the listings after adding a new listing.
  Future<void> updateListing(ListingItem updatedListing) async {
    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(updatedListing.id)
          .update(updatedListing.toMap());
      // If the listing is bid-enabled, update its bid data.
      if (updatedListing.saleType == SaleType.bid) {
        await FirebaseFirestore.instance
            .collection('bids')
            .doc(updatedListing.id)
            .update({
          'bidEndTime': updatedListing.bidEndTime?.toIso8601String(),
          'currentHighestBid': updatedListing.currentHighestBid,
          'currentHighestBidderId': updatedListing.currentHighestBidderId,
          'bidHistory': updatedListing.bidHistory,
          'bidFinalized': updatedListing.bidFinalized,
        });
      }
      // same options as above, re-fetch listings or update list locally.
      await fetchListings();
    } catch (e) {
      rethrow;
    }
  }


  // a method to fetch the current user's listings.
  Future<List<ListingItem>> fetchUserListings(String userId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('listings')
        .where('ownerId', isEqualTo: userId)
        .get();
    return querySnapshot.docs
        .map((doc) => ListingItem.fromMap(doc.data()))
        .toList();
  }
}

final listingsProvider =
StateNotifierProvider<ListingsNotifier, AsyncValue<List<ListingItem>>>(
        (ref) => ListingsNotifier());
