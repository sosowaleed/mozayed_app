import 'dart:io';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/providers/listing_provider.dart';
import 'package:mozayed_app/screens/static_flutter_map_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SellScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const SellScreen({super.key, this.showBackButton = false});

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final List<String> _conditions = [
    "New",
    "Used: feels new",
    "Used: good",
    "Used: acceptable"
  ];
  final List<String> _categoryOptions = [
    "Furniture",
    "Electronics",
    "Clothing",
    "Home",
    "Books",
    "Toys",
    "Other"
  ];
  String _selectedCondition = "New"; // Default condition
  String _selectedCategory = "Other"; // Default category
  final _formKey = GlobalKey<FormState>();
  // Initialize _listingData with an empty image list.
  final Map<String, dynamic> _listingData = {"image": <String>[]};
  bool _isGettingLocation = false;
  bool _isLoading = false;
  String? _address;
  SaleType _saleType = SaleType.buyNow; // Default to Buy Now

  // List to hold newly picked images.
  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  // For preview tracking.
  int _currentImageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Set initial values for other fields if needed.
    _listingData["title"] = "";
    _listingData["description"] = "";
    _listingData["price"] = "";
    _listingData["quantity"] = "";
    _listingData["condition"] = _selectedCondition;
    _listingData["category"] = _selectedCategory;
    // No pre-existing images, so _listingData["image"] is an empty list.
    _pageController = PageController();
  }

  // Upload an image file to Firebase Storage and return its download URL.
  Future<String> uploadImage(
      File imageFile, String listingId, int index) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child("listing_images")
        .child(listingId)
        .child("image_$index.jpg");

    UploadTask uploadTask = storageRef.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Opens the image picker and lets the user choose an image.
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _pickedImages.add(pickedFile);
      });
    }
  }

  /// Opens the map picker (existing implementation) to select a location.
  Future<void> _loadMapPicker() async {
    List<double>? pickedLocation = await Navigator.of(context)
        .push<List<double>>(
            MaterialPageRoute(builder: (ctx) => const StaticMapPickerScreen()));
    setState(() {
      _isGettingLocation = true;
    });
    if (!mounted) return;
    if (kIsWeb) {
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
      String address =
          await _getAddressFromLatLng(pickedLocation![0], pickedLocation[1]);
      setState(() {
        _address = address;
        _isGettingLocation = false;
      });
    }
  }

  /// Removes an image from the preview (only from newly picked images, since there are no existing ones).
  void _removeImage({XFile? xFile}) {
    setState(() {
      if (xFile != null) {
        _pickedImages.remove(xFile);
        // Adjust current image index if needed.
        if (_currentImageIndex >= _pickedImages.length) {
          _currentImageIndex = 0;
        }
        _pageController.jumpToPage(_currentImageIndex);
      }
    });
  }

  Future<void> _saveListing(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
    });

    // Generate a unique ID for the listing.
    String listingId = uuid.v4();

    // Upload newly picked images.
    List<String> imageUrls = [];
    for (int i = 0; i < _pickedImages.length; i++) {
      File imageFile = File(_pickedImages[i].path);
      String url = await uploadImage(imageFile, listingId, i);
      imageUrls.add(url);
    }

    // Set the image URLs in _listingData.
    _listingData["image"] = imageUrls;

    // Parse bid-related fields if sale type is bid.
    DateTime? bidEndTime;
    double? startingBid;
    double? currentHighestBid;
    if (_saleType == SaleType.bid) {
      if (_listingData["bidEndTime"] != null) {
        bidEndTime = DateTime.parse(_listingData["bidEndTime"]);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please select a bid end time")),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      if (_listingData["startingBid"] != null) {
        _listingData["price"] = _listingData["startingBid"];
        startingBid = double.parse(_listingData["startingBid"]);
        currentHighestBid = startingBid;
      }
    }

    final listing = ListingItem(
      id: listingId,
      ownerId: user.id,
      ownerName: user.name,
      title: _listingData["title"],
      description: _listingData["description"],
      image: imageUrls,
      price: double.parse(_listingData["price"]),
      condition: _listingData["condition"],
      quantity: int.parse(_listingData["quantity"]),
      saleType: _saleType,
      category: _listingData["category"] ?? "Other",
      location: _listingData["location"] != null
          ? ListingLocation.fromMap(_listingData["location"])
          : null,
      bidEndTime: bidEndTime,
      startingBid: startingBid,
      currentHighestBid: currentHighestBid,
      currentHighestBidderId: null,
      bidHistory: [],
      bidFinalized: false,
    );

    await ref.read(listingsProvider.notifier).addListing(listing);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Published Successfully")),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future _getAddressFromLatLngWeb({
    required double lat,
    required double lng,
    required Locale lang,
  }) async {
    final uri = Uri.https("nominatim.openstreetmap.org", "/reverse", {
      "lat": lat.toString(),
      "lon": lng.toString(),
      "format": "json",
    });
    try {
      final response = await http
          .get(uri, headers: {'Accept-Language': lang.toLanguageTag()});
      if (response.statusCode != 200) {
        throw http.ClientException(
            'Error ${response.statusCode}: ${response.body}', uri);
      }
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse.containsKey('error')) {
        throw 'Error: ${jsonResponse['error']}';
      }
      return jsonResponse ?? 'Address not found';
    } catch (e) {
      return 'Error retrieving address: $e';
    }
  }

  Future _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      final List<geo.Placemark> placeMarks =
          await geo.placemarkFromCoordinates(latitude, longitude);
      if (placeMarks.isNotEmpty) {
        final geo.Placemark place = placeMarks.first;
        _listingData["location"] = {
          "lat": latitude,
          "lng": longitude,
          "address":
              '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}',
          "city": place.locality,
          "zip": place.postalCode,
          "country": place.country,
        };
        return _listingData["location"]["address"];
      } else {
        return 'Address not found';
      }
    } catch (e) {
      log('Error occurred while fetching address: $e');
      setState(() {
        _address = "Please try another option, or later";
        _isGettingLocation = false;
      });
      return 'Address not found';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Assume user data is loaded.
    UserModel user = UserModel.fromMap(ref.read(userDataProvider).value!);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.showBackButton
          ? AppBar(
              automaticallyImplyLeading:
                  widget.showBackButton, // This will show the back button
              title: const Text("Sell"),
            )
          : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Images Preview Section
                if (_pickedImages.isNotEmpty)
                  SizedBox(
                    height: 250,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _pickedImages.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (ctx, index) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(_pickedImages[index].path),
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 5,
                                  right: 0,
                                  left: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () => _removeImage(
                                        xFile: _pickedImages[index]),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        // Left Arrow (only if more than one image and not on the first page)
                        if (_pickedImages.length > 1 && _currentImageIndex > 0)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              padding: const EdgeInsets.all(32),
                              icon: const Icon(Icons.arrow_back_ios,
                                  size: 15, color: Colors.grey),
                              onPressed: () {
                                _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut);
                              },
                            ),
                          ),
                        // Right Arrow (only if more than one image and not on the last page)
                        if (_pickedImages.length > 1 &&
                            _currentImageIndex < _pickedImages.length - 1)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              padding: const EdgeInsets.all(32),
                              icon: const Icon(Icons.arrow_forward_ios,
                                  size: 15, color: Colors.grey),
                              onPressed: () {
                                _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut);
                              },
                            ),
                          ),
                        // Image count indicator.
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              '${_currentImageIndex + 1} / ${_pickedImages.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                else
                  // If no images have been picked, show a placeholder.
                  Container(
                    height: 250,
                    color: Colors.grey[300],
                    child: const Center(child: Text("No images selected")),
                  ),
                const SizedBox(height: 8),
                // Buttons to pick images.
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
                // Form fields (title, description, etc.)
                TextFormField(
                  decoration: const InputDecoration(labelText: "Title"),
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return "Please enter a valid title (at least 4 characters).";
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _listingData["title"] = value;
                  },
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 3,
                  onSaved: (value) {
                    _listingData["description"] = value;
                  },
                ),
                //added this part to clear the price when the sale type is not buyNow
                if (_saleType == SaleType.bid)
                  const Text(""),
                if (_saleType != SaleType.bid)
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Price"),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return "Please enter a valid price.";
                      } else if (double.parse(value) <= 0) {
                        return "Price must be greater than zero.";
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _listingData["price"] = value;
                    },
                  ),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Quantity"),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null) {
                      return "Please enter a valid quantity.";
                    } else if (int.parse(value) <= 0) {
                      return "Quantity must be greater than zero.";
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _listingData["quantity"] = value;
                  },
                ),
                const SizedBox(
                  height: 5,
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Condition"),
                  value: _selectedCondition,
                  items: _conditions.map((condition) {
                    return DropdownMenuItem<String>(
                      value: condition,
                      child: Text(condition),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCondition = value!;
                    });
                  },
                  onSaved: (value) {
                    _listingData["condition"] = value;
                  },
                ),
                const SizedBox(height: 12),
                // Sale Type Toggle
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
                        setState(() {
                          _saleType = value ?? SaleType.buyNow;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_saleType == SaleType.bid) ...[
                  // Bid End Time Picker
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
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
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: "Starting Bid"),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return "Please enter a valid starting bid.";
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _listingData["startingBid"] = value;
                    },
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
                      onPressed: _loadMapPicker,
                      label: const Text("Select Location"),
                    ),
                    _isGettingLocation
                        ? const CircularProgressIndicator()
                        : Text(_address ?? "No address selected"),
                  ],
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () {
                          if (!_isLoading) {
                            _saveListing(user);
                          }
                        },
                        child: const Text("Publish Listing"),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
