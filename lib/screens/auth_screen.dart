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

import 'package:mozayed_app/screens/static_flutter_map_screen.dart';

final _firebaseAuth = FirebaseAuth.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _password = "";
  String _address = "No address";
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _userModel = {};
  bool _isLogin = true;
  bool _isGettingLocation = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) {
      if (_address == "No address" || _address == "Address not found") {
        setState(() {
          _address = "Please try another option, or later";
        });
        return;
      }
      return;
    }
    _formKey.currentState!.save();

    try {
      if (_isLogin) {
        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: _userModel['email'],
          password: _password,
        );
      } else {
        final userCredential = await _firebaseAuth
            .createUserWithEmailAndPassword(email: _userModel['email'], password: _password);

        _userModel["id"] = userCredential.user!.uid;
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

  Future<void> _getCurrentLocationGoogleMaps() async {
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
    //TODO: add google maps implementation
    /*//for Google maps implementation
    final lat = position.latitude;
    final lng = position.longitude;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=YOUR_API_KEY'); //need api key!
    final response = await http.get(url);
    final resData = json.decode(response.body);
    _userModel["location"] = {
      "lat": lat,
      "lng": lng,
      "address": resData['results'][0]['formatted_address'],
      "city": resData['results'][0]['address_components'][5]['long_name'],
      "zip": resData['results'][0]['address_components'][7]['long_name'],
      "country": resData['results'][0]['address_components'][6]['long_name'],
    };
    setState(() {
      _address = _userModel["location"]["address"];
    });
     */
  }

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

  Future<void> _loadMapGooglePicker() async {
    LatLng? pickedLocation = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(builder: (ctx) => const GoogleMapScreen()
    ));
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.onSurface,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(
                    top: 30, bottom: 20, left: 20, right: 20),
                width: 200,
                child: AutoSizeText(
                  "Mozayed",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(
                    top: 0, bottom: 20, left: 20, right: 20),
                width: 200,
                child: AutoSizeText(
                  "Location based marketplace.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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
                                      onPressed: _loadMapPicker,
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
                          ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                            ),
                            child: Text(_isLogin ? "Login" : "SignUp"),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? "Create new account"
                                  : "I already have an account",
                              style: const TextStyle(color: Colors.blue),
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
