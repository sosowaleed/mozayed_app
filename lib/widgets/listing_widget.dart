import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/screens/listing_details_screen.dart';
import 'dart:typed_data';
import 'package:mozayed_app/utils/global_image_cache.dart';

class ListingWidget extends StatefulWidget {
  final ListingItem listingItem;
  final bool adminInfo;
  const ListingWidget({super.key, required this.listingItem, this.adminInfo = false});

  @override
  State<ListingWidget> createState() => _ListingWidgetState();
}

class _ListingWidgetState extends State<ListingWidget> {
  List<Uint8List?> _imageBytesCache = [];
  late ListingItem listingItem;
  int _currentImageIndex = 0;
  late bool _isLoadingImages;

  @override
  void initState() {
    super.initState();
    listingItem = widget.listingItem;
    _isLoadingImages = true;
    _preloadImages();
  }

  // Preload all image bytes and store in the cache.
  Future<void> _preloadImages() async {
    final futures =
        listingItem.image.map((url) => _getImageBytes(url)).toList();
    _imageBytesCache = await Future.wait(futures);
    setState(() {
      _isLoadingImages = false;
    });
  }

  bool isPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < 600; // Adjust breakpoint as needed
  }

  void _previousImage() {
    setState(() {
      _currentImageIndex = (_currentImageIndex - 1) % listingItem.image.length;
      if (_currentImageIndex < 0) {
        _currentImageIndex = listingItem.image.length - 1;
      }
    });
  }

  void _nextImage() {
    setState(() {
      _currentImageIndex = (_currentImageIndex + 1) % listingItem.image.length;
    });
  }

  // Helper function to get image bytes from Firebase Storage
  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    if (globalImageCache.containsKey(imageUrl)) {
      return globalImageCache[imageUrl];
    }
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      final bytes =  await ref.getData();
      globalImageCache[imageUrl] = bytes;
      return bytes;
    } catch (e) {
      globalImageCache[imageUrl] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneLayout = isPhone(context);

    return InkWell(
      onTap: () {
        // Navigate to the Listing Details Screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ListingDetailsScreen(listingItem: listingItem, _imageBytesCache, adminInfo: widget.adminInfo,),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        margin: const EdgeInsets.all(8.0),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Image Section
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                  child: Hero(
                    tag: listingItem.id,
                    child: _isLoadingImages
                        ? const Center(child: CircularProgressIndicator())
                        : _imageBytesCache[_currentImageIndex] == null
                            ? const Center(child: Icon(Icons.error))
                            : Image.memory(
                                _imageBytesCache[_currentImageIndex]!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                  ),
                ),
                if (!isPhoneLayout)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: _previousImage,
                      color: Colors.white,
                      iconSize: 24,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.38),
                        ),
                      ),
                    ),
                  ),
                if (!isPhoneLayout)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: _nextImage,
                      color: Colors.white,
                      iconSize: 24,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.38),
                        ),
                      ),
                    ),
                  ),
                if (listingItem.image.length > 1)
                  Positioned(
                    right: 0,
                    child: AutoSizeText(
                      '${_currentImageIndex + 1}/${listingItem.image.length}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
              ],
            ),
            // Metadata Section
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      listingItem.title,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(237, 237, 237, 1),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text.rich(
                          softWrap: true,
                          TextSpan(
                            children: [
                              TextSpan(
                                text: NumberFormat('#,##0.00').format(listingItem.price),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(237, 237, 237, 1)),
                              ),
                              TextSpan(
                                text: ' / SAR',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[300],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Expanded(
                          child: AutoSizeText(
                            listingItem.condition,
                            style: TextStyle(
                                color: Colors.grey[200], fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
