import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/screens/sell_screen.dart';
import 'package:mozayed_app/screens/edit_listing_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

/// A screen that displays the current user's listings.
/// This screen uses Riverpod for state management and Firebase for image storage.
class MyListingsScreen extends ConsumerWidget {
  /// Constructor for the `MyListingsScreen` widget.
  const MyListingsScreen({super.key});

  /// Helper function to prefetch all images for a given listing.
  ///
  /// This function takes a `ListingItem` object and fetches all images
  /// associated with the listing from Firebase Storage.
  ///
  /// Returns a `Future` containing a list of `Uint8List?` objects, where each
  /// object represents the binary data of an image.
  Future<List<Uint8List?>> _prefetchListingImages(ListingItem listing) async {
    if (listing.image.isEmpty) return [];
    final futures = listing.image.map((url) async {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        return await ref.getData();
      } catch (e) {
        return null; // Return null if an error occurs while fetching the image.
      }
    }).toList();
    return await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the listings provider to fetch the list of all listings.
    final listingsAsync = ref.watch(listingsProvider);

    // Watches the user data provider to get the current user's ID.
    final currentUserId = ref.watch(userDataProvider).value?['id'];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "My Listings",
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: listingsAsync.when(
        // Handles the case when the data is successfully fetched.
        data: (listings) {
          // Filters the listings to only include those owned by the current user.
          final myListings = listings
              .where((listing) => listing.ownerId == currentUserId)
              .toList();

          // Displays a message if no listings are found.
          if (myListings.isEmpty) {
            return const Center(child: Text("No listings found."));
          }

          // Displays the user's listings in a scrollable list.
          return ListView.builder(
            itemCount: myListings.length,
            itemBuilder: (context, index) {
              final listing = myListings[index];
              return ListTile(
                shape: const Border(bottom: BorderSide(color: Colors.grey)),
                leading: listing.image.isNotEmpty
                    ? FutureBuilder<List<Uint8List?>>(
                        future: _prefetchListingImages(listing),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            // Displays a loading indicator while the image is being fetched.
                            return const SizedBox(
                              width: 50,
                              height: 50,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else if (snapshot.hasError ||
                              snapshot.data == null ||
                              snapshot.data!.isEmpty ||
                              snapshot.data![0] == null) {
                            // Displays an error icon if the image cannot be fetched.
                            return const Icon(Icons.error, size: 50);
                          }
                          // Displays the first prefetched image.
                          return Image.memory(
                            snapshot.data![0]!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : const Icon(Icons
                        .image), // Default icon if no images are available.
                title: Text(listing.title), // Displays the listing title.
                subtitle: Text(
                  "SAR ${NumberFormat('#,##0.00').format(listing.price)}",
                ), // Displays the listing price.
                trailing: Text(
                    "Sale Type: ${listing.saleType.name}"), // Displays the sale type.
                onTap: () {
                  // Navigates to the EditListingScreen when the listing is tapped.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditListingScreen(
                        listing: listing,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        // Displays a loading indicator while the data is being fetched.
        loading: () => const Center(child: CircularProgressIndicator()),
        // Displays an error message if an error occurs while fetching the data.
        error: (err, st) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigates to the SellScreen when the floating action button is pressed.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellScreen(showBackButton: true),
            ),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add), // Icon for the floating action button.
      ),
    );
  }
}
