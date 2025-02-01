import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool isSelecting;

  const GoogleMapScreen({
    super.key,
    this.latitude = 37.422,
    this.longitude = -122.084,
    this.isSelecting = true,
  });

  @override
  State<GoogleMapScreen> createState() {
    return _GoogleMapScreenState();
  }
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  LatLng? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
          Text(widget.isSelecting ? 'Pick your Location' : 'Your Location'),
          actions: [
            if (widget.isSelecting)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  Navigator.of(context).pop<LatLng>(_pickedLocation);
                },
              ),
          ]),
      body: GoogleMap(
        onTap: !widget.isSelecting
            ? null
            : (position) {
          setState(() {
            _pickedLocation = position;
          });
        },
        initialCameraPosition: CameraPosition(
          target: LatLng(
            widget.latitude,
            widget.longitude,
          ),
          zoom: 16,
        ),
        markers: (_pickedLocation == null && widget.isSelecting)
            ? {}
            : {
          Marker(
            markerId: const MarkerId('m1'),
            position: _pickedLocation ??
                LatLng(
                  widget.latitude,
                  widget.longitude,
                ),
          ),
        },
      ),
    );
  }
}