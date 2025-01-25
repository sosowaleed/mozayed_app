import 'package:mozayed_app/models/user_model.dart';
import 'dart:math';
import 'package:faker/faker.dart';
import 'package:mozayed_app/models/listing_model.dart';

User generateDummyUser() {
  final faker = Faker();
  final random = Random();
  final ownerId = faker.guid.guid();
  final ownerName = faker.person.name();
  return User(
    id: ownerId,
    name: ownerName,
    email: faker.internet.email(),
    items: List.generate(random.nextInt(5) + 1,
        (index) => generateDummyListingItem(ownerName, ownerId)),
    location: UserLocation(
      lat: faker.geo.latitude(),
      long: faker.geo.longitude(),
      address: faker.address.streetAddress(),
      city: faker.address.city(),
      zip: faker.address.zipCode(),
      country: faker.address.country(),
    ),
  );
}

ListingItem generateDummyListingItem(String ownerName, String ownerId) {
  final faker = Faker();
  final random = Random();
  final listingId = faker.guid.guid();
  return ListingItem(
    id: listingId,
    ownerId: ownerId,
    ownerName: ownerName,
    title: 'Item $listingId',
    description: faker.lorem.sentences(3).join(' '),
    image: [
      'https://upload.wikimedia.org/wikipedia/commons/7/7e/Camera_%282427208833%29.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/5/59/Creatures_mockup.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/a/ad/Close-up_of_a_Squaw_dress_made_by_a_Hopi_man%2C_ca.1900_%28CHS-5889%29.jpg',
    ],
    price: random.nextDouble() * 100 + 1,
    condition: faker.randomGenerator
        .element(['New', 'Used: Good', 'Used:Fair']),
    location: ListingLocation(
      lat: faker.geo.latitude(),
      long: faker.geo.longitude(),
      address: faker.address.streetAddress(),
      city: faker.address.city(),
      zip: faker.address.zipCode(),
    ),
  );
}
