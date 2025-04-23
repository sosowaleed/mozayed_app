import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/providers/orders_provider.dart';
import 'package:mozayed_app/providers/bids_provider.dart';
import 'package:mozayed_app/screens/listing_details_screen.dart';
import 'dart:typed_data';

/// A screen that displays the user's purchase and bid history.
/// It fetches data from providers and preloads images for listings.
class UserHistoryScreen extends ConsumerStatefulWidget {
  /// Constructor for the `UserHistoryScreen`.
  const UserHistoryScreen({super.key});

  @override
  ConsumerState createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends ConsumerState<UserHistoryScreen> {
  /// A cache to store images for listings, where the key is the listing ID
  /// and the value is a list of image bytes.
  final Map<String, List<Uint8List?>> _imageCache = {};

  /// A flag to indicate whether images are still being loaded.
  bool _isLoadingImages = true;

  /// Fetches image bytes from Firebase Storage for a given image URL.
  ///
  /// Returns the image bytes as `Uint8List` or `null` if an error occurs.
  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      return await ref.getData();
    } catch (e) {
      return null;
    }
  }

  /// Prefetches all images for the provided list of listings.
  ///
  /// This method populates the `_imageCache` with the images for each listing.
  Future<void> _prefetchImages(List<ListingItem> listings) async {
    await Future.wait(listings.map((listing) async {
      if (listing.image.isNotEmpty) {
        // Fetch every image for this listing.
        final futures =
            listing.image.map((url) => _getImageBytes(url)).toList();
        _imageCache[listing.id] = await Future.wait(futures);
      } else {
        _imageCache[listing.id] = [];
      }
    }));
    setState(() {
      _isLoadingImages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the listings provider to get all listings.
    final listingsAsync = ref.watch(listingsProvider);

    // Watch the orders and bids providers to get user-specific data.
    final ordersAsync = ref.watch(ordersProvider);
    final bidsAsync = ref.watch(bidsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: AutoSizeText(
          'User History',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: AutoSizeText("Error loading listings: $error")),
        data: (allListings) {
          // Build the UI once listings are loaded.
          return Column(
            children: [
              // Purchases Section Header.
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: AutoSizeText(
                  "Purchases",
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Expanded(
                child: ordersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                      child: AutoSizeText("Error loading orders: $error")),
                  data: (orders) {
                    // Flatten all purchased items from each order's "items" array.
                    final List<Map<String, dynamic>> purchasedOrders = [];
                    for (var order in orders) {
                      if (order["items"] is List) {
                        for (var item in order["items"]) {
                          if (item is Map && item.containsKey("listingId")) {
                            purchasedOrders.add({
                              "listingId": item["listingId"].toString(),
                              "quantity": item["quantity"] ?? 1,
                              "orderDate": order["orderTime"],
                            });
                          }
                        }
                      }
                    }
                    // Extract unique listing IDs from purchased orders.
                    final purchasedIds = purchasedOrders
                        .map((order) => order["listingId"])
                        .toSet();

                    // Filter listings that match the purchased IDs.
                    final purchasedListings = allListings
                        .where((listing) => purchasedIds.contains(listing.id))
                        .toList();

                    // Process bids.
                    return bidsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                          child: AutoSizeText("Error loading bids: $error")),
                      data: (bidDocs) {
                        // Extract unique listing IDs from bids.
                        final bidIds = bidDocs
                            .map<String>((bid) => bid["listingId"].toString())
                            .toSet();

                        // Filter listings that match the bid IDs.
                        final bidListings = allListings
                            .where((listing) => bidIds.contains(listing.id))
                            .toList();

                        // Combine listings from both purchases and bids into one union.
                        final Map<String, ListingItem> unionMap = {};
                        for (var listing in purchasedListings) {
                          unionMap[listing.id] = listing;
                        }
                        for (var listing in bidListings) {
                          unionMap[listing.id] = listing;
                        }
                        final unionListings = unionMap.values.toList();

                        // Prefetch images for all union listings if not done already.
                        if (_isLoadingImages && unionListings.isNotEmpty) {
                          _prefetchImages(unionListings);
                        }

                        return Column(
                          children: [
                            // Purchases List.
                            purchasedListings.isEmpty
                                ? const Expanded(
                                    child: Center(
                                        child: Text("No Purchases yet",
                                            style: TextStyle(fontSize: 20))))
                                : Expanded(
                                    child: ListView.builder(
                                      itemCount: purchasedListings.length,
                                      itemBuilder: (context, index) {
                                        final listing =
                                            purchasedListings[index];
                                        final currentOrder = purchasedOrders
                                            .firstWhere((order) =>
                                                order["listingId"] ==
                                                listing.id);
                                        return ListTile(
                                          shape: const Border(
                                            bottom:
                                                BorderSide(color: Colors.grey),
                                          ),
                                          leading: listing.image.isNotEmpty
                                              ? _isLoadingImages
                                                  ? const SizedBox(
                                                      width: 50,
                                                      height: 50,
                                                      child: Center(
                                                          child:
                                                              CircularProgressIndicator()),
                                                    )
                                                  : (_imageCache[listing.id]
                                                              ?.isNotEmpty ??
                                                          false)
                                                      ? Image.memory(
                                                          // Show the first image.
                                                          _imageCache[
                                                              listing.id]![0]!,
                                                          width: 50,
                                                          height: 50,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : const Icon(Icons.error,
                                                          size: 50)
                                              : const Icon(Icons.image,
                                                  size: 50),
                                          title: AutoSizeText(listing.title),
                                          subtitle: AutoSizeText(
                                              "${NumberFormat('#,##0.00').format(listing.price)} | Ordered Qty: ${currentOrder["quantity"]} | Ordered on: ${currentOrder["orderDate"]}"),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ListingDetailsScreen(
                                                  listingItem: listing,
                                                  // Pass the full cached list; if not available, pass an empty list.
                                                  _imageCache[listing.id] ??
                                                      const [],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                            const Divider(thickness: 2),
                            // Bids Section Header.
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: AutoSizeText(
                                "Bids",
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                            // Bids List.
                            bidListings.isEmpty
                                ? const Expanded(
                                    child: Center(
                                        child: Text("No bids yet",
                                            style: TextStyle(fontSize: 20))))
                                : Expanded(
                                    child: ListView.builder(
                                      itemCount: bidListings.length,
                                      itemBuilder: (context, index) {
                                        final listing = bidListings[index];
                                        return ListTile(
                                          shape: const Border(
                                              bottom: BorderSide(
                                                  color: Colors.grey)),
                                          subtitle: AutoSizeText(
                                            () {
                                              final userBidHistory =
                                                  bidDocs.firstWhere(
                                                          (bid) =>
                                                              bid["listingId"]
                                                                  .toString() ==
                                                              listing.id,
                                                          orElse: () => {
                                                                "bidHistory": []
                                                              })["bidHistory"]
                                                      as List<dynamic>;
                                              final userBid = userBidHistory
                                                  .last["bidAmount"];
                                              return "Your Bid: \$${NumberFormat('#,##0.00').format(userBid)} "
                                                  "Current Highest Bid: \$${NumberFormat('#,##0.00').format(listing.currentHighestBid ?? listing.startingBid ?? listing.price)} | "
                                                  "End Date: ${listing.bidEndTime}";
                                            }(),
                                          ),
                                          leading: listing.image.isNotEmpty
                                              ? _isLoadingImages
                                                  ? const SizedBox(
                                                      width: 50,
                                                      height: 50,
                                                      child: Center(
                                                          child:
                                                              CircularProgressIndicator()),
                                                    )
                                                  : (_imageCache[listing.id]
                                                              ?.isNotEmpty ??
                                                          false)
                                                      ? Image.memory(
                                                          _imageCache[
                                                              listing.id]![0]!,
                                                          width: 50,
                                                          height: 50,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : const Icon(Icons.error,
                                                          size: 50)
                                              : const Icon(Icons.image,
                                                  size: 50),
                                          title: AutoSizeText(listing.title),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ListingDetailsScreen(
                                                  listingItem: listing,
                                                  // Pass all cached images if available.
                                                  _imageCache[listing.id] ??
                                                      const [],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
