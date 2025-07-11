import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/widgets/listing_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/providers/listing_provider.dart';

/// An enum representing the location scope for filtering listings.
enum LocationScope { everywhere, city, country }

/// A stateful widget that displays the home content, including a list of filtered listings
/// and a filter bar for users to refine their search criteria.
class HomeContent extends ConsumerStatefulWidget {
  /// Whether to display admin-specific information.
  final bool adminInfo;

  /// Constructor for the `HomeContent` widget.
  const HomeContent({super.key, this.adminInfo = false});

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  // Filter parameters with default values.
  String _selectedCondition = "Any"; // Selected condition filter.
  String _selectedSaleType = "Any"; // Selected sale type filter.
  String _selectedCategory = "Any"; // Selected category filter.
  String _maxPriceText = ""; // Maximum price filter input.
  String _maxDistanceText = ""; // Maximum distance filter input (in kilometers).
  List<ListingItem> _filteredListings = []; // List of filtered listings.

  // Location scope filter (default is Everywhere).
  LocationScope _selectedLocationScope = LocationScope.everywhere;

  // Whether the filter inputs are visible.
  bool _showFilters = false;

  // Whether the filter has been applied.
  bool _filterApplied = false;

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
    "Car",
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

  // Default user location (fallback) if not available.
  final double _defaultUserLat = 24.774265; // Default latitude.
  final double _defaultUserLng = 46.738586; // Default longitude.

