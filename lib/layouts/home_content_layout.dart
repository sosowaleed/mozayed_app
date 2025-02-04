import 'package:flutter/material.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/widgets/listing_widget.dart';
import 'package:mozayed_app/dummy_data/user_dummydata.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // Filter parameters with default values.
  String _selectedCondition = "Any";
  String _selectedSaleType = "Any";
  String _selectedCategory = "Any";
  String _maxPriceText = "";

  late List<ListingItem> _allListings;
  List<ListingItem> _filteredListings = [];

  // Options for dropdowns.
  final List<String> _conditionOptions = [
    "Any",
    "New",
    "Used: feels new",
    "Used: good",
    "Used: acceptable"
  ];

  final List<String> _categoryOptions = [
    "Any",
    "Furniture",
    "Electronics",
    "Clothing",
    "Home",
    "Books",
    "Toys",
    "Other"
  ];

  final List<String> _saleTypeOptions = [
    "Any",
    "Buy",
    "Bid",
  ];

  @override
  void initState() {
    super.initState();
    // Generate dummy data.
    _allListings = List.generate(50, (index) {
      return generateDummyListingItem();
    });
    // Initially, show all listings.
    _filteredListings = List.from(_allListings);
  }

  /// Called when the user presses the Filter button.
  void _applyFilter() {
    setState(() {
      double? maxPrice;
      if (_maxPriceText.isNotEmpty) {
        maxPrice = double.tryParse(_maxPriceText);
      }
      _filteredListings = _allListings.where((listing) {
        // Check condition if not "Any"
        bool conditionMatches = _selectedCondition == "Any" ||
            listing.condition.toLowerCase() == _selectedCondition.toLowerCase();
        // Check sale type if not "Any"
        bool saleTypeMatches = _selectedSaleType == "Any" ||
            ((_selectedSaleType.toLowerCase() == "buy" &&
                listing.saleType.name.toLowerCase().contains("buy")) ||
                (_selectedSaleType.toLowerCase() == "bid" &&
                    listing.saleType.name.toLowerCase().contains("bid")));
        bool categoryMatches = _selectedCategory == "Any" ||
            listing.category.toLowerCase() == _selectedCategory.toLowerCase();
        // Check price if maxPrice is specified.
        bool priceMatches = maxPrice == null || listing.price <= maxPrice;
        return conditionMatches && saleTypeMatches && categoryMatches && priceMatches;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 2;
      if (constraints.maxWidth >= 1200 && constraints.maxHeight >= 500) {
        crossAxisCount = 6;
      } else if (constraints.maxWidth >= 735 && constraints.maxHeight >= 400) {
        crossAxisCount = 5;
      } else if (constraints.maxWidth >= 600) {
        crossAxisCount = 3;
      }

      return Column(
        children: [
          // Filter Bar
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Condition Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: "Condition",
                          ),
                          value: _selectedCondition,
                          items: _conditionOptions
                              .map((condition) => DropdownMenuItem<String>(
                            value: condition,
                            child: Text(condition),
                          ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCondition = val!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sale Type Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: "Sale Type",
                          ),
                          value: _selectedSaleType,
                          items: _saleTypeOptions
                              .map((saleType) => DropdownMenuItem<String>(
                            value: saleType,
                            child: Text(saleType),
                          ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedSaleType = val!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Category Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: "Category",
                          ),
                          value: _selectedCategory,
                          items: _categoryOptions
                              .map((category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCategory = val!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Price Filter
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: "Max Price",
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            _maxPriceText = val;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _applyFilter,
                        child: const Text("Filter"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Listings Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                key: UniqueKey(), // Forces a rebuild when _filteredListings changes
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _filteredListings.length,
                itemBuilder: (context, index) {
                  return ListingWidget(
                    key: ValueKey(_filteredListings[index].id),
                    listingItem: _filteredListings[index],
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }
}
