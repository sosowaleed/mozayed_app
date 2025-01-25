import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/dummy_data/user_dummydata.dart';
import 'package:faker/faker.dart' as faker;

class ListingWidget extends StatefulWidget {
  const ListingWidget({super.key});

  @override
  State<ListingWidget> createState() => _ListingWidgetState();
}

class _ListingWidgetState extends State<ListingWidget> {
  ListingItem listingItem =
  generateDummyListingItem(faker.faker.person.name(), faker.faker.guid.guid());
  int _currentImageIndex = 0;

  bool isPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < 600; // Adjust breakpoint as needed
  }

  void _previousImage() {
    setState(() {
      _currentImageIndex = (_currentImageIndex - 1) % listingItem.image.length;
      if (_currentImageIndex < 0) {
        _currentImageIndex = listingItem.image.length - 1;
      }
    });
  }

  void _nextImage() {
    setState(() {
      _currentImageIndex = (_currentImageIndex + 1) % listingItem.image.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneLayout = isPhone(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      margin: const EdgeInsets.all(8.0),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Image Section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Hero(
                  tag: listingItem.id,
                  child: Image.network(
                    listingItem.image[_currentImageIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: isPhoneLayout ? 250 : 500,
                  ),
                ),
              ),
              if (!isPhoneLayout)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _previousImage,
                    color: Colors.white,
                    iconSize: 24,
                    style: const ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.black38),
                    ),
                  ),
                ),
              if (!isPhoneLayout)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _nextImage,
                    color: Colors.white,
                    iconSize: 24,
                    style: const ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.black38),
                    ),
                  ),
                ),
              if (listingItem.image.length > 1)
                Positioned(
                  right: 0,
                  child: AutoSizeText(
                    '${_currentImageIndex + 1}/${listingItem.image.length}',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[300],
                    ),
                  ),
                ),
            ],
          ),
          // Metadata Section
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    listingItem.title,
                    softWrap: true,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(237, 237, 237, 1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4,),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text.rich(
                        softWrap: true,
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '\$${listingItem.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromRGBO(237, 237, 237, 1)),
                            ),
                            TextSpan(
                              text: ' / SAR',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[300],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Expanded(
                        child: AutoSizeText(
                          listingItem.condition,
                          style: TextStyle(color: Colors.grey[200], fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
