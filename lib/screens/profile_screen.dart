import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mozayed_app/screens/google_map_screen_picker.dart';
import 'package:mozayed_app/screens/static_flutter_map_screen.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// A screen that allows the user to update their profile information.
/// This includes fields such as name, email, password, and location.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _address; // Stores the user's address.
  String _password = "Old Password"; // Stores the user's password.
  final Map<String, dynamic> _userUpdates = {}; // Holds updated user data.
  final _formKey = GlobalKey<FormState>(); // Key for the form validation.
  bool _isGettingLocation = false; // Indicates if location is being fetched.

  // Tracks which fields the user wants to update.
  final Map<String, bool> _fieldsToUpdate = {
    'name': false,
    'email': false,
    'password': false,
    'location': false,
  };

  /// Marks all fields for update.
  void _checkAllFields() {
    setState(() {
      _fieldsToUpdate.updateAll((key, value) => true);
    });
  }

  /// Opens a map picker for the user to select a location.
  /// Updates the user's location data and address.
  Future<void> _loadMapPicker(UserModel user) async {
    List<double>? pickedLocation =
        await Navigator.of(context).push<List<double>>(MaterialPageRoute(
            builder: (ctx) => GoogleMapScreen(
                  latitude: user.location.lat,
                  longitude: user.location.lng,
                )));
    if (pickedLocation == null) {
      return;
    }
    setState(() {
      _isGettingLocation = true;
    });

    if (!mounted) return;
    if (kIsWeb) {
      // Fetch address using a web-based API.
      Map<String, dynamic> address = await _getAddressFromLatLngWeb(
        lat: pickedLocation[0],
        lng: pickedLocation[1],
        lang: Localizations.localeOf(context),
      );

      if (address["display_name"] != "address not found") {
        _userUpdates["location"] = {
          "lat": pickedLocation[0],
          "lng": pickedLocation[1],
          "address": address["display_name"],
          "city": address["address"]["city"],
          "zip": address["address"]["postcode"],
          "country": address["address"]["country"],
        };
        _fieldsToUpdate['location'] = true;
      }
      setState(() {
        _address = address["display_name"];
        _isGettingLocation = false;
      });
    } else {
      // Fetch address using the geocoding package.
      String address =
          await _getAddressFromLatLng(pickedLocation[0], pickedLocation[1]);
      _userUpdates["location"] = {
        "lat": pickedLocation[0],
        "lng": pickedLocation[1],
        "address": address,
      };
      _fieldsToUpdate['location'] = true;
      setState(() {
        _address = address;
        _isGettingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fetch the current user data.
    UserModel user = UserModel.fromMap(ref.watch(userDataProvider).value!);
    _address ??= user
        .location.address; // Use the user's current address if none was picked.

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: AutoSizeText("Profile",
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title of the profile updater.
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 20),
                      width: 200,
                      child: AutoSizeText(
                        "Profile Updater",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontSize: 19,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Button to select all fields for update.
                    ElevatedButton(
                      onPressed: _checkAllFields,
                      child: const Text("Select All Fields"),
                    ),
                    const SizedBox(height: 12),
                    // Name field with a checkbox.
                    Row(
                      children: [
                        Checkbox(
                          value: _fieldsToUpdate['name'],
                          onChanged: (val) {
                            setState(() {
                              _fieldsToUpdate['name'] = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: "Prev Name: ${user.name}",
                            ),
                            enableSuggestions: false,
                            validator: (username) {
                              if (_fieldsToUpdate['name'] == true &&
                                  (username == null ||
                                      username.trim().length < 4)) {
                                return "Please enter at least 4 characters.";
                              }
                              return null;
                            },
                            onSaved: (username) {
                              if (_fieldsToUpdate['name'] == true) {
                                _userUpdates['name'] = username!;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    // Email field with a checkbox.
                    Row(
                      children: [
                        Checkbox(
                          value: _fieldsToUpdate['email'],
                          onChanged: (val) {
                            setState(() {
                              _fieldsToUpdate['email'] = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: "Prev Email: ${user.email}",
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            validator: (email) {
                              if (_fieldsToUpdate['email'] == true &&
                                  (email == null ||
                                      email.trim().isEmpty ||
                                      !email.contains("@"))) {
                                return "Please enter a valid email address.";
                              }
                              return null;
                            },
                            onSaved: (email) {
                              if (_fieldsToUpdate['email'] == true) {
                                _userUpdates['email'] = email!;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Password field with a checkbox.
                    Row(
                      children: [
                        Checkbox(
                          value: _fieldsToUpdate['password'],
                          onChanged: (val) {
                            setState(() {
                              _fieldsToUpdate['password'] = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: "New Password",
                            ),
                            obscureText: true,
                            validator: (password) {
                              if (_fieldsToUpdate['password'] == true &&
                                  (password == null ||
                                      password.trim().length < 6)) {
                                return "Password must be at least 6 characters long.";
                              }
                              return null;
                            },
                            onSaved: (password) {
                              if (_fieldsToUpdate['password'] == true) {
                                _password = password!;
                                _userUpdates['password'] = _password;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Location field with a button and checkbox.
                    Row(
                      children: [
                        Checkbox(
                          value: _fieldsToUpdate['location'],
                          onChanged: (val) {
                            setState(() {
                              _fieldsToUpdate['location'] = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.map),
                            onPressed: () {
                              _loadMapPicker(user);
                            },
                            label: const AutoSizeText("Select on Map"),
                          ),
                        ),
                      ],
                    ),
                    _isGettingLocation
                        ? const CircularProgressIndicator()
                        : Text(_address ?? "No address"),
                    const SizedBox(height: 12),
                    // Save button to update all selected fields.
                    ElevatedButton(
                      onPressed: () async {
                        await _save(user);
                      },
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Saves the updated user data to Firebase Authentication and Firestore.
  Future<void> _save(UserModel user) async {
    if (!_formKey.currentState!.validate()) {
      return; // Stop if validation fails.
    }
    _formKey.currentState!.save();

    // Update Firebase Authentication for email and password.
    final currentUser = FirebaseAuth.instance.currentUser;
    try {
      if (_fieldsToUpdate['email'] == true &&
          _userUpdates.containsKey('email') &&
          _userUpdates['email'] != user.email) {
        await currentUser!.verifyBeforeUpdateEmail(_userUpdates['email']);
      }
      if (_fieldsToUpdate['password'] == true &&
          _userUpdates.containsKey('password')) {
        await currentUser!.updatePassword(_userUpdates['password']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Auth update failed: $e")),
        );
      }
      return;
    }

    // Update Firestore user document.
    try {
      _userUpdates.remove('password'); // Do not store password in Firestore.
      await ref.read(userDataProvider.notifier).updateUserData(_userUpdates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Firestore update failed: $e")),
        );
      }
    }
  }

  /// Fetches the address from latitude and longitude using a web-based API.
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

        _userUpdates["location"] = {
          "lat": latitude,
          "lng": longitude,
          "address":
              '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}',
          "city": place.locality,
          "zip": place.postalCode,
          "country": place.country,
        };

        return _userUpdates["location"]["address"];
      } else {
        return 'Address not found';
      }
    } catch (e) {
      setState(() {
        _address = "Please try another option, or later";
        _isGettingLocation = false;
      });
      return 'Address not found';
    }
  }
}
