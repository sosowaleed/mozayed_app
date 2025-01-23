class SellingLocation {
  final double lat;
  final double long;
  final String address;
  final String? city;
  final String? zip;

  const SellingLocation({
    required this.lat,
    required this.long,
    required this.address,
    this.zip,
    this.city,
  });
}