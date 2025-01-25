import 'package:mozayed_app/models/selling_location_model.dart';

class ListingItem {
  final String id;
  final String ownerName;
  final String title;
  final String description;
  final List<String> image;
  final double price;
  final String condition;
  final ListingLocation? location;
  final String ownerId;

  const ListingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.price,
    required this.condition,
    required this.ownerName,
    required this.ownerId,
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