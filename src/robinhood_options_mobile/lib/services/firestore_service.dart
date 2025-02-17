import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
// import 'dart:async';
import 'package:async/async.dart';
import 'package:robinhood_options_mobile/model/user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String instrumentCollectionName = 'instrument';
  final String userCollectionName = 'user';

  /// A reference to the list of instruments.
  /// We are using `withConverter` to ensure that interactions with the collection
  /// are type-safe.
  late final CollectionReference<Instrument> instrumentCollection = _db
      .collection(instrumentCollectionName)
      .withConverter<Instrument>(
        fromFirestore: (snapshots, _) => Instrument.fromJson(snapshots.data()!),
        toFirestore: (obj, _) => obj.toJson(),
      );

  late final CollectionReference<User> userCollection =
      _db.collection(userCollectionName).withConverter<User>(
            fromFirestore: (snapshots, _) => User.fromJson(snapshots.data()!),
            toFirestore: (obj, _) => obj.toJson(),
          );

  FirestoreService() {
    // instrumentsCollection =
    //     _db.collection('instruments').withConverter<Instrument>(
    //           fromFirestore: (snapshots, _) =>
    //               Instrument.fromJson(snapshots.data()!),
    //           toFirestore: (movie, _) => movie.toJson(),
    //         );
  }

  Future<void> addUser(DocumentReference<User> documentReference, User user,
      {Function? onError}) async {
    try {
      await documentReference.set(user);
      debugPrint("User added with ID: $documentReference - ${user.name}");
    } on FirebaseException catch (e) {
      debugPrint('${e.message}');
      if (onError != null) {
        onError(e);
      }
    }
    debugPrint(documentReference.path);
  }

  Future<void> updateUser(DocumentReference<User> documentReference, User user,
      {Function? onError}) async {
    user.dateUpdated = DateTime.now().toUtc();
    try {
      await documentReference.update(user.toJson());
    } on FirebaseException catch (e) {
      if (onError != null) {
        onError(e);
      }
      debugPrint("Failed to update user: $e");
    }
  }

  Stream<QuerySnapshot<User>> searchUsers(
      // CollectionReference<User> usersCollection,
      {String? searchTerm,
      UserRole? userRole,
      int limit = -1,
      String sort = 'dateUpdated',
      bool sortDescending = true}) {
    Query<User> query = userCollection;
    if (searchTerm != null && searchTerm.isNotEmpty) {
      query = query
          .where('nameLower', isGreaterThanOrEqualTo: searchTerm.toLowerCase())
          .where('nameLower',
              isLessThanOrEqualTo: '${searchTerm.toLowerCase()}\uf8ff');
    }
    if (userRole != null) {
      query = query.where('role', isEqualTo: userRole.enumValue());
    }
    if (limit != -1) {
      query = query.limit(limit);
    }
    Stream<QuerySnapshot<User>> stream =
        query.orderBy(sort, descending: sortDescending).snapshots();
    return stream;
  }

  Future<DocumentReference<Map<String, dynamic>>> addInstrument(
      Instrument instrument) {
    return _db.collection(instrumentCollectionName).add(instrument.toJson());
  }

  Future<void> updateInstrument(
      Instrument instrument, DocumentReference<Instrument> doc) async {
    instrument.dateUpdated = DateTime.now();
    return doc.set(instrument, SetOptions(merge: true));
  }

  Future<void> deleteInstrument(String id) {
    return instrumentCollection.doc(id).delete();
  }

  Future<DocumentReference> upsertInstrument(Instrument instrument) async {
    var existingDocs =
        await instrumentCollection.where('id', isEqualTo: instrument.id).get();
    if (existingDocs.docs.isNotEmpty) {
      var doc = existingDocs.docs.first.reference;
      await updateInstrument(instrument, doc);
      return doc;
    } else {
      return addInstrument(instrument);
    }
  }

  Future<Instrument?> getInstrument(
      {String? id, String? url, String? symbol}) async {
    Query<Instrument> query = instrumentCollection;
    if (id != null) {
      query = query.where('id', isEqualTo: id);
    }
    if (url != null) {
      query = query.where('url', isEqualTo: url);
    }
    if (symbol != null) {
      query = query.where('symbol', isEqualTo: symbol);
    }
    var results = await query.get();
    if (results.size > 0) {
      return results.docs.first.data();
    } else {
      return Future.value(null);
    }
  }

  Stream<List<Instrument>> searchInstruments(
      {String? id, List<String>? ids, String? url, String? symbol}) {
    Query<Instrument> query = instrumentCollection;
    if (id != null) {
      query = query.where('id', isEqualTo: id);
    }
    if (ids != null) {
      if (ids.length > 30) {
        // query = query.where('id', whereIn: ids.take(30));

        List<List<String>> subList = [];
        for (var i = 0; i < ids.length; i += 30) {
          subList
              .add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
        }
        List<Stream<List<Instrument>>> results = [];
        for (var subIds in subList) {
          Query<Instrument> batchedquery = instrumentCollection;
          batchedquery = batchedquery.where('id', whereIn: subIds);
          results.add(batchedquery.snapshots().map(
              (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()));
        }
        return StreamGroup.merge(results).asBroadcastStream();
      } else {
        query = query.where('id', whereIn: ids);
      }
    }
    if (url != null) {
      query = query.where('url', isEqualTo: url);
    }
    if (symbol != null) {
      query = query.where('symbol', isEqualTo: symbol);
    }
    return query
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    // .map((snapshot) =>
    //     snapshot.docs.map((doc) => Instrument.fromJson(doc.data())).toList());
  }

  // Stream<QuerySnapshot<Instrument>> queryInstruments() {
  // }
}

// /// The different ways that we can filter/sort instruments.
// enum InstrumentQuery {
//   year,
//   likesAsc,
//   likesDesc,
//   rated,
//   sciFi,
//   fantasy,
// }

// extension on Query<Instrument> {
//   /// Create a firebase query from a [InstrumentQuery]
//   Query<Instrument> queryBy(InstrumentQuery query) {
//     switch (query) {
//       case InstrumentQuery.fantasy:
//         return where('genre', arrayContainsAny: ['fantasy']);

//       case InstrumentQuery.sciFi:
//         return where('genre', arrayContainsAny: ['sci-fi']);

//       case InstrumentQuery.likesAsc:
//       case InstrumentQuery.likesDesc:
//         return orderBy('likes', descending: query == InstrumentQuery.likesDesc);

//       case InstrumentQuery.year:
//         return orderBy('year', descending: true);

//       case InstrumentQuery.rated:
//         return orderBy('rated', descending: true);
//     }
//   }
// }
