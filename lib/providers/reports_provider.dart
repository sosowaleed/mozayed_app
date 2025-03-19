import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/report_model.dart';

class ReportsNotifier extends StateNotifier<AsyncValue<List<ReportModel>>> {
  ReportsNotifier() : super(const AsyncValue.loading()) {
    fetchReports();
  }

  Future<void> fetchReports() async {
    try {
      final querySnapshot =
      await FirebaseFirestore.instance.collection('reports').get();
      final reports = querySnapshot.docs
          .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
          .toList();
      state = AsyncValue.data(reports);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Toggle the "handled" status for a report.
  Future<void> updateReportHandled(String reportId, bool newHandled) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({'handled': newHandled});
      await fetchReports();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final reportsProvider = StreamProvider<List<ReportModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('reports')
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => ReportModel.fromMap(doc.id, doc.data()))
      .toList());
});
