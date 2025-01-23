import 'package:mozayed_app/models/selling_location_model.dart';

class ListingItem {
  final String id;
  final String title;
  final String description;
  final String image;
  final double price;
  final String condition;
  final ListingLocation? location;

  const ListingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.price,
    required this.condition,
    this.location,
  });
}

class ListingLocation extends SellingLocation {
  const ListingLocation({
    required super.lat,
    required super.long,
    required super.address,
    super.city,
    super.zip,
  });
}