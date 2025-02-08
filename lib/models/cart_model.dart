import 'package:mozayed_app/models/listing_model.dart';

class CartItem {
  final ListingItem listing;
  final int quantity;

  CartItem({required this.listing, required this.quantity});

  CartItem copyWith({ListingItem? listing, int? quantity}) {
    return CartItem(
      listing: listing ?? this.listing,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listing': listing.toMap(),
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      listing: ListingItem.fromMap(map['listing']),
      quantity: map['quantity'],
    );
  }
}
