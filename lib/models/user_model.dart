import 'package:mozayed_app/models/selling_location_model.dart';

/// Represents a user in the application.
class UserModel {
  final String id;
  final String name;
  final String email;
  final bool admin;
  final bool suspended;
  final bool activated;
  final UserLocation location;

  /// Constructor for creating a [UserModel] instance.
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.location,
    this.admin = false, // Defaults to non-admin.
    this.suspended = false, // Defaults to not suspended.
    this.activated = true, // Defaults to activated.
  });

  /// Converts the [UserModel] instance to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'admin': admin,
      'suspended': suspended,
      'activated': activated,
      'location': location.toMap(),
    };
  }

  /// Creates a [UserModel] instance from a map (deserialization).
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      admin: map['admin'] ?? false,
      suspended: map['suspended'] ?? false,
      activated: map['activated'] ?? true,
      location: UserLocation.fromMap(map['location']),
    );
  }
}

/// Represents the location details of a user.
class UserLocation extends SellingLocation {
  final String? country; // Optional country information.

  /// Constructor for creating a [UserLocation] instance.
  const UserLocation({
    required super.lat,
    required super.lng,
    required super.address,
    super.city,
    super.zip,
    this.country,
  });

  /// Converts the [UserLocation] instance to a map for serialization.
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['country'] = country;
    return map;
  }

  /// Creates a [UserLocation] instance from a map (deserialization).
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

