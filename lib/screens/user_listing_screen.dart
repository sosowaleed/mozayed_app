import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/screens/sell_screen.dart';
import 'edit_listing_screen.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Assume that listingsProvider has already loaded all listings.
    final listingsAsync = ref.watch(listingsProvider);
    final currentUserId = ref.watch(userDataProvider).value?['id'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("My Listings")),
      body: listingsAsync.when(
        data: (listings) {
          final myListings =
          listings.where((listing) => listing.ownerId == currentUserId).toList();
          if (myListings.isEmpty) {
            return const Center(child: Text("No listings found."));
          }
          return ListView.builder(
            itemCount: myListings.length,
            itemBuilder: (context, index) {
              final listing = myListings[index];
              return ListTile(
                leading: listing.image.isNotEmpty
                    ? Image.network(listing.image.first, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.image),
                title: Text(listing.title),
                subtitle: Text("\$${listing.price.toStringAsFixed(2)}"),
                trailing: Text("Sale Type: ${listing.saleType.name}"),
                onTap: () {
                  // Navigate to the EditListingScreen with this listing's data.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditListingScreen(listing: listing,),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
              MaterialPageRoute(builder: (context) => const SellScreen(showBackButton: true)), // Navigate to SellScreen with back button          );
          );
          },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
