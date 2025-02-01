import 'package:mozayed_app/models/selling_location_model.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserLocation location;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'location': location.toMap(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      location: UserLocation.fromMap(map['location']),
    );
  }
}

class UserLocation extends SellingLocation {
  final String? country;

  const UserLocation({
    required super.lat,
    required super.lng,
    required super.address,
    super.city,
    super.zip,
    this.country,
  });

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['country'] = country;
    return map;
  }

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      lat: map['lat'],
      lng: map['lng'],
      address: map['address'],
      city: map['city'],
      zip: map['zip'],
      country: map['country'],
    );
  }
}

