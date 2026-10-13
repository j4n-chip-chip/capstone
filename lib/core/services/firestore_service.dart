import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>> _streams =
      {};

  void clearStreamCache() => _streams.clear();

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String userId) {
    return _streams.putIfAbsent(userId, () => users.doc(userId).snapshots());
  }
}

final firestoreService = FirestoreService();
