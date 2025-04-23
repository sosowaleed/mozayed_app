import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

/// A screen that displays a static map and allows the user to pick a location.
///
/// This screen uses the `flutter_map` package to render the map and allows
/// the user to select a location by tapping on the map. The selected location
/// is returned to the previous screen when the user saves their selection.
class StaticMapPickerScreen extends StatefulWidget {
  /// The initial latitude of the map's center.
  final double? lat;

  /// The initial longitude of the map's center.
  final double? lng;

  /// Constructor for the `StaticMapPickerScreen`.
  ///
  /// [lat] and [lng] are optional parameters that define the initial center
  /// of the map. If not provided, a default location is used.
  const StaticMapPickerScreen({super.key, this.lat, this.lng});

  @override
  State<StaticMapPickerScreen> createState() {
    return _StaticMapPickerScreenState();
  }
}

class _StaticMapPickerScreenState extends State<StaticMapPickerScreen> {
  /// The currently selected location on the map.
  LatLng? _pickedLocation;

  /// The current zoom level of the map.
  double _zoomLevel = 13.0;

  @override
  void initState() {
    super.initState();

    // Set the initial location to the provided latitude and longitude,
    // or use a default location if none are provided.
    if (widget.lat != null && widget.lng != null) {
      _pickedLocation = LatLng(widget.lat!, widget.lng!);
    } else {
      _pickedLocation = const LatLng(24.774265, 46.738586);
    }

    // Uncomment the following line to fetch the user's current location
    // when the screen is initialized.
    //_fetchInitialLocation();
  }

  /// Fetches the user's current location using the `location` package.
  ///
  /// This method checks for location service availability and permissions.
  /// If both are granted, it retrieves the user's current location and updates
  /// the map's center to that location.
  Future<void> _fetchInitialLocation() async {
    Location location = Location();

    // Check if location services are enabled.
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    // Check for location permissions.
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    // Retrieve the user's current location.
    LocationData locationData = await location.getLocation();
    setState(() {
      _pickedLocation = LatLng(locationData.latitude!, locationData.longitude!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pick a Location',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            onPressed: () {
              // If a location is selected, return it to the previous screen.
              if (_pickedLocation != null) {
                Navigator.of(context).pop<List<double>>([
                  _pickedLocation!.latitude,
                  _pickedLocation!.longitude,
                  _zoomLevel
                ]);
              } else {
                // Show a snackbar if no location is selected.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please select a location on the map.'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: Icon(
              Icons.save,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        ],
      ),
      body: _pickedLocation == null
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : FlutterMap(
              options: MapOptions(
                // Set the initial center and zoom level of the map.
                initialCenter: _pickedLocation!,
                initialZoom: _zoomLevel,
                onTap: (tabPosition, point) {
                  // Update the selected location when the map is tapped.
                  setState(() {
                    _pickedLocation = point;
                  });
                },
                onPositionChanged: (position, hasGesture) {
                  // Update the zoom level when the map's position changes.
                  setState(() {
                    _zoomLevel = position.zoom;
                  });
                },
              ),
              children: [
                // Add a tile layer to display the map.
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                ),
                if (_pickedLocation != null)
                  // Add a marker at the selected location.
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pickedLocation!,
                        child: Transform.translate(
                          offset: const Offset(-20, -40),
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 60,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
