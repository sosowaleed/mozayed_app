import 'package:mozayed_app/models/user_model.dart';
import 'dart:math';
import 'package:faker/faker.dart';
import 'package:mozayed_app/models/listing_model.dart';

User generateDummyUser(int index) {
  final faker = Faker();
  final random = Random();
  return User(
    id: faker.guid.guid(),
    name: faker.person.name(),
    email: faker.internet.email(),
    items: List.generate(random.nextInt(5) + 1,
        (index) => generateDummyListingItem(index)),
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

ListingItem generateDummyListingItem(int id) {
  final faker = Faker();
  final random = Random();
  return ListingItem(
    id: faker.guid.guid(),
    title: 'Item ${id + 1}',
    description: faker.lorem.sentences(3).join(' '),
    image: [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Cat_November_2010-1a.jpg/1200px-Cat_November_2010-1a.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d8/A_kitten_sitting_on_the_floor.jpg/800px-A_kitten_sitting_on_the_floor.jpg',
    ],
    price: random.nextDouble() * 100 + 1,
    condition: faker.randomGenerator
        .element(['New', 'Used - Like New', 'Used - Good', 'Used - Fair']),
    location: ListingLocation(
      lat: faker.geo.latitude(),
      long: faker.geo.longitude(),
      address: faker.address.streetAddress(),
      city: faker.address.city(),
      zip: faker.address.zipCode(),
    ),
  );
}
