
import 'dart:math';
import 'package:faker/faker.dart';
import 'package:mozayed_app/models/listing_model.dart';

ListingItem generateDummyListingItem() {
  final faker = Faker();
  final random = Random();
  final listingId = faker.guid.guid();
  return ListingItem(
    ownerId: listingId,
    ownerName: faker.person.name(),
    title: 'Item $listingId',
    description: faker.lorem.sentences(3).join(' '),
    image: [
      'https://upload.wikimedia.org/wikipedia/commons/7/7e/Camera_%282427208833%29.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/5/59/Creatures_mockup.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/a/ad/Close-up_of_a_Squaw_dress_made_by_a_Hopi_man%2C_ca.1900_%28CHS-5889%29.jpg',
    ],
    price: random.nextDouble() * 100 + 1,
    condition: faker.randomGenerator
        .element(["New", "Used: feels new", "Used: good", "Used: acceptable"]),
    saleType: faker.randomGenerator.element([SaleType.bid, SaleType.buyNow]),
    category: faker.randomGenerator
        .element(["Furniture","Electronics", "Clothing", "Home", "Books", "Toys", "Other"]),
    location: ListingLocation(
      lat: faker.geo.latitude(),
      lng: faker.geo.longitude(),
      address: faker.address.streetAddress(),
      city: faker.address.city(),
      zip: faker.address.zipCode(),
      country: faker.randomGenerator.element([faker.address.country(), "Saudi Arabia"]),
    ),
  );
}
