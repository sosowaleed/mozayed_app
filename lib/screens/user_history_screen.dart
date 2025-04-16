import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/providers/orders_provider.dart';
import 'package:mozayed_app/providers/bids_provider.dart';
import 'package:mozayed_app/screens/listing_details_screen.dart';
import 'dart:typed_data';

class UserHistoryScreen extends ConsumerStatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  ConsumerState createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends ConsumerState<UserHistoryScreen> {
  // Change the cache to hold a list of images per listing.
  final Map<String, List<Uint8List?>> _imageCache = {};
  bool _isLoadingImages = true;

  // Helper function to get image bytes from Firebase Storage.
  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      return await ref.getData();
    } catch (e) {
      return null;
    }
  }

  // Prefetch all images for each listing.
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
    // Watch the listings provider.
    final listingsAsync = ref.watch(listingsProvider);
    // Watch the orders and bids providers.
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
              // Purchases Section.
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
                    final purchasedIds = purchasedOrders
                        .map((order) => order["listingId"])
                        .toSet();
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
                        final bidIds = bidDocs
                            .map<String>((bid) => bid["listingId"].toString())
                            .toSet();
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
                                  final listing = purchasedListings[index];
                                  final currentOrder =
                                  purchasedOrders.firstWhere((order) =>
                                  order["listingId"] == listing.id);
                                  return ListTile(
                                    shape: const Border(
                                      bottom: BorderSide(color: Colors.grey),
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
                                      _imageCache[listing.id]![
                                      0]!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                        : const Icon(Icons.error,
                                        size: 50)
                                        : const Icon(Icons.image, size: 50),
                                    title: AutoSizeText(listing.title),
                                    subtitle: AutoSizeText(
                                        "\$${listing.price.toStringAsFixed(2)} | Ordered Qty: ${currentOrder["quantity"]} | Ordered on: ${currentOrder["orderDate"]}"),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ListingDetailsScreen(
                                                listingItem: listing,
                                                // Pass the full cached list; if not available, pass an empty list.
                                                _imageCache[listing.id] ?? const [],
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const Divider(thickness: 2),
                            // Bids List.
                            // Purchases Section.
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: AutoSizeText(
                                "Bids",
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
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
                                        return "Your Bid: \$$userBid "
                                            "Current Highest Bid: \$${(listing.currentHighestBid ?? listing.startingBid ?? listing.price).toStringAsFixed(2)} | "
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
