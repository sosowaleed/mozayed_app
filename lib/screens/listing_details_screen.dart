import 'dart:developer';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/cart_provider.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

class ListingDetailsScreen extends ConsumerStatefulWidget {
  final ListingItem listingItem;
  final List<Uint8List?> _imageBytesCache;
  final bool adminInfo;
  const ListingDetailsScreen(this._imageBytesCache, {super.key, required this.listingItem, this.adminInfo = false});

  @override
  ConsumerState<ListingDetailsScreen> createState() =>
      _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends ConsumerState<ListingDetailsScreen> {
  int _currentImageIndex = 0;
  final TextEditingController _bidController = TextEditingController();

  // Controllers for the report form.
  String? _selectedReportCategory;
  String? _selectedFlag;
  final TextEditingController _reportedValueController =
  TextEditingController();
  final TextEditingController _reportDescriptionController =
  TextEditingController();

  // Dropdown options.
  final List<String> _reportCategoriesForNonBid = ["User", "Item"];
  final List<String> _reportCategoriesForBid = ["User", "Item", "Bid"];

  final Map<String, List<String>> _flagOptions = {
    "User": ["Not responding", "Location distant was false", "Other"],
    "Item": ["Condition worse than advertised", "Item sold was different", "Other"],
    "Bid": ["Illegitimate bid", "Not responding", "Other"],
  };
  // Local cache for image bytes.
  List<Uint8List?> _localCache = [];
  bool _isLocalCacheLoading = true;

  @override
  void initState() {
    super.initState();
    // If the cache passed from the ListingWidget is not empty, use it.
    if (widget._imageBytesCache.isNotEmpty) {
      _localCache = widget._imageBytesCache;
      _isLocalCacheLoading = false;
    } else {
      _prefetchImages();
    }
  }

  Future<void> _prefetchImages() async {
    final futures = widget.listingItem.image.map((url) => _getImageBytes(url)).toList();
    _localCache = await Future.wait(futures);
    setState(() {
      _isLocalCacheLoading = false;
    });
  }

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

  // Helper function to get image bytes from Firebase Storage
  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      return await ref.getData();
    } catch (e) {
      return null;
    }
  }

  void _handleBuy() {
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
          content: Text(
              "Your bid must be higher than SAR ${NumberFormat('#,##0.00').format(currentBid)}"),
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
        content:
        Text("Are you sure you want to bid SAR ${NumberFormat('#,##0.00').format(enteredBid)}?"),
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
      if (mounted){
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
        await Future.delayed(const Duration(seconds: 3));
      }
      if (mounted){
        Navigator.of(context).pop(); // Remove the progress indicator
      }

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
            content: Text("Bid of SAR ${NumberFormat('#,##0.00').format(enteredBid)} placed!"),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      _bidController.clear();
      if (mounted) {
        Navigator.of(context).pop(); // Optionally pop back to previous screen.
      }
    }
  }

  // Function to open the Report overlay.
  Future<void> _showReportDialog(UserModel reporter) async {
    // Set default category based on sale type.
    _selectedReportCategory = widget.listingItem.saleType == SaleType.bid
        ? _reportCategoriesForBid.first
        : _reportCategoriesForNonBid.first;
    _selectedFlag = _flagOptions[_selectedReportCategory!]!.first;
    _reportedValueController.clear();
    _reportDescriptionController.clear();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report"),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              // Get the flag options based on selected category.
              final flagOptions = _flagOptions[_selectedReportCategory!]!;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Dropdown.
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Category"),
                      value: _selectedReportCategory,
                      items: (widget.listingItem.saleType == SaleType.bid
                          ? _reportCategoriesForBid
                          : _reportCategoriesForNonBid)
                          .map((category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedReportCategory = value;
                          _selectedFlag = _flagOptions[value!]!.first;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    // Flag Dropdown.
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Flag"),
                      value: _selectedFlag,
                      items: flagOptions
                          .map((flag) => DropdownMenuItem<String>(
                        value: flag,
                        child: Text(flag),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFlag = value;
                        });
                      },
                    ),

                    const SizedBox(height: 10),
                    // Description Text Field.
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: "Description",
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      controller: _reportDescriptionController,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close without saving.
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                // Build report document with all required details.
                final listing = widget.listingItem;
                final reportData = {
                  "category": _selectedReportCategory,
                  "flag": _selectedFlag,
                  "description": _reportDescriptionController.text,
                  "reporterId": reporter.id,
                  "reporterEmail": reporter.email,
                  // Listing details.
                  "listingId": listing.id,
                  "listingTitle": listing.title,
                  "listingOwnerId": listing.ownerId,
                  "listingOwnerName": listing.ownerName,
                  "listingCondition": listing.condition,
                  "handled": false,
                  "image": listing.image,
                  // Include currentHighestBidderId if the saleType is bid.
                  if (listing.saleType == SaleType.bid && listing.currentHighestBidderId != null)
                    "currentHighestBidderId": listing.currentHighestBidderId,
                  "timestamp": DateTime.now().toIso8601String(),
                };

                try {
                  await FirebaseFirestore.instance
                      .collection("reports")
                      .add(reportData);
                  log("Report saved with details: $reportData");
                } catch (error) {
                  log("Error saving report: $error");
                }
                Navigator.of(context).pop(); // Close the dialog.
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Report Sent Successfully!"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }


  @override
  void dispose() {
    _bidController.dispose();
    _reportedValueController.dispose();
    _reportDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listingItem;
    final user = UserModel.fromMap(ref.read(userDataProvider).value!);
    final theme = Theme.of(context);

    // Sort the bid history (if any) descending by bidAmount.
    final List<Map<String, dynamic>> sortedBidHistory =
    List<Map<String, dynamic>>.from(listing.bidHistory ?? []);
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
                  child: _isLocalCacheLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _localCache[_currentImageIndex] != null
                      ? Image.memory(
                    _localCache[_currentImageIndex]!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                      : const Center(child: Icon(Icons.error)),
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
                  // Row with seller name and Report icon.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Listed by: ${listing.ownerName}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      TextButton.icon(
                        onPressed: () => _showReportDialog(user),
                        icon: const Icon(Icons.report, color: Colors.red),
                        label: const Text("Report", style: TextStyle(color: Colors.red)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Condition: ${listing.condition}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Price: SAR ${NumberFormat('#,##0.00').format(listing.price)}",
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
                  // Bid End Date.
                  if (listing.saleType == SaleType.bid) ...[
                    Text(
                      "Bid End Date: ${listing.bidEndTime!.toLocal().toString().substring(0, 16)}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 10),
                  ],
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
                  // Bidders List Section (only for bid listings)

                  if (listing.saleType == SaleType.bid) ...[
                    const SizedBox(height: 8),

                    Text(
                      "Bidders (Highest to Lowest):",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge!.color),
                    ),

                    SizedBox(
                      height: 100,
                      child: sortedBidHistory.isEmpty
                          ? const Center(child: Text("No bids yet."))
                          : ListView.builder(
                        itemCount: sortedBidHistory.length,
                        itemBuilder: (context, index) {
                          final bidEntry = sortedBidHistory[index];
                          // Check if this bid belongs to the current user.
                          final bool isCurrentUserBid = bidEntry['bidderId'] == user.id;
                          return Container(
                            color: isCurrentUserBid ? theme.colorScheme.secondary.withOpacity(0.2) : null,
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.account_circle),
                              title: Text(
                                "Bid: SAR ${NumberFormat('#,##0.00').format(bidEntry['bidAmount'] as num)}",
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                "Time: ${bidEntry['bidTime']}",
                                style: const TextStyle(fontSize: 12),
                              ),
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
          const SizedBox(height: 5),
          // Bid/Buy Button Area.
          // Replace the Bid/Buy Button Area with the following snippet:

          Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: widget.adminInfo
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Admin Details",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Listing ID: ${listing.id}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Owner: ${listing.ownerName}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Owner ID: ${listing.ownerId}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Listing Location: ${listing.location.toString()}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sale Mode: ${listing.saleType == SaleType.bid ? "Bid" : "Buy Now"}",
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            )
                : listing.saleType == SaleType.bid
                ? Column(
              children: [
                Text(
                  "Current Highest Bid: SAR ${NumberFormat('#,##0.00').format(listing.currentHighestBid ?? listing.startingBid ?? listing.price)}",
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
