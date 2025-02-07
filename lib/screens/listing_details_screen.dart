import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/cart_provider.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';

class ListingDetailsScreen extends StatefulWidget {
  final ListingItem listingItem;
  const ListingDetailsScreen({super.key, required this.listingItem});

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
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

  void _handleBuy(WidgetRef ref) {
    // Add listing to cart
    ref.read(cartProvider.notifier).addToCart(widget.listingItem);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Item added to cart")),
    );
  }

  void _handleBid() async {
    double? enteredBid = double.tryParse(_bidController.text);
    double currentBid = widget.listingItem.currentHighestBid ??
        widget.listingItem.startingBid ??
        widget.listingItem.price;
    if (enteredBid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid bid.")),
      );
      return;
    }
    if (enteredBid <= currentBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Your bid must be higher than \$${currentBid.toStringAsFixed(2)}"),
        ),
      );
      return;
    }

    // Show confirmation dialog.
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Bid"),
        content: Text("Are you sure you want to bid \$${enteredBid.toStringAsFixed(2)}?"),
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      await Future.delayed(const Duration(seconds: 3));
      Navigator.of(context).pop(); // Remove the progress dialog
      //TODO: update backed with new bid
      // For example, update the "bids" collection with this new bid.
      // For demonstration, we show a snackbar:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bid of \$${enteredBid.toStringAsFixed(2)} placed!")),
      );
      // Clear the bid input.
      _bidController.clear();
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
    return Consumer(builder: (context, ref, child) {
      final user = UserModel.fromMap(ref.read(userDataProvider).value!);
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(listing.title, style: const TextStyle(fontSize: 18)),
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
                      color: Colors.white,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.black38),
                      ),
                    ),
                  ),
                  // Right Arrow.
                  Positioned(
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 30),
                      onPressed: _nextImage,
                      color: Colors.white,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.black38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Metadata Section.
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                    "Condition: ${listing.condition}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Price: \$${listing.price.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Quantity: ${listing.quantity}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  // Distance Indicator.
                  Text(
                    "Distance: ${(Geolocator.distanceBetween(
                      user.location.lat,
                      user.location.lng,
                      widget.listingItem.location!.lat,
                      widget.listingItem.location!.lng,
                    ) /
                        1000).toStringAsFixed(1)} km",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Description:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        listing.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ]
              ),
            ),
            const Spacer(),
            // Bid/Buy Button Area.
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: listing.saleType == SaleType.bid
                  ? Column(
                children: [
                  Text(
                    "Current Highest Bid: \$${(listing.currentHighestBid ?? listing.startingBid ?? listing.price).toStringAsFixed(2)}",
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
                    onPressed: () => _handleBid(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 0),
                      fixedSize: Size(
                        MediaQuery.of(context).size.width,
                        40,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Bid", style: TextStyle(fontSize: 16)),
                  ),
                ],
              )
                  : ElevatedButton(
                onPressed: () => _handleBuy(ref),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 0),
                  fixedSize: Size(
                    MediaQuery.of(context).size.width,
                    40,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Buy", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    });
  }
}
