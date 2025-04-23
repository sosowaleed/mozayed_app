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

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  // Helper function to prefetch all images for a given listing.
  Future<List<Uint8List?>> _prefetchListingImages(ListingItem listing) async {
    if (listing.image.isEmpty) return [];
    final futures = listing.image.map((url) async {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        return await ref.getData();
      } catch (e) {
        return null;
      }
    }).toList();
    return await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(listingsProvider);
    final currentUserId = ref.watch(userDataProvider).value?['id'];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text("My Listings",
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: listingsAsync.when(
        data: (listings) {
          final myListings = listings
              .where((listing) => listing.ownerId == currentUserId)
              .toList();
          if (myListings.isEmpty) {
            return const Center(child: Text("No listings found."));
          }
          return ListView.builder(
            itemCount: myListings.length,
            itemBuilder: (context, index) {
              final listing = myListings[index];
              return ListTile(
                shape:
                const Border(bottom: BorderSide(color: Colors.grey)),
                leading: listing.image.isNotEmpty
                    ? FutureBuilder<List<Uint8List?>>(
                  future: _prefetchListingImages(listing),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(
                              child:
                              CircularProgressIndicator()));
                    } else if (snapshot.hasError ||
                        snapshot.data == null ||
                        snapshot.data!.isEmpty ||
                        snapshot.data![0] == null) {
                      return const Icon(Icons.error, size: 50);
                    }
                    // Display the first prefetched image.
                    return Image.memory(
                      snapshot.data![0]!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    );
                  },
                )
                    : const Icon(Icons.image),
                title: Text(listing.title),
                subtitle: Text("SAR ${NumberFormat('#,##0.00').format(listing.price)}"),
                trailing: Text("Sale Type: ${listing.saleType.name}"),
                onTap: () {
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
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
              const SellScreen(showBackButton: true),
            ),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}