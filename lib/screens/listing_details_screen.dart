import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/cart_provider.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';

class ListingDetailsScreen extends ConsumerStatefulWidget {
  final ListingItem listingItem;
  const ListingDetailsScreen({super.key, required this.listingItem});

  @override
  ConsumerState<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends ConsumerState<ListingDetailsScreen> {
  int _currentImageIndex = 0;
  final TextEditingController _bidController = TextEditingController();

  void _previousImage() {
    setState(() {
      if (_currentImageIndex > 0) {
        _currentImageIndex--;
      } else {
        _currentImageIndex = widget.listingItem.image.length - 1;
      }
    });
  }

  void _nextImage() {
    setState(() {
      if (_currentImageIndex < widget.listingItem.image.length - 1) {
        _currentImageIndex++;
      } else {
        _currentImageIndex = 0;
      }
    });
  }

  void _handleBuy() {
    // Add listing to cart.
    ref.read(cartProvider.notifier).addToCart(widget.listingItem);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Item added to cart"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleBid(UserModel user) async {
    double? enteredBid = double.tryParse(_bidController.text);
    double currentBid = widget.listingItem.currentHighestBid ??
        widget.listingItem.startingBid ??
        widget.listingItem.price;
    if (enteredBid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid bid."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (enteredBid <= currentBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Your bid must be higher than SAR ${currentBid.toStringAsFixed(2)}"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (DateTime.now().isAfter(widget.listingItem.bidEndTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bid time has expired."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show confirmation dialog.
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Bid"),
        content: Text("Are you sure you want to bid SAR ${enteredBid.toStringAsFixed(2)}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show a progress indicator for 3 seconds.
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pop(); // Remove the progress indicator
      }

      // Update the listing with the new bid:
      // Here, we assume ListingItem has methods to update bid values.
      widget.listingItem.setCurrentHighestBid(enteredBid);
      widget.listingItem.setCurrentHighestBidderId(user.id);
      widget.listingItem.setBidHistory({
        'bidderId': user.id,
        'bidAmount': enteredBid,
        'bidTime': DateTime.now().toIso8601String(),
      });

      await ref.read(listingsProvider.notifier).updateListing(widget.listingItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bid of SAR ${enteredBid.toStringAsFixed(2)} placed!"),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      _bidController.clear();
      if (mounted) {
        Navigator.of(context).pop(); // Optionally pop back to the previous screen.
      }
    }
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listingItem;
    final user = UserModel.fromMap(ref.read(userDataProvider).value!);
    final theme = Theme.of(context);

    // Sort the bid history (if any) descending by bidAmount.
    final List<Map<String, dynamic>> sortedBidHistory = List<Map<String, dynamic>>.from(listing.bidHistory ?? []);
    sortedBidHistory.sort((a, b) {
      final bidA = a['bidAmount'] as num;
      final bidB = b['bidAmount'] as num;
      return bidB.compareTo(bidA);
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          listing.title,
          style: TextStyle(fontSize: 18, color: theme.appBarTheme.titleTextStyle?.color),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Image Section with arrows.
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    listing.image[_currentImageIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                // Left Arrow.
                Positioned(
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 30),
                    onPressed: _previousImage,
                    color: theme.colorScheme.onPrimary,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(theme.colorScheme.secondary.withOpacity(0.5)),
                    ),
                  ),
                ),
                // Right Arrow.
                Positioned(
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 30),
                    onPressed: _nextImage,
                    color: theme.colorScheme.onPrimary,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(theme.colorScheme.secondary.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Metadata Section.
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Condition: ${listing.condition}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Price: SAR ${listing.price.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Quantity: ${listing.quantity}",
                    style: TextStyle(fontSize: 16, color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  // Distance Indicator.
                  if (listing.location != null)
                    Text(
                      "Distance: ${(Geolocator.distanceBetween(
                        user.location.lat,
                        user.location.lng,
                        listing.location!.lat,
                        listing.location!.lng,
                      ) / 1000).toStringAsFixed(1)} km",
                      style: TextStyle(fontSize: 16, color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 2),
                                  // Bid End Date
                  if (listing.saleType == SaleType.bid) ...[
                    Text(
                      "Bid End Date: ${listing.bidEndTime!.toLocal().toString().substring(0, 16)}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.error),
                    ),
                  const SizedBox(height: 10),],
                  Text(
                    "Description:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge!.color),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        listing.description,
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge!.color),
                      ),
                    ),
                  ),
                  // New: Bidders List Section (only for bid listings)
                  if (listing.saleType == SaleType.bid) ...[
                    const SizedBox(height: 10),
                    Text(
                      "Bidders (Highest to Lowest):",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge!.color),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 120,
                      child: sortedBidHistory.isEmpty
                          ? const Center(child: Text("No bids yet."))
                          : ListView.builder(
                        itemCount: sortedBidHistory.length,
                        itemBuilder: (context, index) {
                          final bidEntry = sortedBidHistory[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.account_circle),
                            title: Text(
                              "Bid: SAR ${(bidEntry['bidAmount'] as num).toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              "Time: ${bidEntry['bidTime']}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 5,),
          // Bid/Buy Button Area.
          Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: listing.saleType == SaleType.bid
                ? Column(
              children: [
                Text(
                  "Current Highest Bid: SAR ${(listing.currentHighestBid ?? listing.startingBid ?? listing.price).toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bidController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Enter your bid",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _handleBid(user),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 0),
                    fixedSize: Size(MediaQuery.of(context).size.width, 40),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    backgroundColor: theme.colorScheme.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text("Bid", style: TextStyle(fontSize: 16, color: theme.colorScheme.onPrimary)),
                ),
              ],
            )
                : ElevatedButton(
              onPressed: _handleBuy,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0),
                fixedSize: Size(MediaQuery.of(context).size.width, 40),
                padding: const EdgeInsets.symmetric(vertical: 2),
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Buy", style: TextStyle(fontSize: 18, color: theme.colorScheme.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
