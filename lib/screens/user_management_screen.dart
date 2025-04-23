import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/all_users_provider.dart';

// Main screen for managing users
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  // Controller for the search input field
  final TextEditingController _searchController = TextEditingController();

  // Filters for user roles, activation status, and suspension status
  String _roleFilter = "All"; // "All", "Admin", "Not Admin"
  String _activationFilter = "All"; // "All", "Activated", "Deactivated"
  String _suspendedFilter = "All"; // "All", "Suspended", "Not Suspended"

  // Visibility toggle for the filter section
  bool _filtersVisible = false;

  @override
  void dispose() {
    // Dispose of the search controller when the widget is removed
    _searchController.dispose();
    super.dispose();
  }

  // Function to show a bottom sheet for editing user details
  Future<void> _showEditUserSheet(UserModel user) async {
    bool newActivated = user.activated;
    bool newSuspended = user.suspended;
    bool newAdmin = user.admin;

    // Display a modal bottom sheet with user editing options
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              children: [
                // Title displaying the user's name
                Text(
                  "Edit User: ${user.name}",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                // Switches for toggling user properties
                SwitchListTile(
                  title: const Text("Activated"),
                  value: newActivated,
                  onChanged: (val) {
                    setModalState(() {
                      newActivated = val;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text("Suspended"),
                  value: newSuspended,
                  onChanged: (val) {
                    setModalState(() {
                      newSuspended = val;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text("Admin"),
                  value: newAdmin,
                  onChanged: (val) {
                    setModalState(() {
                      newAdmin = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Buttons for saving or canceling changes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        // Update user details in Firestore
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(user.id)
                            .update({
                          "activated": newActivated,
                          "suspended": newSuspended,
                          "admin": newAdmin,
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Save"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // App bar title
        title: const Text("User Management"),
      ),
      body: Consumer(
        builder: (context, ref, _) {
          // Watch the users provider for data
          final usersAsync = ref.watch(usersProvider);

          return usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text("Error: $e")),
            data: (allUsers) {
              // Filter users based on search and dropdown filters
              final searchTerm = _searchController.text.toLowerCase();
              final filteredUsers = allUsers.where((user) {
                final matchesSearch =
                    user.name.toLowerCase().contains(searchTerm) ||
                        user.email.toLowerCase().contains(searchTerm);
                final matchesRole = _roleFilter == "All" ||
                    (_roleFilter == "Admin" && user.admin) ||
                    (_roleFilter == "Not Admin" && !user.admin);
                final matchesActivation = _activationFilter == "All" ||
                    (_activationFilter == "Activated" && user.activated) ||
                    (_activationFilter == "Deactivated" && !user.activated);
                final matchesSuspended = _suspendedFilter == "All" ||
                    (_suspendedFilter == "Suspended" && user.suspended) ||
                    (_suspendedFilter == "Not Suspended" && !user.suspended);
                return matchesSearch &&
                    matchesRole &&
                    matchesActivation &&
                    matchesSuspended;
              }).toList();

              return Column(
                children: [
                  // Search input field
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: "Search by name or email",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setState(() {}); // Update filtering
                      },
                    ),
                  ),
                  // Button to toggle filter visibility
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton.icon(
                      icon: Icon(_filtersVisible
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down),
                      label: const Text("Filters"),
                      onPressed: () {
                        setState(() {
                          _filtersVisible = !_filtersVisible;
                        });
                      },
                    ),
                  ),
                  // Filter dropdowns (visible only when _filtersVisible is true)
                  if (_filtersVisible)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Role filter dropdown
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: "Role",
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _roleFilter,
                                  items: ["All", "Admin", "Not Admin"]
                                      .map((role) => DropdownMenuItem<String>(
                                            value: role,
                                            child: Text(role),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    _roleFilter = val!;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Activation filter dropdown
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: "Activation",
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _activationFilter,
                                  items: ["All", "Activated", "Deactivated"]
                                      .map((act) => DropdownMenuItem<String>(
                                            value: act,
                                            child: Text(act),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    _activationFilter = val!;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Suspension filter dropdown
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: "Suspended",
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _suspendedFilter,
                                  items: ["All", "Suspended", "Not Suspended"]
                                      .map((susp) => DropdownMenuItem<String>(
                                            value: susp,
                                            child: Text(susp),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    _suspendedFilter = val!;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Button to apply filters
                          ElevatedButton(
                            onPressed: () {
                              setState(
                                  () {}); // Trigger rebuild to apply filter changes
                            },
                            child: const Text("Apply Filter"),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  // List of filtered users
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(child: Text("No users found"))
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(user.name),
                                  subtitle: Text(
                                      "Email: ${user.email}\nActivated: ${user.activated}\nSuspended: ${user.suspended}\nAdmin: ${user.admin}"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditUserSheet(user),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
