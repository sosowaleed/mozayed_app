import 'package:flutter/material.dart';
import 'package:mozayed_app/models/listing_model.dart';

class ListingDetailsScreen extends StatefulWidget {
  final ListingItem listingItem;

  const ListingDetailsScreen({super.key, required this.listingItem});

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  int _currentImageIndex = 0;

  void _previousImage() {
    setState(() {
      _currentImageIndex = (_currentImageIndex - 1) % widget.listingItem.image.length;
      if (_currentImageIndex < 0) {
        _currentImageIndex = widget.listingItem.image.length - 1;
      }
    });
  }

  void _nextImage() {
    setState(() {
      _currentImageIndex = (_currentImageIndex + 1) % widget.listingItem.image.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listingItem.title, style: const TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image Section with Arrows
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Image Display
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.listingItem.image[_currentImageIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                // Left Arrow
                Positioned(
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 30),
                    onPressed: _previousImage,
                    color: Colors.white,
                    style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.black38)),
                  ),
                ),
                // Right Arrow
                Positioned(
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 30),
                    onPressed: _nextImage,
                    color: Colors.white,
                    style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.black38)),
                  ),
                ),
              ],
            ),
          ),

          // Metadata Section
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata Content
                  Text(
                    "Condition: ${widget.listingItem.condition}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Price: \$${widget.listingItem.price.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
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
                        widget.listingItem.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Spacer to push buttons to the bottom
          const Spacer(),

          // Buttons at the Bottom
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                // "Bit" Button
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle bidding logic here
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Bit", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                // "BUY" Button
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle buying logic here
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("BUY", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
