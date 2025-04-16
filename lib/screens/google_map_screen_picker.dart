import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class GoogleMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool isSelecting;
  final bool ifLocationFetched;

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
  LatLng? _pickedLocation;
  CameraPosition? _cameraPosition;
  bool _locationFetched = false;

  @override
  void initState() {
    super.initState();
    if (widget.ifLocationFetched) {
      setState(() {
        _pickedLocation = LatLng(widget.latitude, widget.longitude);
        _cameraPosition = CameraPosition(
          target: _pickedLocation!,
          zoom: 16,);
        _locationFetched = true;
      });
      return;
    }
    _fetchInitialLocation();
  }

  Future<void> _fetchInitialLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        _setDefaultLocation();
        return;
      }
    }

    try {
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
    _setDefaultLocation();
  }

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
        title: Text(widget.isSelecting ? 'Pick your Location' : 'Your Location',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
            )),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          if (widget.isSelecting)
            IconButton(
              icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary),
              onPressed: () {
                Navigator.of(context).pop<LatLng>(_pickedLocation);
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
          setState(() {
            _pickedLocation = position;
            _cameraPosition = CameraPosition(target: position, zoom: 16);
          });
        },
        initialCameraPosition: _cameraPosition!,
        markers: {
          Marker(
            markerId: const MarkerId('m1'),
            position: _pickedLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
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