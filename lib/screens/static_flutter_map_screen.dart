import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class StaticMapPickerScreen extends StatefulWidget {
  const StaticMapPickerScreen({super.key});

  @override
  State<StaticMapPickerScreen> createState() {
    return _StaticMapPickerScreenState();
  }
}

class _StaticMapPickerScreenState extends State<StaticMapPickerScreen> {
  LatLng? _pickedLocation = const LatLng(37.422, -122.084);
  double _zoomLevel = 13.0;

  @override
  void initState() {
    super.initState();
    //_fetchInitialLocation();
  }

  Future<void> _fetchInitialLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    LocationData locationData = await location.getLocation();
    setState(() {
      _pickedLocation = LatLng(locationData.latitude!, locationData.longitude!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a Location'),
        actions: [
          IconButton(
            onPressed: () {
              if (_pickedLocation != null) {
                Navigator.of(context).pop<List<double>>([
                  _pickedLocation!.latitude,
                  _pickedLocation!.longitude,
                  _zoomLevel
                ]);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a location on the map.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.save),
          )
        ],
      ),
      body: _pickedLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        options: MapOptions(
          initialCenter: _pickedLocation!,
          initialZoom: _zoomLevel,
          onTap: (tabPosition, point) {
            setState(() {
              _pickedLocation = point;
            });
          },
          onPositionChanged: (position, hasGesture) {
            setState(() {
              _zoomLevel = position.zoom;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
          if (_pickedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _pickedLocation!,
                  child: Transform.translate(
                    offset: const Offset(-10, -30),
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 50,
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
