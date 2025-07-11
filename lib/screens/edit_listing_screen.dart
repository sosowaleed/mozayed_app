/// This file defines the `EditListingScreen` widget, which allows users to edit
/// an existing listing. It includes functionality for updating listing details,
/// managing images, and handling location data.

import 'dart:io';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geo;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/screens/google_map_screen_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A stateful widget that provides a screen for editing a listing.
///
/// This widget allows users to modify listing details, upload/remove images,
/// and update location data. It also supports deleting the listing.
class EditListingScreen extends ConsumerStatefulWidget {
  /// The listing item to be edited.
  final ListingItem listing;

  /// Whether the user has admin privileges.
  final bool adminInfo;

  /// Constructor for `EditListingScreen`.
  const EditListingScreen({
    super.key,
    required this.listing,
    this.adminInfo = false,
  });

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  /// List of category options for the listing.
  final List<String> _categoryOptions = [
    "Furniture",
    "Electronics",
    "Car",
    "Clothing",
    "Home",
    "Books",
    "Toys",
    "Other"
  ];

  /// The currently selected category.
  String _selectedCategory = "Other";

  /// Form key for validating and saving form data.
  final _formKey = GlobalKey<FormState>();

  /// Map to store the listing data being edited.
  late Map<String, dynamic> _listingData;

  /// Indicates whether the app is fetching location data.
  bool _isGettingLocation = false;

  /// The address of the listing's location.
  String? _address;

  /// The sale type of the listing (e.g., Buy Now or Bidding).
  SaleType _saleType = SaleType.buyNow;

  /// List of images picked by the user.
  final List<XFile> _pickedImages = [];

  /// Image picker instance for selecting images.
  final ImagePicker _picker = ImagePicker();

  /// Page controller for navigating through images.
  late PageController _pageController;

  /// List of image URLs that have been removed by the user.
  final List<String> _removedImageUrls = [];

  /// Local cache for storing prefetched images.
  List<Uint8List?> _localCache = [];

  /// Indicates whether the local image cache is still loading.
  bool _isLocalCacheLoading = true;

  @override
  void initState() {
    super.initState();

    // Pre-populate the form with existing listing data.
    _listingData = {
      "title": widget.listing.title,
      "description": widget.listing.description,
      "price": widget.listing.price.toString(),
      "quantity": widget.listing.quantity.toString(),
      "condition": widget.listing.condition,
      "category": widget.listing.category,
      "location": widget.listing.location?.toMap(),
      "image": widget.listing.image, // existing image URLs
      "bidEndTime": widget.listing.bidEndTime?.toIso8601String(),
      "startingBid": widget.listing.startingBid?.toString(),
      "currentHighestBid": widget.listing.currentHighestBid?.toString(),
      "currentHighestBidderId": widget.listing.currentHighestBidderId,
      "bidHistory": widget.listing.bidHistory,
      "bidFinalized": widget.listing.bidFinalized,
    };

    _address = widget.listing.location?.address;
    _saleType = widget.listing.saleType;
    _selectedCategory = widget.listing.category;
    _pageController = PageController();

    // Prefetch images from Firebase Storage.
    _prefetchImages();
  }

  @override
  void dispose() {
    // Dispose of the page controller to free resources.
    _pageController.dispose();
    super.dispose();
  }

  /// Prefetches all image bytes for the current listing from Firebase Storage.
  Future<void> _prefetchImages() async {
    final futures =
        widget.listing.image.map((url) => _getImageBytes(url)).toList();
    _localCache = await Future.wait(futures);
    setState(() {
      _isLocalCacheLoading = false;
    });
  }

