import 'package:mozayed_app/models/selling_location_model.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

enum SaleType { buyNow, bid } // Buy or bid system

class ListingItem {
  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String description;
  final List<String> image;
  final double price; // For bid, this might be the starting price.
  final String condition;
  final ListingLocation? location;
  final int quantity;
  final SaleType saleType; // Determines whether bidding is enabled
  final String category;

  ListingItem({
    String? id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.image,
    required this.price,
    required this.condition,
    this.location,
    this.quantity = 1,
    this.saleType = SaleType.buyNow,
    required this.category,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'title': title,
      'description': description,
      'image': image,
      'price': price,
      'condition': condition,
      'location': location?.toMap(),
      'quantity': quantity,
      'saleType': saleType.toString().split('.').last,
      'category': category,
    };
  }

  factory ListingItem.fromMap(Map<String, dynamic> map) {
    return ListingItem(
      id: map['id'],
      ownerId: map['ownerId'],
      ownerName: map['ownerName'],
      title: map['title'],
      description: map['description'],
      image: List<String>.from(map['image']),
      price: map['price'],
      condition: map['condition'],
      location: map['location'] != null ? ListingLocation.fromMap(map['location']) : null,
      quantity: map['quantity'] ?? 1,
      saleType: (map['saleType'] as String).toLowerCase() == 'bid' ? SaleType.bid : SaleType.buyNow,
      category: map['category'] ?? "Other",
    );
  }
}


class ListingLocation extends SellingLocation {
  final String? country;

  const ListingLocation({
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

  factory ListingLocation.fromMap(Map<String, dynamic> map) {
    return ListingLocation(
      lat: map['lat'],
      lng: map['lng'],
      address: map['address'],
      city: map['city'],
      zip: map['zip'],
      country: map['country'],
    );
  }
}