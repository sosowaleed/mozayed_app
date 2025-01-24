import 'package:mozayed_app/models/selling_location_model.dart';
import 'package:mozayed_app/models/listing_model.dart';

class User {
  final String id;
  final String name;
  final String email;
  final List<ListingItem> items;
  final UserLocation location;

  const User(
      {required this.id,
      required this.name,
      required this.email,
      required this.items,
      required this.location});
}

class UserLocation extends SellingLocation {
  final String? country;
  const UserLocation({
    required super.lat,
    required super.long,
    required super.address,
    super.city,
    super.zip,
    this.country,
  });
}