  /// Fetches image bytes from Firebase Storage for a given image URL.
  ///
  /// Returns the image data as a `Uint8List` or `null` if an error occurs.
  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      return await ref.getData();
    } catch (e) {
      log("Error fetching image: $e");
      return null;
    }
  }

  /// Deletes the current listing after user confirmation.
  Future<void> _deleteListing() async {
    // Confirm deletion with the user.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Listing"),
        content: const Text(
            "Are you sure you want to delete this listing? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the listing using the provider.
      await ref.read(listingsProvider.notifier).deleteListing(widget.listing);

      // Show a success message and navigate back if the widget is still mounted.
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Listing deleted successfully")));
        Navigator.of(context).pop(); // Return from edit screen.
      }
    } catch (e) {
      log("Error deleting listing: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error deleting listing")));
    }
  }

  /// Uploads an image file to Firebase Storage and returns its download URL.
  ///
  /// [imageFile] is the file to upload.
  /// [listingId] is the ID of the listing the image belongs to.
  /// [index] is the index of the image.
  Future<String> uploadImage(
      File imageFile, String listingId, int index) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child("listing_images")
        .child(listingId)
        .child("image_$index.jpg");

    // Upload the file.
    UploadTask uploadTask = storageRef.putFile(imageFile);

    // Wait for the upload to complete and return the download URL.
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Allows the user to pick an image from the specified [source].
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _pickedImages.add(pickedFile);
      });
    }
  }

  /// Opens the Google Map picker screen for selecting a location.
  Future<void> _loadMapGooglePicker() async {
    List<double>? pickedLocation =
        await Navigator.of(context).push<List<double>>(MaterialPageRoute(
            builder: (ctx) => GoogleMapScreen(
                  latitude: widget.listing.location!.lat,
                  longitude: widget.listing.location!.lng,
                  ifLocationFetched: true,
                )));

    // If the user pressed back, do nothing.
    if (pickedLocation == null) return;

    setState(() {
      _isGettingLocation = true;
    });

    if (!mounted) {
      return;
    }
    if (kIsWeb) {
      // Fetch address for web platforms.
      Map<String, dynamic> address = await _getAddressFromLatLngWeb(
        lat: pickedLocation![0],
        lng: pickedLocation[1],
        lang: Localizations.localeOf(context),
      );

      if (address["display_name"] != "address not found") {
        _listingData["location"] = {
          "lat": pickedLocation[0],
          "lng": pickedLocation[1],
          "address": address["display_name"],
          "city": address["address"]["city"],
          "zip": address["address"]["postcode"],
          "country": address["address"]["country"],
        };
      }

      setState(() {
        _address = address["display_name"];
        _isGettingLocation = false;
      });
    } else {
      // Fetch address for non-web platforms.
      String address =
          await _getAddressFromLatLng(pickedLocation[0], pickedLocation[1]);
      setState(() {
        _address = address;
        _isGettingLocation = false;
      });
    }
  }

  /// Removes an image from the listing.
  ///
  /// [imageUrl] is the URL of the image to remove (if it's an existing image).
  /// [xFile] is the file to remove (if it's a newly picked image).
  void _removeImage({String? imageUrl, XFile? xFile}) {
    setState(() {
      if (imageUrl != null) {
        // Remove the image URL from the listing data.
        List<String> currentImages =
            List<String>.from(_listingData["image"] ?? []);
        currentImages.remove(imageUrl);
        _listingData["image"] = currentImages;
        _removedImageUrls.add(imageUrl);
      }
      if (xFile != null) {
        // Remove the picked image file.
        _pickedImages.remove(xFile);
      }
    });
  }

  /// Deletes an image from Firebase Storage and Firestore.
  ///
  /// [imageUrl] is the URL of the image to delete.
  /// [listingId] is the ID of the listing the image belongs to.
  Future<void> _deleteImageFromFirebaseStorageAndFirestore(
      String imageUrl, String listingId) async {
    if (imageUrl.isNotEmpty) {
      try {
        // Delete the image from Firebase Storage.
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();

        // Remove the image reference from Firestore.
        final docRef =
            FirebaseFirestore.instance.collection('listings').doc(listingId);
        final doc = await docRef.get();
        if (doc.exists && doc.data() != null) {
          List<dynamic> images = doc.data()!['image'] ?? [];
          images.remove(imageUrl);
          await docRef.update({'image': images});
        }
      } catch (e) {
        log("Error deleting image from Firebase: $e");
      }
    }
  }

  /// Saves the updated listing data.
  void _saveListing() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Upload newly picked images to Firebase Storage and collect their download URLs.
    List<String> newImageUrls = [];
    for (int i = 0; i < _pickedImages.length; i++) {
      File imageFile = File(_pickedImages[i].path);
      String url = await uploadImage(imageFile, widget.listing.id, i);
      newImageUrls.add(url);
    }

    // Delete removed images from Firebase Storage and Firestore.
    for (String imageUrl in _removedImageUrls) {
      await _deleteImageFromFirebaseStorageAndFirestore(
          imageUrl, widget.listing.id);
    }

    // Merge existing and new images, removing duplicates.
    List<String> updatedImages = List<String>.from(_listingData["image"] ?? []);
    updatedImages.addAll(newImageUrls);
    updatedImages = updatedImages.toSet().toList();
    _listingData["image"] = updatedImages;

    // Parse bid-related fields if the sale type is bidding.
    DateTime? bidEndTime;
    double? startingBid;
    double? currentHighestBid;
    if (_saleType == SaleType.bid) {
      if (_listingData["bidEndTime"] != null &&
          _listingData["bidEndTime"].toString().trim().isNotEmpty) {
        bidEndTime = DateTime.parse(_listingData["bidEndTime"]);
      } else {
        bidEndTime = widget.listing.bidEndTime;
      }
      if (_listingData["startingBid"] != null &&
          _listingData["startingBid"].toString().trim().isNotEmpty) {
        startingBid = double.parse(_listingData["startingBid"]);
      } else {
        startingBid = widget.listing.startingBid;
      }
      currentHighestBid = widget.listing.currentHighestBid ?? startingBid;
    }

    // Create the updated listing object.
    final updatedListing = ListingItem(
      id: widget.listing.id,
      ownerId: widget.listing.ownerId,
      ownerName: widget.listing.ownerName,
      title: _listingData["title"] ?? widget.listing.title,
      description: _listingData["description"] ?? widget.listing.description,
      image: updatedImages,
      price: _listingData["price"] != null
          ? double.parse(_listingData["price"])
          : widget.listing.price,
      condition: _listingData["condition"] ?? widget.listing.condition,
      quantity: _listingData["quantity"] != null
          ? int.parse(_listingData["quantity"])
          : widget.listing.quantity,
      saleType: _saleType,
      category: _listingData["category"] ?? widget.listing.category,
      location: _listingData["location"] != null
          ? ListingLocation.fromMap(_listingData["location"])
          : widget.listing.location,
      bidEndTime: bidEndTime,
      startingBid: startingBid,
      currentHighestBid: currentHighestBid,
      currentHighestBidderId: widget.listing.currentHighestBidderId,
      bidHistory: widget.listing.bidHistory ?? [],
      bidFinalized: widget.listing.bidFinalized,
    );

    // Update the listing using the provider.
    await ref.read(listingsProvider.notifier).updateListing(updatedListing);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Navigates to the previous image in the image carousel.
  void _previousImage() {
    if (_pageController.page! > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  /// Navigates to the next image in the image carousel.
  void _nextImage() {
    if (_pageController.page! <
        _listingData["image"].length + _pickedImages.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Listing",
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Images Preview (existing images + newly picked ones)
                SizedBox(
                  height: 250,
                  child: Stack(
                    children: [
                      PageView(
                        controller: _pageController,
                        children: [
                          // Display prefetched images from Firebase Storage.
                          if (!_isLocalCacheLoading)
                            ...List.generate(
                              (_listingData["image"] as List<String>).length,
                              (index) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  _localCache[index] != null
                                      ? Image.memory(
                                          _localCache[index]!,
                                          fit: BoxFit.cover,
                                        )
                                      : const Center(child: Icon(Icons.error)),
                                  Positioned(
                                    top: 5,
                                    left: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeImage(
                                          imageUrl: (_listingData["image"]
                                              as List<String>)[index],
                                          xFile: null),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            // If not loaded yet, display a loading indicator for each image.
                            ...List.generate(
                              (_listingData["image"] as List<String>).length,
                              (index) => const Center(
                                  child: CircularProgressIndicator()),
                            ),
                          // Newly picked images remain unchanged.
                          ..._pickedImages.map((xFile) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(xFile.path),
                                      fit: BoxFit.cover),
                                  Positioned(
                                    top: 8,
                                    left: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      onPressed: () => _removeImage(
                                          imageUrl: null, xFile: xFile),
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      ),
                      // Previous arrow
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          padding: const EdgeInsets.all(32),
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            size: 15,
                            color: Colors.grey,
                          ),
                          onPressed: _previousImage,
                        ),
                      ),
                      // Next arrow
                      Positioned(
                        right: 0,
                        top: 5,
                        bottom: 0,
                        child: IconButton(
                          padding: const EdgeInsets.all(32),
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            size: 15,
                            color: Colors.grey,
                          ),
                          onPressed: _nextImage,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${(_pageController.hasClients && _pageController.page != null ? (_pageController.page! + 1).toInt() : 1)} / ${(_listingData["image"] as List).length + _pickedImages.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Gallery"),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Camera"),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text("Sale Type: "),
                    DropdownButton<SaleType>(
                      value: _saleType,
                      items: SaleType.values.map((saleType) {
                        return DropdownMenuItem<SaleType>(
                          value: saleType,
                          child: Text(saleType == SaleType.buyNow
                              ? "Buy Now"
                              : "Bidding"),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (_saleType == SaleType.buyNow &&
                            value == SaleType.bid) {
                          // only allow changing from buyNow to bid.
                          setState(() {
                            _saleType = value ?? SaleType.buyNow;
                          });
                        } else if (_saleType == SaleType.bid &&
                            value == SaleType.buyNow) {
                          //show a message that you cant change from bid to buyNow
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'You cannot change from bid to buy only from buy to bid.'),
                            duration: Duration(seconds: 3),
                          ));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Form fields (title, description, etc.)
                TextFormField(
                  initialValue: _listingData["title"],
                  decoration: const InputDecoration(labelText: "Title"),
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return "Please enter a valid title.";
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _listingData["title"] = value;
                  },
                ),
                TextFormField(
                  initialValue: _listingData["description"],
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 3,
                  onSaved: (value) {
                    _listingData["description"] = value;
                  },
                ),
                //added this part to clear the price when the sale type is not buyNow
                if (_saleType == SaleType.bid) const Text(""),

                if (_saleType != SaleType.bid)
                  TextFormField(
                    initialValue: _listingData["price"],
                    decoration: const InputDecoration(labelText: "Price"),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return "Please enter a valid price.";
                      } else if (double.parse(value) <= 0) {
                        return "Price must be greater than 0.";
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _listingData["price"] = value;
                    },
                  ),
                TextFormField(
                  initialValue: _listingData["quantity"],
                  decoration: const InputDecoration(labelText: "Quantity"),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null) {
                      return "Please enter a valid quantity.";
                    } else if (int.parse(value) <= 0) {
                      return "Quantity must be greater than 0.";
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _listingData["quantity"] = value;
                  },
                ),
                TextFormField(
                  initialValue: _listingData["condition"],
                  decoration: const InputDecoration(labelText: "Condition"),
                  onSaved: (value) {
                    _listingData["condition"] = value;
                  },
                ),
                const SizedBox(height: 12),
                // Sale Type Toggle

                if (_saleType == SaleType.bid) ...[
                  // Bid End Time Picker
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: _listingData["bidEndTime"] != null
                            ? DateTime.parse(_listingData["bidEndTime"])
                            : DateTime.now().add(const Duration(days: 7)),
                      );
                      if (picked != null) {
                        // Optionally show time picker as well.
                        setState(() {
                          _listingData["bidEndTime"] = picked.toIso8601String();
                        });
                      }
                    },
                    child: Text(
                      _listingData["bidEndTime"] != null
                          ? "Bid End: ${_listingData["bidEndTime"]}"
                          : "Select Bid End Time",
                    ),
                  ),
                  // Starting Bid Field
                  if (_listingData["startingBid"] == null)
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: "Starting Bid"),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || double.tryParse(value) == null) {
                          return "Please enter a valid starting bid.";
                        } else if (double.parse(value) <= 0) {
                          return "Starting bid must be greater than 0.";
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _listingData["startingBid"] = value;
                      },
                    ),
                  if (_listingData["currentHighestBid"] != null)
                    const SizedBox(height: 12),
                  Text(
                    "Current Highest Bid: SAR ${NumberFormat('#,##0.00').format(double.tryParse(_listingData["currentHighestBid"] ?? '0'))}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ],

                Row(
                  children: [
                    const Text("Category: "),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Select Category",
                        ),
                        value: _selectedCategory,
                        items: _categoryOptions.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val ?? "Other";
                          });
                        },
                        onSaved: (val) {
                          _listingData["category"] = val;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Location Picker
                Column(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      onPressed: _loadMapGooglePicker,
                      label: const Text("Select Location"),
                    ),
                    _isGettingLocation
                        ? const CircularProgressIndicator()
                        : Text(_address ?? "No address selected"),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _saveListing,
                      child: const Text("Save Changes"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _deleteListing,
                      child: Text("Delete Listing",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fetches the address from latitude and longitude using the Nominatim API (for web platforms).
  /// Returns a JSON response containing the address or an error message.
  Future _getAddressFromLatLngWeb({
    required double lat,
    required double lng,
    required Locale lang,
  }) async {
    // Construct the URI for the Nominatim API.
    final uri = Uri.https("nominatim.openstreetmap.org", "/reverse", {
      "lat": lat.toString(),
      "lon": lng.toString(),
      "format": "json", // Required format
    });

    try {
      // Send an HTTP GET request to fetch the address.
      final response = await http.get(
        uri,
        headers: {'Accept-Language': lang.toLanguageTag()},
      );

      // Check if the response status is not successful.
      if (response.statusCode != 200) {
        throw http.ClientException(
          'Error ${response.statusCode}: ${response.body}',
          uri,
        );
      }

      // Parse the JSON response.
      final jsonResponse = jsonDecode(response.body);

      // Check for errors in the JSON response.
      if (jsonResponse.containsKey('error')) {
        throw 'Error: ${jsonResponse['error']}';
      }

      // Return the extracted address or a default message.
      return jsonResponse ?? 'Address not found';
    } catch (e) {
      // Return an error message if an exception occurs.
      return 'Error retrieving address: $e';
    }
  }

  /// Fetches the address from latitude and longitude using the Geocoding package (for non-web platforms).
  /// Updates the `_listingData` with the location details and returns the address as a string.
  Future _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      // Fetch placemarks using the Geocoding package.
      final List<geo.Placemark> placeMarks =
          await geo.placemarkFromCoordinates(latitude, longitude);

      // Check if placemarks are available.
      if (placeMarks.isNotEmpty) {
        final geo.Placemark place = placeMarks.first;

        // Update the listing data with location details.
        _listingData["location"] = {
          "lat": latitude,
          "lng": longitude,
          "address":
              '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}',
          "city": place.locality,
          "zip": place.postalCode,
          "country": place.country,
        };

        // Return the formatted address.
        return _listingData["location"]["address"];
      } else {
        // Return a default message if no address is found.
        return 'Address not found';
      }
    } catch (e) {
      // Log the error and update the state with a fallback message.
      log('Error occurred while fetching address: $e');
      setState(() {
        _address = "Please try another option, or later";
        _isGettingLocation = false;
      });
    }
  }
}
