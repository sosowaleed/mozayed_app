import 'dart:developer';

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
  double price; // For bid, this might be the starting price.
  final String condition;
  final ListingLocation? location;
  int quantity;
  final SaleType saleType; // Determines whether bidding is enabled
  final String category;
  // --- Bidding fields (only used if saleType is bid) ---
  final DateTime? bidEndTime;
  final double? startingBid; // initial bid amount
  double? currentHighestBid;
  String? currentHighestBidderId;
  List<Map<String, dynamic>>? bidHistory; // each entry: {bidderId, bidAmount, bidTime}
  final bool bidFinalized;


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
    this.bidEndTime,
    this.startingBid,
    this.currentHighestBid,
    this.currentHighestBidderId,
    this.bidHistory,
    this.bidFinalized = false,
  }) : id = id ?? uuid.v4();

  void setCurrentHighestBid(double newBid) {
    if (saleType == SaleType.bid) {
      currentHighestBid = newBid;
      setPrice(newBid);
    } else {
      log(
          'you cannot set the currentHighestBid since the sale type is not bid');
    }
  }

  void setPrice(double newPrice) {
    price = newPrice;
  }

  void setQuantity(int newQuantity) {
    quantity = newQuantity;
  }

  void setCurrentHighestBidderId(String? newCurrentHighestBidderId) {
    if (saleType == SaleType.bid) {
      currentHighestBidderId = newCurrentHighestBidderId;
    } else {
      log(
          'you cannot set the currentHighestBidderId since the sale type is not bid');
    }
  }

  void setBidHistory(Map<String, dynamic> newBidHistory) {
    if (saleType == SaleType.bid) {
      bidHistory == null ? bidHistory = [newBidHistory] : bidHistory!.add(newBidHistory);
    } else {
      log(
          'you cannot set the bidHistory since the sale type is not bid');
    }
  }


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
      'bidEndTime': bidEndTime?.toIso8601String(),
      'startingBid': startingBid,
      'currentHighestBid': currentHighestBid,
      'currentHighestBidderId': currentHighestBidderId,
      'bidHistory': bidHistory,
      'bidFinalized': bidFinalized,
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
      bidEndTime: map['bidEndTime'] != null ? DateTime.parse(map['bidEndTime']) : null,
      startingBid: map['startingBid'] != null ? (map['startingBid'] as num).toDouble() : null,
      currentHighestBid: map['currentHighestBid'] != null ? (map['currentHighestBid'] as num).toDouble() : null,
      currentHighestBidderId: map['currentHighestBidderId'],
      bidHistory: map['bidHistory'] != null ? List<Map<String, dynamic>>.from(map['bidHistory']) : null,
      bidFinalized: map['bidFinalized'] ?? false,
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