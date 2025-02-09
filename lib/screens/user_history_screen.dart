import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/providers/orders_provider.dart';
import 'package:mozayed_app/providers/bids_provider.dart';
import 'package:mozayed_app/screens/listing_details_screen.dart';

class UserHistoryScreen extends ConsumerStatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  ConsumerState createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends ConsumerState<UserHistoryScreen> {

  @override
  Widget build(BuildContext context) {
    // Watch the listings provider.
    final listingsAsync = ref.watch(listingsProvider);
    // Watch the orders and bids providers.
    final ordersAsync = ref.watch(ordersProvider);
    final bidsAsync = ref.watch(bidsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const AutoSizeText('User History'),
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
                child: AutoSizeText("Purchases", style: TextStyle(fontSize: 20)),
              ),
              Expanded(
                child: ordersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: AutoSizeText("Error loading orders: $error")),
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
                    final purchasedSet = purchasedIds.toSet();
                    final purchasedListings = allListings
                        .where((listing) => purchasedSet.contains(listing.id))
                        .toList();
                    if (purchasedListings.isEmpty) {
                      return const Center(child: AutoSizeText("No purchases found."));
                    }
                    return ListView.builder(
                      itemCount: purchasedListings.length,
                      itemBuilder: (context, index) {
                        final listing = purchasedListings[index];
                        //get the data needed from the current purchase order.
                        final currentOrder = purchasedOrders.firstWhere((order) => order["listingId"] == listing.id);
                        return ListTile(
                          leading: listing.image.isNotEmpty
                              ? Image.network(
                            listing.image.first,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                              : const Icon(Icons.image),
                          title: AutoSizeText(listing.title),
                          subtitle: AutoSizeText(
                              "\$${listing.price.toStringAsFixed(2)} | Ordered Qty: ${currentOrder["quantity"]} | Ordered on: ${currentOrder["orderDate"]}"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ListingDetailsScreen(listingItem: listing),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(thickness: 2),
              // Current Bids Section.
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: AutoSizeText("Current Bids", style: TextStyle(fontSize: 20)),
              ),
              Expanded(
                child: bidsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: AutoSizeText("Error loading bids: $error")),
                  data: (bidDocs) {
                    // Extract listing IDs from bid documents.
                    final bidIds = bidDocs
                        .map<String>((bid) => bid["listingId"].toString())
                        .toSet()
                        .toList();
                    final bidListings = allListings
                        .where((listing) => bidIds.contains(listing.id))
                        .toList();
                    if (bidListings.isEmpty) {
                      return const Center(child: AutoSizeText("No current bids found."));
                    }
                    return ListView.builder(
                      itemCount: bidListings.length,
                      itemBuilder: (context, index) {
                        final listing = bidListings[index];
                        return ListTile(
                          subtitle: bidsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stack) =>
                                Center(child: AutoSizeText("Error loading bids: $error")),
                            data: (bidDocs) {
                              final userBidHistory = bidDocs.firstWhere(
                                      (bid) => bid["listingId"].toString() == listing.id,
                                  orElse: () => {"bidHistory": []})["bidHistory"] as List<dynamic>;

                              final userBid = userBidHistory.last["bidAmount"];
                              return AutoSizeText(
                                  "Your Bid: \$$userBid "
                                      "Current Highest Bid: \$${(listing.currentHighestBid ?? listing.startingBid ?? listing.price).toStringAsFixed(2)} | "
                                      "End Date: ${listing.bidEndTime}");
                            },
                          ),



                          leading: listing.image.isNotEmpty
                              ? Image.network(
                            listing.image.first,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                              : const Icon(Icons.image),
                          title: AutoSizeText(listing.title),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ListingDetailsScreen(listingItem: listing),
                              ),
                            );
                          },
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
