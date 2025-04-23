import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

/// A screen widget that displays a Google Map and allows the user to select a location.
class GoogleMapScreen extends StatefulWidget {
  /// The initial latitude for the map's camera position.
  final double latitude;

  /// The initial longitude for the map's camera position.
  final double longitude;

  /// A flag indicating whether the user is selecting a location.
  final bool isSelecting;

  /// A flag indicating whether the location has already been fetched.
  final bool ifLocationFetched;

  /// Creates a `GoogleMapScreen` widget.
  ///
  /// [latitude] and [longitude] default to the coordinates of Riyadh, Saudi Arabia.
  /// [isSelecting] defaults to `true`, allowing the user to select a location.
  /// [ifLocationFetched] defaults to `false`, indicating the location has not been fetched yet.
  const GoogleMapScreen({
    super.key,
    this.latitude = 24.774265,
    this.longitude = 46.738586,
    this.isSelecting = true,
    this.ifLocationFetched = false,
  });

  @override
  State<GoogleMapScreen> createState() {
    return _GoogleMapScreenState();
  }
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  /// The location selected by the user.
  LatLng? _pickedLocation;

  /// The camera position for the Google Map.
  CameraPosition? _cameraPosition;

  /// A flag indicating whether the location has been fetched.
  bool _locationFetched = false;

  @override
  void initState() {
    super.initState();
    if (widget.ifLocationFetched) {
      // If the location is already fetched, set the initial location and camera position.
      setState(() {
        _pickedLocation = LatLng(widget.latitude, widget.longitude);
        _cameraPosition = CameraPosition(
          target: _pickedLocation!,
          zoom: 16,
        );
        _locationFetched = true;
      });
      return;
    }
    // Fetch the initial location if not already fetched.
    _fetchInitialLocation();
  }

  /// Fetches the user's current location using the `location` package.
  ///
  /// If location services or permissions are unavailable, sets a default location.
  Future<void> _fetchInitialLocation() async {
    Location location = Location();

    // Check if location services are enabled.
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }
    }

    // Check if location permissions are granted.
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        _setDefaultLocation();
        return;
      }
    }

    try {
      // Get the user's current location.
      LocationData locationData = await location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _pickedLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _cameraPosition = CameraPosition(
            target: _pickedLocation!,
            zoom: 16,
          );
          _locationFetched = true;
        });
        return;
      }
    } catch (_) {}
    // Set a default location if fetching the location fails.
    _setDefaultLocation();
  }

  /// Sets the default location to the widget's initial latitude and longitude.
  void _setDefaultLocation() {
    setState(() {
      _pickedLocation = LatLng(widget.latitude, widget.longitude);
      _cameraPosition = CameraPosition(
        target: _pickedLocation!,
        zoom: 16,
      );
      _locationFetched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isSelecting ? 'Pick your Location' : 'Your Location',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          if (widget.isSelecting)
            IconButton(
              icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary),
              onPressed: () {
                // Return the selected location's latitude and longitude when saving.
                Navigator.of(context).pop<List<double>>(
                    [_pickedLocation!.latitude, _pickedLocation!.longitude]);
              },
            ),
        ],
      ),
      body: !_locationFetched
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onTap: !widget.isSelecting
                  ? null
                  : (position) {
                      // Update the selected location and camera position when the map is tapped.
                      setState(() {
                        _pickedLocation = position;
                        _cameraPosition = CameraPosition(target: position, zoom: 16);
                      });
                    },
              initialCameraPosition: _cameraPosition!,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              markers: {
                Marker(
                  markerId: const MarkerId('m1'),
                  position: _pickedLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(
                    title: 'Selected Location',
                    snippet: 'This is the location you selected.',
                  ),
                )
              },
            ),
    );
  }
}