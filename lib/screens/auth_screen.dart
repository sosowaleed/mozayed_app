import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mozayed_app/screens/google_map_screen_picker.dart';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:mozayed_app/screens/static_flutter_map_screen.dart';

/// Firebase Authentication instance
final _firebaseAuth = FirebaseAuth.instance;

/// A StatefulWidget for user authentication (login and signup).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _password = ""; // Stores the user's password
  String _address = "No address"; // Stores the user's address
  final _formKey = GlobalKey<FormState>(); // Key for the form validation
  final Map<String, dynamic> _userModel = {}; // Stores user data
  bool _isLogin = true; // Tracks whether the user is logging in or signing up
  bool _isGettingLocation = false; // Tracks if the app is fetching the user's location

  /// Handles saving the form data and performing login or signup.
  void _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    // Only for signup: Check if location is provided
    if (!_isLogin) {
      if (_userModel["location"] == null ||
          _userModel["location"]["address"] == null ||
          _userModel["location"]["address"] == "No address" ||
          _userModel["location"]["address"] == "Address not found" ||
          _userModel["location"]["address"] == "Please try another option, or later") {
        setState(() {
          _address = "Please select your location before signing up.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location is required for registration.")),
        );
        return;
      }
    }

    try {
      if (_isLogin) {
        // Sign in with email and password
        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: _userModel['email'],
          password: _password,
        );
      } else {
        // Create a new user with email and password
        final userCredential = await _firebaseAuth
            .createUserWithEmailAndPassword(email: _userModel['email'], password: _password);

        // Add user data to Firestore
        _userModel["id"] = userCredential.user!.uid;
        _userModel["admin"] = false; // Default to false, enabled by backend later
        _userModel["suspended"] = false; // Default to false
        _userModel["activated"] = true; // Default to true

        await FirebaseFirestore.instance
            .collection("users")
            .doc(userCredential.user!.uid)
            .set(_userModel);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.message ?? "Authentication has failed.")),
        );
      }
    }
  }

  /// Fetches the address from latitude and longitude using OpenStreetMap API (for web).
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

  /// Fetches the address from latitude and longitude using the geocoding package.
  Future _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      final List<geo.Placemark> placeMarks =
      await geo.placemarkFromCoordinates(latitude, longitude);
      if (placeMarks.isNotEmpty) {
        final geo.Placemark place = placeMarks.first;

        _userModel["location"] = {
          "lat": latitude,
          "lng": longitude,
          "address": '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}',
          "city": place.locality,
          "zip": place.postalCode,
          "country": place.country,
        };

        return _userModel["location"]["address"];
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

  /// Fetches the user's current location and updates the address.
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return;
      }
    }

    setState(() {
      _isGettingLocation = true;
    });

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) {
      return;
    }
    if (kIsWeb) {
      Map<String, dynamic> address = await _getAddressFromLatLngWeb(
        lat: position.latitude,
        lng: position.longitude,
        lang: Localizations.localeOf(context),
      );
      if(address["display_name"] != "address not found") {
        _userModel["location"] = {
          "lat": position.latitude,
          "lng": position.longitude,
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
      String address = await _getAddressFromLatLng(position.latitude, position.longitude);
      setState(() {
        _address =  address;
        _isGettingLocation = false;
      });
    }
  }

  /// Opens a Google Map picker for the user to select a location.
  Future<void> _loadMapGooglePicker() async {
    LatLng? position = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(builder: (ctx) => const GoogleMapScreen()
        ));
    if (position == null) {
      return;
    }
    setState(() {
      _isGettingLocation = true;
    });
    // For Google Maps implementation
    final lat = position.latitude;
    final lng = position.longitude;
    if (!mounted) {
      return;
    }
    if (kIsWeb) {
      Map<String, dynamic> address = await _getAddressFromLatLngWeb(
        lat: lat,
        lng: lng,
        lang: Localizations.localeOf(context),
      );

      if(address["display_name"] != "address not found") {
        _userModel["location"] = {
          "lat": lat,
          "lng": lng,
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
      String address = await _getAddressFromLatLng(lat, lng);
      setState(() {
        _address =  address;
        _isGettingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App title
              Container(
                margin: const EdgeInsets.only(
                    top: 30, bottom: 20, left: 20, right: 20),
                width: 200,
                child:  AutoSizeText(
                  'Mozayed',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Theme.of(context).colorScheme.surface, blurRadius: 2, offset: const Offset(1, 1))],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // App subtitle
              Container(
                margin: const EdgeInsets.only(
                    top: 0, bottom: 20, left: 20, right: 20),
                width: 200,
                child: AutoSizeText(
                  "Location based marketplace.",
                  style:  TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 16,
                    shadows: [
                      Shadow(color: Theme.of(context).colorScheme.surface, offset: const Offset(1, 1)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Authentication form
              Card(
                margin: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Username field (only for signup)
                          if (!_isLogin)
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: "Username",
                              ),
                              enableSuggestions: false,
                              validator: (username) {
                                if (username == null ||
                                    username.trim().length < 4) {
                                  return "Please enter at least 4 characters.";
                                }
                                return null;
                              },
                              onSaved: (username) {
                                _userModel['name'] = username!;
                              },
                            ),
                          // Email field
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: "Email Address",
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            validator: (email) {
                              if (email == null ||
                                  email.trim().isEmpty ||
                                  !email.contains("@")) {
                                return "Please enter a valid email address.";
                              }
                              return null;
                            },
                            onSaved: (email) {
                              _userModel['email'] = email!;
                            },
                          ),
                          // Password field
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: "Password",
                            ),
                            obscureText: true,
                            validator: (password) {
                              if (password == null ||
                                  password.trim().length < 6) {
                                return "Password must be at least 6 characters long.";
                              }
                              return null;
                            },
                            onSaved: (password) {
                              _password = password!;
                            },
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          // Location options (only for signup)
                          if (!_isLogin)
                            Column(
                              children: [
                                Wrap(
                                  spacing: 8.0, // Space between buttons
                                  alignment: WrapAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.location_on),
                                      onPressed: _getCurrentLocation,
                                      label: const AutoSizeText(
                                          "Get Current Location"),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.map),
                                      onPressed: _loadMapGooglePicker,
                                      label:
                                      const AutoSizeText("Select on Map"),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                _isGettingLocation
                                    ? const CircularProgressIndicator()
                                    : Text(_address),
                              ],
                            ),
                          const SizedBox(
                            height: 12,
                          ),
                          // Submit button
                          ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                            ),
                            child: Text(_isLogin ? "Login" : "SignUp"),
                          ),
                          // Toggle between login and signup
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? "Create new account"
                                  : "I already have an account", style: TextStyle(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}