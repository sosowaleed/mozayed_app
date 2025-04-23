import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/report_model.dart';

/// A StateNotifier that manages the state of reports.
class ReportsNotifier extends StateNotifier<AsyncValue<List<ReportModel>>> {
  /// Initializes the state as loading and fetches the reports.
  ReportsNotifier() : super(const AsyncValue.loading()) {
    fetchReports();
  }

  /// Fetches the list of reports from Firestore and updates the state.
  Future<void> fetchReports() async {
    try {
      // Retrieve all documents from the 'reports' collection.
      final querySnapshot =
          await FirebaseFirestore.instance.collection('reports').get();
      // Map the documents to a list of ReportModel objects.
      final reports = querySnapshot.docs
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList();
      // Update the state with the fetched reports.
      state = AsyncValue.data(reports);
    } catch (e, st) {
      // Update the state with an error if fetching fails.
      state = AsyncValue.error(e, st);
    }
  }

  /// Toggle the "handled" status for a report.
  Future<void> updateReportHandled(String reportId, bool newHandled) async {
    try {
      // Update the "handled" field of the specified report document.
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({'handled': newHandled});
      // Refresh the reports list after the update.
      await fetchReports();
    } catch (e, st) {
      // Update the state with an error if the update fails.
      state = AsyncValue.error(e, st);
    }
  }
}

/// A StreamProvider that listens to real-time updates of the reports collection.
final reportsProvider = StreamProvider<List<ReportModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('reports')
      .snapshots()
      .map((snapshot) => snapshot.docs
          // Map the real-time snapshot documents to a list of ReportModel objects.
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList());
});
