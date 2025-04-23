import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/report_model.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/reports_provider.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/widgets/report_widget.dart';

// Enum to define the different categories of reports for filtering.
enum ReportCategoryFilter { all, user, item, bid }

// Main widget for displaying and filtering reports.
class ReportContent extends ConsumerStatefulWidget {
  const ReportContent({super.key});

  @override
  ConsumerState<ReportContent> createState() => _ReportHomeContentState();
}

class _ReportHomeContentState extends ConsumerState<ReportContent> {
  // State variables for filtering reports.
  ReportCategoryFilter _selectedCategoryFilter = ReportCategoryFilter.all; // Selected category filter.
  String _selectedFlagFilter = "All"; // Selected flag filter.
  bool _excludeHandled = true; // Whether to exclude handled reports.
  bool _filterVisible = false; // Whether to show filter options.

  // Define flag options for each category.
  final Map<ReportCategoryFilter, List<String>> flagOptions = {
    ReportCategoryFilter.all: ["All"],
    ReportCategoryFilter.user: [
      "All",
      "Not responding",
      "Location distant was false",
      "Other"
    ],
    ReportCategoryFilter.item: [
      "All",
      "Condition worse than advertised",
      "Item sold was different",
      "Other"
    ],
    ReportCategoryFilter.bid: [
      "All",
      "Illegitimate bid",
      "Not responding",
      "Other"
    ],
  };

  // List to store filtered reports.
  List<ReportModel> _filteredReports = [];

  // Function to apply filters to the list of reports.
  void _applyFilter(List<ReportModel> allReports) {
    setState(() {
      _filteredReports = allReports.where((report) {
        // Check if the report matches the selected category.
        bool categoryMatch =
            _selectedCategoryFilter == ReportCategoryFilter.all ||
                report.category.toLowerCase() ==
                    _selectedCategoryFilter.name.toLowerCase();
        // Check if the report matches the selected flag.
        bool flagMatch = _selectedFlagFilter == "All" ||
            report.flag.toLowerCase() == _selectedFlagFilter.toLowerCase();
        // Check if the report matches the handled filter.
        final bool handledMatch = !_excludeHandled || (report.handled == false);
        return categoryMatch && flagMatch && handledMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the reports and user data providers.
    final reportsAsync = ref.watch(reportsProvider);
    final currentUser = ref.watch(userDataProvider);
    late UserModel currentAdmin;

    // Handle the current user data.
    currentUser.when(
      data: (data) => currentAdmin = UserModel.fromMap(data!),
      error: (error, stackTrace) => Center(child: Text("No admin found\nPlease try again later\n\n$error")),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    // Handle the reports data.
    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, st) =>
          Center(child: Text("Error loading reports: $error")),
      data: (allReports) {
        // Apply filter to the list of reports.
        _applyFilter(allReports);

        // Determine the grid layout based on screen width.
        int crossAxisCount = 2;
        final width = MediaQuery.of(context).size.width;
        if (width >= 1200) {
          crossAxisCount = 6;
        } else if (width >= 735) {
          crossAxisCount = 5;
        } else if (width >= 600) {
          crossAxisCount = 3;
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh the reports provider.
            ref.refresh(reportsProvider);
            // Optionally wait a moment to show the indicator.
            await Future.delayed(const Duration(seconds: 1));
          },
          child: Column(
            children: [
              // Button to toggle the visibility of filter options.
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  icon: Icon(_filterVisible ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                  label: const Text("Filter options"),
                  onPressed: () {
                    setState(() {
                      _filterVisible = !_filterVisible;
                    });
                  },
                ),
              ),
              // Filter options, shown only when _filterVisible is true.
              if (_filterVisible)
                Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Dropdown for selecting the report category.
                            Expanded(
                              child: DropdownButtonFormField<ReportCategoryFilter>(
                                decoration: const InputDecoration(labelText: "Category"),
                                value: _selectedCategoryFilter,
                                items: ReportCategoryFilter.values
                                    .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat == ReportCategoryFilter.all
                                      ? "All"
                                      : cat.name.toUpperCase()),
                                ))
                                    .toList(),
                                onChanged: (val) {
                                  _selectedCategoryFilter = val!;
                                  _selectedFlagFilter = "All";
                                  _applyFilter(allReports);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Dropdown for selecting the report flag.
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(labelText: "Flag"),
                                value: _selectedFlagFilter,
                                items: flagOptions[_selectedCategoryFilter]!
                                    .map((flag) => DropdownMenuItem(
                                  value: flag,
                                  child: Text(flag),
                                ))
                                    .toList(),
                                onChanged: (val) {
                                  _selectedFlagFilter = val!;
                                  _applyFilter(allReports);
                                },
                              ),
                            ),
                          ],
                        ),
                        // Switch to toggle exclusion of handled reports.
                        SwitchListTile(
                          title: const Text("Exclude handled reports"),
                          value: _excludeHandled,
                          onChanged: (newVal) {
                            setState(() {
                              _excludeHandled = newVal;
                              _applyFilter(allReports);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        // Button to manually apply the filter.
                        ElevatedButton(
                          onPressed: () => _applyFilter(allReports),
                          child: const Text("Apply Filter"),
                        ),
                      ],
                    ),
                  ),
                ),
              // Grid to display the filtered reports.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _filteredReports.isEmpty
                      ? const Center(child: Text("No reports available"))
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            // Display each report using the ReportWidget.
                            return ReportWidget(
                              report: _filteredReports[index],
                              currentAdmin: currentAdmin,
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
  }
}
