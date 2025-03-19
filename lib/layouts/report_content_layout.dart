import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/report_model.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/reports_provider.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/widgets/report_widget.dart';

enum ReportCategoryFilter { all, user, item, bid }

class ReportContent extends ConsumerStatefulWidget {
  const ReportContent({super.key});

  @override
  ConsumerState<ReportContent> createState() => _ReportHomeContentState();
}

class _ReportHomeContentState extends ConsumerState<ReportContent> {
  ReportCategoryFilter _selectedCategoryFilter = ReportCategoryFilter.all;
  String _selectedFlagFilter = "All";
  bool _excludeHandled = true; // default: do not include handled reports
  bool _filterVisible = false; // initially hide filter options

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

  List<ReportModel> _filteredReports = [];

  void _applyFilter(List<ReportModel> allReports) {
    setState(() {
      _filteredReports = allReports.where((report) {
        bool categoryMatch =
            _selectedCategoryFilter == ReportCategoryFilter.all ||
                report.category.toLowerCase() ==
                    _selectedCategoryFilter.name.toLowerCase();
        bool flagMatch = _selectedFlagFilter == "All" ||
            report.flag.toLowerCase() == _selectedFlagFilter.toLowerCase();
        // Only include reports that are NOT handled when _excludeHandled is true.
        final bool handledMatch = !_excludeHandled || (report.handled == false);
        return categoryMatch && flagMatch && handledMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(reportsProvider);
    final currentUser = ref.watch(userDataProvider);
    late UserModel currentAdmin;

    currentUser.when(
      data: (data) => currentAdmin = UserModel.fromMap(data!),
      error: (error, stackTrace) => Center(child: Text("No admin found\nPlease try again later\n\n$error")),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, st) =>
          Center(child: Text("Error loading reports: $error")),
      data: (allReports) {
        // Apply filter to the list of reports.
        _applyFilter(allReports);
        // Determine grid layout based on available width.
        int crossAxisCount = 2;
        final width = MediaQuery.of(context).size.width;
        if (width >= 1200) {
          crossAxisCount = 6;
        } else if (width >= 735) {
          crossAxisCount = 5;
        } else if (width >= 600) {
          crossAxisCount = 3;
        }

        return Column(
          children: [
            // Show/hide filter options button.
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
            // Filter options shown only when _filterVisible is true.
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
                          // Category Dropdown.
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
                          // Flag Dropdown.
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
                      // Switch for handled reports.
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
                      ElevatedButton(
                        onPressed: () => _applyFilter(allReports),
                        child: const Text("Apply Filter"),
                      ),
                    ],
                  ),
                ),
              ),
            // Reports Grid.
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
                          return ReportWidget(
                            report: _filteredReports[index],
                            currentAdmin: currentAdmin,
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
