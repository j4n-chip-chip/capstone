import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String userId) {
    return users.doc(userId).snapshots();
  }
}

final firestoreService = FirestoreService();
