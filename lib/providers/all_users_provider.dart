import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


final usersProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => UserModel.fromMap(doc.data()))
      .toList());
});