  /// Applies the filter to the list of listings based on the selected criteria.
  ///
  /// - Filters by condition, sale type, category, price, distance, and location scope.
  /// - Updates the `_filteredListings` state with the filtered results.
  void _applyFilter(List<ListingItem> allListings) {
    setState(() {
      double? maxPrice;
      if (_maxPriceText.isNotEmpty) {
        maxPrice = double.tryParse(_maxPriceText);
      }
      double? maxDistance;
      if (_maxDistanceText.isNotEmpty) {
        maxDistance = double.tryParse(_maxDistanceText);
      }

      // Get user's location data from the provider.
      final userData = ref.read(userDataProvider).maybeWhen(
        data: (data) => data,
        orElse: () => null,
      );
      double userLat = _defaultUserLat;
      double userLng = _defaultUserLng;
      String? userCity;
      String? userCountry;
      if (userData != null && userData["location"] != null) {
        userLat = (userData["location"]["lat"] as num).toDouble();
        userLng = (userData["location"]["lng"] as num).toDouble();
        userCity = userData["location"]["city"];
        userCountry = userData["location"]["country"];
      }

      // Filter the listings based on the criteria.
      List<ListingItem> filteredListings = allListings.where((listing) {
        // Condition Filter.
        bool conditionMatches = _selectedCondition == "Any" ||
            listing.condition.toLowerCase() ==
                _selectedCondition.toLowerCase();
        // Sale Type Filter.
        bool saleTypeMatches = _selectedSaleType == "Any" ||
            ((_selectedSaleType.toLowerCase() == "buy" &&
                listing.saleType.name.toLowerCase().contains("buy")) ||
                (_selectedSaleType.toLowerCase() == "bid" &&
                    listing.saleType.name.toLowerCase().contains("bid")));
        // Category Filter.
        bool categoryMatches = _selectedCategory == "Any" ||
            listing.category.toLowerCase() ==
                _selectedCategory.toLowerCase();
        // Price Filter.
        bool priceMatches =
            maxPrice == null || listing.price <= maxPrice;
        // Distance Filter.
        bool distanceMatches = true;
        if (maxDistance != null && listing.location != null) {
          double distanceMeters = Geolocator.distanceBetween(
              userLat, userLng, listing.location!.lat, listing.location!.lng);
          distanceMatches = distanceMeters <= maxDistance * 1000;
        }
        // Location Scope Filter.
        bool locationScopeMatches = true;
        if (_selectedLocationScope == LocationScope.city) {
          locationScopeMatches = listing.location != null &&
              listing.location!.city != null &&
              userCity != null &&
              listing.location!.city!.toLowerCase() == userCity.toLowerCase();
        } else if (_selectedLocationScope == LocationScope.country) {
          locationScopeMatches = listing.location != null &&
              listing.location!.country != null &&
              userCountry != null &&
              listing.location!.country!.toLowerCase() == userCountry.toLowerCase();
        }
        return conditionMatches &&
            saleTypeMatches &&
            categoryMatches &&
            priceMatches &&
            distanceMatches &&
            locationScopeMatches;
      }).toList();
      // Update our filtered list.
      _filteredListings = filteredListings;
      _filterApplied = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the listings provider.
    final listingsAsync = ref.watch(listingsProvider);

    return listingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text("Error loading listings: $error")),

      data: (allListings) {
        // Only update _filteredListings with all listings if no filter is applied.
        if (!_filterApplied) {
          _filteredListings = List.from(allListings);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            // Determine the number of columns in the grid based on screen size.
            int crossAxisCount = 2;
            if (constraints.maxWidth >= 1200 && constraints.maxHeight >= 500) {
              crossAxisCount = 6;
            } else if (constraints.maxWidth >= 735 && constraints.maxHeight >= 400) {
              crossAxisCount = 5;
            } else if (constraints.maxWidth >= 600) {
              crossAxisCount = 3;
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Refresh the listings provider.
                ref.refresh(listingsProvider);
                // Optionally wait a moment to show the indicator.
                await Future.delayed(const Duration(seconds: 1));
              },
              child: Column(
                children: [
                  // Filter Toggle Button with arrow icon.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,),
                          onPressed: () {
                            setState(() {
                              _showFilters = !_showFilters;
                            });
                          },
                          icon: AnimatedRotation(
                            turns: _showFilters ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(Icons.arrow_drop_down),
                          ),
                          label: Text(
                              "Filters",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                        ),
                      ],
                    ),
                  ),
                  // Expandable Filter Bar.
                  if (_showFilters)
                    Card(
                      margin: const EdgeInsets.all(8.0),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Condition Dropdown.
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration:  InputDecoration(
                                      fillColor: Theme.of(context).colorScheme.onInverseSurface,
                                      filled: true,
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
                                // Sale Type Dropdown.
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration:  InputDecoration(
                                      fillColor: Theme.of(context).colorScheme.onInverseSurface,
                                      filled: true,
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
                                // Category Dropdown.
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      fillColor: Theme.of(context).colorScheme.onInverseSurface,
                                      filled: true,
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
                                // Price Filter.
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      fillColor: Theme.of(context).colorScheme.onInverseSurface,
                                      filled: true,
                                      labelText: "Max Price",
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      _maxPriceText = val;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Max Distance Filter (km).
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      fillColor: Theme.of(context).colorScheme.onInverseSurface,
                                      filled: true,
                                      labelText: "Max Distance (km)",
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      _maxDistanceText = val;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Location Scope Radio Buttons.
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       AutoSizeText("Location Scope:", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                      RadioListTile<LocationScope>(
                                        title:  AutoSizeText("Everywhere", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                        value: LocationScope.everywhere,
                                        groupValue: _selectedLocationScope,
                                        dense: true,
                                         contentPadding: EdgeInsets.zero,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedLocationScope = value!;
                                          });
                                        },
                                      ),
                                      RadioListTile<LocationScope>(
                                        title:  AutoSizeText("City",style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                        value: LocationScope.city,
                                        groupValue: _selectedLocationScope,
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        onChanged: (value) {
                                          setState((){
                                            _selectedLocationScope=value!;
                                          });
                                        },
                                      ),
                                      RadioListTile<LocationScope>(
                                        title: const AutoSizeText("Country"),
                                        value: LocationScope.country,
                                        groupValue: _selectedLocationScope,
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedLocationScope = value!;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => _applyFilter(allListings),
                                      child: const Text("Filter"),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          // Reset filter parameters back to their defaults.
                                          _selectedCondition = "Any";
                                          _selectedSaleType = "Any";
                                          _selectedCategory = "Any";
                                          _maxPriceText = "";
                                          _maxDistanceText = "";
                                          _selectedLocationScope = LocationScope.everywhere;
                                          _filterApplied = false;
                                          // Reset filtered listings to the full list.
                                          _filteredListings = List.from(allListings);
                                        });
                                      },
                                      child: const Text("Reset"),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Listings Grid or Empty Message.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _filteredListings.isEmpty
                          ? const Center(child: Text("No listings available"))
                          : GridView.builder(
                        key: UniqueKey(),
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
                            adminInfo: widget.adminInfo,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}