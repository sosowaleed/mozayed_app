import 'package:uuid/uuid.dart';

const uuid = Uuid();

class ReportModel {
  final String id;
  final String category;
  final String flag;
  final String description;
  final String reporterId;
  final String reporterEmail;
  final String listingId;
  final String listingTitle;
  final String listingOwnerId;
  final List<String> image;
  final String listingOwnerName;
  final String listingCondition;
  final bool handled;
  final String? currentHighestBidderId; // only for bid listings
  final String timestamp;

  ReportModel({
    required this.id,
    required this.category,
    required this.flag,
    required this.description,
    required this.reporterId,
    required this.reporterEmail,
    required this.listingId,
    required this.listingTitle,
    required this.listingOwnerId,
    required this.listingOwnerName,
    required this.listingCondition,
    this.handled = false,
    this.currentHighestBidderId,
    required this.image,
    required this.timestamp,
  });

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    return ReportModel(
      id: id,
      category: map['category'] as String,
      flag: map['flag'] as String,
      description: map['description'] as String,
      reporterId: map['reporterId'] as String,
      reporterEmail: map['reporterEmail'] as String,
      listingId: map['listingId'] as String,
      listingTitle: map['listingTitle'] as String,
      listingOwnerId: map['listingOwnerId'] as String,
      listingOwnerName: map['listingOwnerName'] as String,
      listingCondition: map['listingCondition'] as String,
      image: List<String>.from(map['image']),
      handled: map['handled'] as bool? ?? false,
      currentHighestBidderId: map['currentHighestBidderId'] as String?,
      timestamp: map['timestamp'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'flag': flag,
      'description': description,
      'reporterId': reporterId,
      'reporterEmail': reporterEmail,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingOwnerId': listingOwnerId,
      'listingOwnerName': listingOwnerName,
      'listingCondition': listingCondition,
      'image': image,
      'handled': handled,
      'currentHighestBidderId': currentHighestBidderId,
      'timestamp': timestamp,
    };
  }
}
