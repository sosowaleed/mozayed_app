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

class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key});

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _listingData = {};
  bool _isGettingLocation = false;
  String? _address;
  SaleType _saleType = SaleType.buyNow; // Default to Buy Now

  // List to hold the picked images
  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _conditions = ["New", "Used: feels new", "Used: good", "Used: acceptable"];
  String _selectedCondition = "New"; // Default condition

  /// Opens the image picker and lets the user choose an image from gallery or camera.
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _pickedImages.add(pickedFile);
      });
    }
  }

  // TODO: replace with google maps implementation.
  /// Opens the map picker (existing implementation) to select a location.
  Future<void> _loadMapPicker() async {
    List<double>? pickedLocation = await Navigator.of(context).push<List<double>>(
        MaterialPageRoute(builder: (ctx) => const StaticMapPickerScreen()
        ));
    setState(() {
      _isGettingLocation = true;
    });

    if (!mounted) {
      return;
    }
    if (kIsWeb) {
      Map<String, dynamic> address = await _getAddressFromLatLngWeb(
        lat: pickedLocation![0],
        lng: pickedLocation[1],
        lang: Localizations.localeOf(context),
      );

      if(address["display_name"] != "address not found") {
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
      String address = await _getAddressFromLatLng(pickedLocation![0], pickedLocation[1]);
      setState(() {
        _address =  address;
        _isGettingLocation = false;
      });
    }
  }

  void _saveListing(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // In a real app, upload images to storage and get URLs.
    // For now, we simulate that _listingData["image"] is a list of file paths.
    _listingData["image"] = _pickedImages.map((xfile) => xfile.path).toList();

    final listing = ListingItem(
      ownerId: user.id,
      ownerName: user.name,
      title: _listingData["title"],
      description: _listingData["description"],
      image: _listingData["image"] ?? [],
      price: double.parse(_listingData["price"]),
      condition: _listingData["condition"],
      quantity: int.parse(_listingData["quantity"]),
      saleType: _saleType,
      location: _listingData["location"] != null
          ? ListingLocation.fromMap(_listingData["location"])
          : null,
    );

    await ref.read(listingsProvider.notifier).addListing(listing);
    // Optionally, clear the form or navigate back.
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // we assume that the user data is already loaded.
    UserModel user = UserModel.fromMap(ref.read(userDataProvider).value!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sell an Item"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Images Preview
                if (_pickedImages.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      itemCount: _pickedImages.length,
                      itemBuilder: (ctx, index) {
                        return Image.file(
                          File(_pickedImages[index].path),
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                // Buttons to pick images
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
                // Title Field
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
                // Description Field
                TextFormField(
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 3,
                  onSaved: (value) {
                    _listingData["description"] = value;
                  },
                ),
                // Price Field
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
                // Quantity Field
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
                // Condition Field
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
                // Location Picker
                Column(
                  children: [
                    TextButton.icon(
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
                ElevatedButton(
                  onPressed: () => _saveListing(user),
                  child: const Text("Publish Listing"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future _getAddressFromLatLngWeb({
    required double lat,
    required double lng,
    required Locale lang,
  }) async {
    final uri = Uri.https("nominatim.openstreetmap.org", "/reverse", {
      "lat": lat.toString(),
      "lon": lng.toString(),
      "format": "json", // Required format
    });

    try {
      final response = await http.get(
        uri,
        headers: {'Accept-Language': lang.toLanguageTag()},
      );

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Error ${response.statusCode}: ${response.body}',
          uri,
        );
      }

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse.containsKey('error')) {
        throw 'Error: ${jsonResponse['error']}';
      }

      // Extract address as a readable string
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
          "address": '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}',
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
    }
  }

}
