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
import 'package:mozayed_app/screens/google_map_screen_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SellScreen extends ConsumerStatefulWidget {
  final bool showBackButton; // Determines if the back button should be shown
  const SellScreen({super.key, this.showBackButton = false});

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  // Dropdown options for item condition and category
  final List<String> _conditions = [
    "New",
    "Used: feels new",
    "Used: good",
    "Used: acceptable"
  ];
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

  // ValueNotifiers to track selected dropdown values
  final ValueNotifier<String> _selectedConditionNotifier =
      ValueNotifier<String>("New");
  final ValueNotifier<String> _selectedCategoryNotifier =
      ValueNotifier<String>("Other");
  final ValueNotifier<String?> _addressNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<SaleType> _saleTypeNotifier =
      ValueNotifier<SaleType>(SaleType.buyNow);
  final ValueNotifier<bool> _isGettingLocationNotifier = ValueNotifier<bool>(false); // Replace _isGettingLocation
  final ValueNotifier<String?> _bidEndTimeNotifier = ValueNotifier<String?>(null); // New notifier for bid end time
  final ValueNotifier<List<XFile>> _pickedImagesNotifier = ValueNotifier<List<XFile>>([]); // Use ValueNotifier for images

  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final Map<String, dynamic> _listingData = {"image": <String>[]}; // Listing data
  bool _isLoading = false; // Tracks if the listing is being saved

  final ImagePicker _picker = ImagePicker(); // Image picker instance

  int _currentImageIndex = 0; // Tracks the current image index in the carousel
  late final PageController _pageController; // Controller for image carousel

  @override
  void initState() {
    super.initState();
    // Initialize listing data with default values
    _listingData["title"] = "";
    _listingData["description"] = "";
    _listingData["price"] = "";
    _listingData["quantity"] = "";
    _listingData["condition"] = _selectedConditionNotifier.value;
    _listingData["category"] = _selectedCategoryNotifier.value;
    _bidEndTimeNotifier.value = _listingData["bidEndTime"]; // Initialize bid end time notifier
    _pickedImagesNotifier.value = []; // Initialize picked images
    _pageController = PageController();
  }

  // Uploads an image to Firebase Storage and returns its download URL
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

  // Picks an image from the specified source (camera or gallery)
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      _pickedImagesNotifier.value = [..._pickedImagesNotifier.value, pickedFile]; // Update ValueNotifier
    }
  }

  // Opens the map picker screen and fetches the selected location
  Future<void> _loadMapGooglePicker() async {
    List<double>? pickedLocation = await Navigator.of(context)
        .push<List<double>>(
            MaterialPageRoute(builder: (ctx) => const GoogleMapScreen()));
    if (pickedLocation == null) return;

    _isGettingLocationNotifier.value = true; // Start loading state

    if (!mounted) return;

    if (kIsWeb) {
      Map<String, dynamic> address = await _getAddressFromLatLngWeb(
        lat: pickedLocation[0],
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
      _addressNotifier.value = address["display_name"];
    } else {
      String address =
          await _getAddressFromLatLng(pickedLocation[0], pickedLocation[1]);
      _addressNotifier.value = address;
    }

    _isGettingLocationNotifier.value = false; // End loading state
  }

  // Removes an image from the picked images list
  void _removeImage({XFile? xFile}) {
    if (xFile != null) {
      _pickedImagesNotifier.value = _pickedImagesNotifier.value
          .where((image) => image != xFile)
          .toList(); // Update ValueNotifier
      if (_currentImageIndex >= _pickedImagesNotifier.value.length) {
        _currentImageIndex = 0;
      }
      _pageController.jumpToPage(_currentImageIndex);
    }
  }

  // Saves the listing data to the backend
  Future<void> _saveListing(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    String listingId = uuid.v4();

    List<String> imageUrls = [];
    for (int i = 0; i < _pickedImagesNotifier.value.length; i++) {
      File imageFile = File(_pickedImagesNotifier.value[i].path);
      String url = await uploadImage(imageFile, listingId, i);
      imageUrls.add(url);
    }

    _listingData["image"] = imageUrls;

    DateTime? bidEndTime;
    double? startingBid;
    double? currentHighestBid;
    if (_saleTypeNotifier.value == SaleType.bid) {
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
      saleType: _saleTypeNotifier.value,
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
      _formKey.currentState!.reset();
    });
  }

  // Fetches the address from latitude and longitude for web
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

  // Fetches the address from latitude and longitude for mobile
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
        _addressNotifier.value = "Please try another option, or later";
      });
      return 'Address not found';
    }
  }

  // Checks if the user account is suspended
  Future<bool?> _isSuspended() async {
    return await ref.read(userDataProvider.notifier).fetchSuspended();
  }

  @override
  Widget build(BuildContext context) {
    final userAsyncValue = ref.read(userDataProvider);

    return userAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text("Error: $error")),
        data: (userData) {
          if (userData == null) {
            return const Center(child: Text("User not logged in"));
          }
          if (userData["suspended"] == true) {
            return const Center(
              child: Text(
                  "Your account has been suspended.\nPlease contact support."),
            );
          }
          final UserModel user = UserModel.fromMap(userData);

          return FutureBuilder<bool?>(
            future: _isSuspended(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              final isSuspended = snapshot.data ?? false;
              if (isSuspended) {
                return const Center(
                  child: Text(
                    "Your account has been suspended.\nPlease contact 365mozayed@gmail.com for support.",
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ValueListenableBuilder<SaleType>(
                valueListenable: _saleTypeNotifier,
                builder: (context, saleType, child) {
                  return ValueListenableBuilder<List<XFile>>(
                    valueListenable: _pickedImagesNotifier,
                    builder: (context, pickedImages, child) {
                      return Scaffold(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        appBar: widget.showBackButton
                            ? AppBar(
                                automaticallyImplyLeading: widget.showBackButton,
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
                                  // Image carousel or placeholder
                                  if (pickedImages.isNotEmpty)
                                    SizedBox(
                                      height: 250,
                                      child: Stack(
                                        children: [
                                          PageView.builder(
                                            controller: _pageController,
                                            itemCount: pickedImages.length,
                                            onPageChanged: (index) {
                                              _currentImageIndex = index;
                                            },
                                            itemBuilder: (ctx, index) {
                                              return Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.file(
                                                    File(pickedImages[index].path),
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
                                                          xFile: pickedImages[index]),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          if (pickedImages.length > 1 &&
                                              _currentImageIndex > 0)
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
                                                      duration:
                                                          const Duration(milliseconds: 300),
                                                      curve: Curves.easeInOut);
                                                },
                                              ),
                                            ),
                                          if (pickedImages.length > 1 &&
                                              _currentImageIndex < pickedImages.length - 1)
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
                                                      duration:
                                                          const Duration(milliseconds: 300),
                                                      curve: Curves.easeInOut);
                                                },
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 8,
                                            left: 0,
                                            right: 0,
                                            child: Center(
                                              child: Text(
                                                '${_currentImageIndex + 1} / ${pickedImages.length}',
                                                style: const TextStyle(
                                                    color: Colors.white, fontSize: 18),
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      height: 250,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiaryContainer,
                                      child: const Center(
                                          child: Text("No images selected")),
                                    ),
                                  const SizedBox(height: 8),
                                  // Buttons to pick images
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.photo_library),
                                        label: const Text("Gallery"),
                                        onPressed: () =>
                                            _pickImage(ImageSource.gallery),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text("Camera"),
                                        onPressed: () =>
                                            _pickImage(ImageSource.camera),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Dropdown for sale type
                                  Row(
                                    children: [
                                      const Text("Sale Type: "),
                                      DropdownButton<SaleType>(
                                        value: saleType,
                                        items: SaleType.values.map((saleType) {
                                          return DropdownMenuItem<SaleType>(
                                            value: saleType,
                                            child: Text(saleType ==
                                                    SaleType.buyNow
                                                ? "Buy Now"
                                                : "Bidding"),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null &&
                                              value != _saleTypeNotifier.value) {
                                            _saleTypeNotifier.value = value;
                                            if (value == SaleType.buyNow) {
                                              _listingData.remove("bidEndTime");
                                              _listingData.remove("startingBid");
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Form fields for title, description, price, etc.
                                  TextFormField(
                                    decoration:
                                        const InputDecoration(labelText: "Title"),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().length < 4) {
                                        return "Please enter a valid title (at least 4 characters).";
                                      }
                                      return null;
                                    },
                                    onSaved: (value) {
                                      _listingData["title"] = value;
                                    },
                                  ),
                                  TextFormField(
                                    decoration: const InputDecoration(
                                        labelText: "Description"),
                                    maxLines: 3,
                                    onSaved: (value) {
                                      _listingData["description"] = value;
                                    },
                                  ),
                                  if (saleType == SaleType.bid) ...[
                                    ValueListenableBuilder<String?>(
                                      valueListenable: _bidEndTimeNotifier,
                                      builder: (context, bidEndTime, child) {
                                        return ElevatedButton(
                                          onPressed: () async {
                                            DateTime? picked = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now()
                                                  .add(const Duration(days: 1)),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now()
                                                  .add(const Duration(days: 30)),
                                            );
                                            if (picked != null) {
                                              _bidEndTimeNotifier.value =
                                                  picked.toIso8601String();
                                              _listingData["bidEndTime"] =
                                                  _bidEndTimeNotifier.value; // Update listing data
                                            }
                                          },
                                          child: Text(
                                            bidEndTime != null
                                                ? "Bid End: $bidEndTime"
                                                : "Select Bid End Time",
                                          ),
                                        );
                                      },
                                    ),
                                    TextFormField(
                                      decoration: const InputDecoration(
                                          labelText: "Starting Bid"),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null ||
                                            double.tryParse(value) == null) {
                                          return "Please enter a valid starting bid.";
                                        }
                                        return null;
                                      },
                                      onSaved: (value) {
                                        _listingData["startingBid"] = value;
                                      },
                                    ),
                                  ],
                                  if (saleType != SaleType.bid)
                                    TextFormField(
                                      decoration:
                                          const InputDecoration(labelText: "Price"),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null ||
                                            double.tryParse(value) == null) {
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
                                    decoration: const InputDecoration(
                                        labelText: "Quantity"),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null ||
                                          int.tryParse(value) == null) {
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
                                  ValueListenableBuilder<String>(
                                    valueListenable: _selectedConditionNotifier,
                                    builder: (context, selectedCondition, child) {
                                      return DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                            labelText: "Condition"),
                                        value: selectedCondition,
                                        items: _conditions.map((condition) {
                                          return DropdownMenuItem<String>(
                                            value: condition,
                                            child: Text(condition),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            _selectedConditionNotifier.value =
                                                value;
                                            _listingData["condition"] = value;
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ValueListenableBuilder<String>(
                                    valueListenable: _selectedCategoryNotifier,
                                    builder: (context, selectedCategory, child) {
                                      return DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                            labelText: "Category"),
                                        value: selectedCategory,
                                        items: _categoryOptions.map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category,
                                            child: Text(category),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            _selectedCategoryNotifier.value = value;
                                            _listingData["category"] = value;
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.map),
                                        onPressed: _loadMapGooglePicker,
                                        label: const Text("Select Location"),
                                      ),
                                      ValueListenableBuilder<bool>(
                                        valueListenable:
                                            _isGettingLocationNotifier,
                                        builder:
                                            (context, isGettingLocation, child) {
                                          return isGettingLocation
                                              ? const CircularProgressIndicator()
                                              : ValueListenableBuilder<String?>(
                                                  valueListenable: _addressNotifier,
                                                  builder:
                                                      (context, address, child) {
                                                    return Text(address ??
                                                        "No address selected");
                                                  },
                                                );
                                        },
                                      ),
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
                    },
                  );
                },
              );
            },
          );
        });
  }

  @override
  void dispose() {
    // Dispose ValueNotifiers to free resources
    _selectedConditionNotifier.dispose();
    _selectedCategoryNotifier.dispose();
    _addressNotifier.dispose();
    _saleTypeNotifier.dispose();
    _isGettingLocationNotifier.dispose(); // Dispose the new notifier
    _bidEndTimeNotifier.dispose(); // Dispose the new notifier
    _pickedImagesNotifier.dispose(); // Dispose the new notifier
    super.dispose();
  }
}

