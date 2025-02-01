import 'package:uuid/uuid.dart';

const uuid = Uuid();

class SellingLocation {
  final double lat;
  final double lng;
  final String address;
  final String? city;
  final String? zip;

  const SellingLocation({
    required this.lat,
    required this.lng,
    required this.address,
    this.city,
    this.zip,
  });

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'address': address,
      'city': city,
      'zip': zip,
    };
  }

  factory SellingLocation.fromMap(Map<String, dynamic> map) {
    return SellingLocation(
      lat: map['lat'],
      lng: map['lng'],
      address: map['address'],
      city: map['city'],
      zip: map['zip'],
    );
  }
}