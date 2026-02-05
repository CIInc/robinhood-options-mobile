import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
// import 'dart:async';
import 'package:async/async.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/group_message.dart';
import 'package:robinhood_options_mobile/model/instrument_note.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String instrumentCollectionName = 'instrument';
  final String userCollectionName = 'user';
  final String instrumentPositionCollectionName = 'instrumentPosition';
  final String optionPositionCollectionName = 'optionPosition';
  final String forexPositionCollectionName = 'forexPosition';
  final String instrumentOrderCollectionName = 'instrumentOrder';
  final String optionOrderCollectionName = 'optionOrder';
  final String optionEventCollectionName = 'optionEvent';
  final String dividendCollectionName = 'dividend';
  final String interestCollectionName = 'interest';
  final String investorGroupCollectionName = 'investor_groups';

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

  late final CollectionReference<InvestorGroup> investorGroupCollection =
      _db.collection(investorGroupCollectionName).withConverter<InvestorGroup>(
            fromFirestore: (snapshots, _) =>
                InvestorGroup.fromJson(snapshots.data()!),
            toFirestore: (obj, _) => obj.toJson(),
          );

  /// User Methods

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
    user.dateUpdated = DateTime.now();
    try {
      await documentReference.update(user.toJson());
    } on FirebaseException catch (e) {
      if (onError != null) {
        onError(e);
      }
      debugPrint("Failed to update user: $e");
    } on Exception catch (e) {
      debugPrint("Failed to update user: $e");
    }
  }

  Future<void> updateUserField(String uid, {DateTime? lastVisited}) async {
    var userDocumentReference = userCollection.doc(uid);
    var fields = {
      'dateUpdated': DateTime.now(),
    };
    if (lastVisited != null) {
      fields['lastVisited'] = lastVisited;
    }
    await userDocumentReference.update(fields);
  }

  Stream<DocumentSnapshot<User>> getUser(String uid) {
    final documentReference = userCollection.doc(uid);
    final documentSnapshot = documentReference.snapshots();
    return documentSnapshot;
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

  /// Instrument Methods

  Future<DocumentReference<Map<String, dynamic>>> addInstrument(
      Instrument instrument) {
    return _db.collection(instrumentCollectionName).add(instrument.toJson());
  }

  Future<void> updateInstrument(
      Instrument instrument, DocumentReference<Instrument> doc) async {
    instrument.dateUpdated = DateTime.now();
    try {
      doc.set(instrument, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint("Failed to update instrument: $e");
    } on Exception catch (e) {
      debugPrint("Failed to update instrument: $e");
    }
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

  /// Advanced Stock Screener
  ///
  /// Queries the Firestore `instrument` collection with multiple filter criteria
  /// to find stocks matching specific investment parameters.
  ///
  /// **Parameters:**
  /// - [sector]: Filter by company sector (e.g., 'Technology Services', 'Finance')
  /// - [marketCapMin]/[marketCapMax]: Market capitalization range in USD
  /// - [peMin]/[peMax]: Price-to-Earnings ratio range
  /// - [dividendYieldMin]/[dividendYieldMax]: Dividend yield percentage range
  /// - [limit]: Maximum number of results to return (default: 100)
  /// - [sort]: Field to sort by (default: 'fundamentalsObj.market_cap')
  /// - [sortDescending]: Sort direction (default: true)
  ///
  /// **Returns:** List of [Instrument] objects matching the criteria
  ///
  /// **Example:**
  /// ```dart
  /// var results = await firestoreService.stockScreener(
  ///   sector: 'Technology Services',
  ///   marketCapMin: 1000000000, // $1B
  ///   marketCapMax: 100000000000, // $100B
  ///   peMin: 10,
  ///   peMax: 30,
  /// );
  /// ```
  ///
  /// **Note:** Requires Firestore composite indexes to be deployed.
  /// See `firebase/firestore.indexes.json` for index definitions.
  Future<List<Instrument>> stockScreener({
    String? sector,
    int? marketCapMin,
    int? marketCapMax,
    int? peMin,
    int? peMax,
    int? dividendYieldMin,
    int? dividendYieldMax,
    int limit = 100,
    String sort = 'fundamentalsObj.market_cap',
    bool sortDescending = true,
  }) async {
    Query<Instrument> query = instrumentCollection;
    if (sector != null && sector.isNotEmpty) {
      query = query.where('fundamentalsObj.sector', isEqualTo: sector);
    }
    if (marketCapMin != null) {
      query = query.where('fundamentalsObj.market_cap',
          isGreaterThanOrEqualTo: marketCapMin);
    }
    if (marketCapMax != null) {
      query = query.where('fundamentalsObj.market_cap',
          isLessThanOrEqualTo: marketCapMax);
    }
    if (peMin != null) {
      query = query.where('fundamentalsObj.pe_ratio',
          isGreaterThanOrEqualTo: peMin);
    }
    if (peMax != null) {
      query =
          query.where('fundamentalsObj.pe_ratio', isLessThanOrEqualTo: peMax);
    }
    if (dividendYieldMin != null) {
      query = query.where('fundamentalsObj.dividend_yield',
          isGreaterThanOrEqualTo: dividendYieldMin);
    }
    if (dividendYieldMax != null) {
      query = query.where('fundamentalsObj.dividend_yield',
          isLessThanOrEqualTo: dividendYieldMax);
    }
    query = query.orderBy(sort, descending: sortDescending).limit(limit);
    var results = await query.get();
    return results.docs.map((doc) => doc.data()).toList();
  }

  /// InstrumentPosition Methods

  Future<List<InstrumentPosition>> getInstrumentPositions(
      DocumentReference userDoc) async {
    var querySnapshot =
        await userDoc.collection(instrumentPositionCollectionName).get();
    return querySnapshot.docs
        .map((doc) => InstrumentPosition.fromJson(doc.data()))
        .toList();
  }

  Future<DocumentReference<Map<String, dynamic>>> addInstrumentPosition(
      InstrumentPosition instrument, DocumentReference userDoc) {
    return userDoc
        .collection(instrumentPositionCollectionName)
        .add(instrument.toJson());
  }

  Future<void> updateInstrumentPosition(
      InstrumentPosition instrumentPosition, DocumentReference doc) async {
    // return doc.set(instrumentPosition, SetOptions(merge: true));
    return doc.update(instrumentPosition.toJson());
  }

  Future<void> deleteInstrumentPosition(String id, DocumentReference doc) {
    return doc.collection(instrumentPositionCollectionName).doc(id).delete();
  }

  Future<DocumentReference> upsertInstrumentPosition(
    InstrumentPosition instrumentPosition,
    DocumentReference userDoc,
  ) async {
    var existingDocs = await userDoc
        .collection(instrumentPositionCollectionName)
        .where('instrument', isEqualTo: instrumentPosition.instrument)
        .get();
    if (existingDocs.docs.isNotEmpty) {
      var doc = existingDocs.docs.first.reference;
      await updateInstrumentPosition(instrumentPosition, doc);
      return doc;
    } else {
      return addInstrumentPosition(instrumentPosition, userDoc);
    }
  }

  /// OptionPosition Methods

  Future<List<OptionAggregatePosition>> getOptionPositions(
      DocumentReference userDoc) async {
    var querySnapshot =
        await userDoc.collection(optionPositionCollectionName).get();
    return querySnapshot.docs
        .map((doc) => OptionAggregatePosition.fromJson(doc.data()))
        .toList();
  }

  Future<DocumentReference<Map<String, dynamic>>> addOptionPosition(
      OptionAggregatePosition option, DocumentReference userDoc) {
    return userDoc
        .collection(optionPositionCollectionName)
        .add(option.toJson());
  }

  Future<void> updateOptionPosition(
      OptionAggregatePosition optionPosition, DocumentReference doc) async {
    // return doc.set(optionPosition, SetOptions(merge: true));
    return doc.update(optionPosition.toJson());
  }

  Future<void> deleteOptionPosition(String id, DocumentReference doc) {
    return doc.collection(optionPositionCollectionName).doc(id).delete();
  }

  Future<DocumentReference> upsertOptionPosition(
    OptionAggregatePosition optionPosition,
    DocumentReference userDoc,
  ) async {
    var existingDocs = await userDoc
        .collection(optionPositionCollectionName)
        .where('id', isEqualTo: optionPosition.id)
        .get();
    if (existingDocs.docs.isNotEmpty) {
      var doc = existingDocs.docs.first.reference;
      await updateOptionPosition(optionPosition, doc);
      return doc;
    } else {
      return addOptionPosition(optionPosition, userDoc);
    }
  }

  /// ForexPosition Methods

  Future<DocumentReference<Map<String, dynamic>>> addForexPosition(
      ForexHolding forex, DocumentReference userDoc) {
    return userDoc.collection(forexPositionCollectionName).add(forex.toJson());
  }

  Future<void> updateForexPosition(
      ForexHolding forexPosition, DocumentReference doc) async {
    // return doc.set(forexPosition, SetOptions(merge: true));
    return doc.update(forexPosition.toJson());
  }

  Future<void> deleteForexPosition(String id, DocumentReference doc) {
    return doc.collection(forexPositionCollectionName).doc(id).delete();
  }

  Future<DocumentReference> upsertForexPosition(
    ForexHolding forexPosition,
    DocumentReference userDoc,
  ) async {
    var existingDocs = await userDoc
        .collection(forexPositionCollectionName)
        .where('id', isEqualTo: forexPosition.id)
        .get();
    if (existingDocs.docs.isNotEmpty) {
      var doc = existingDocs.docs.first.reference;
      await updateForexPosition(forexPosition, doc);
      return doc;
    } else {
      return addForexPosition(forexPosition, userDoc);
    }
  }

  /// InstrumentOrder Methods

  // Future<DocumentReference<Map<String, dynamic>>> addInstrumentOrder(
  //     InstrumentOrder instrumentOrder, DocumentReference userDoc) {
  //   return userDoc
  //       .collection(instrumentOrderCollectionName)
  //       .add(instrumentOrder.toJson());
  // }

  // Future<void> updateInstrumentOrder(
  //     InstrumentOrder instrumentOrder, DocumentReference doc) async {
  //   // return doc.set(instrumentPosition, SetOptions(merge: true));
  //   return doc.update(instrumentOrder.toJson());
  // }

  // Future<void> deleteInstrumentOrder(String id, DocumentReference doc) {
  //   return doc.collection(instrumentOrderCollectionName).doc(id).delete();
  // }

  // Future<DocumentReference> upsertInstrumentOrder(
  //   InstrumentOrder instrumentOrder,
  //   DocumentReference userDoc,
  // ) async {
  //   var existingDocs = await userDoc
  //       .collection(instrumentOrderCollectionName)
  //       .where('id', isEqualTo: instrumentOrder.id)
  //       .get();
  //   if (existingDocs.docs.isNotEmpty) {
  //     var doc = existingDocs.docs.first.reference;
  //     Timestamp updatedAt = existingDocs.docs.first.get('updated_at');
  //     if (updatedAt.toDate().isBefore(instrumentOrder.updatedAt!)) {
  //       await updateInstrumentOrder(instrumentOrder, doc);
  //     }
  //     return doc;
  //   } else {
  //     return addInstrumentOrder(instrumentOrder, userDoc);
  //   }
  // }

  // Future<void> upsertInstrumentOrders(
  //   List<InstrumentOrder> instrumentOrders,
  //   DocumentReference userDoc,
  // ) async {
  //   var batch = _db.batch();
  //   var existingDocs = await userDoc
  //       .collection(instrumentOrderCollectionName)
  //       .where('id', whereIn: instrumentOrders.map((e) => e.id))
  //       .get();
  //   var foundIds = [];
  //   for (var existingDoc in existingDocs.docs) {
  //     var doc = existingDoc.reference;
  //     Timestamp updatedAt = existingDoc.get('updated_at');
  //     final id = existingDoc.get('id');
  //     foundIds.add(id);
  //     InstrumentOrder instrumentOrder =
  //         instrumentOrders.firstWhere((e) => e.id == id);
  //     if (updatedAt.toDate().isBefore(instrumentOrder.updatedAt!)) {
  //       batch.update(doc, instrumentOrder.toJson());
  //     }
  //   }
  //   await batch.commit();
  //   for (var instrumentOrder
  //       in instrumentOrders.where((e) => !foundIds.contains(e.id))) {
  //     await addInstrumentOrder(instrumentOrder, userDoc);
  //   }
  // }

  Future<void> upsertInstrumentOrders(
      List<InstrumentOrder> instrumentOrders, DocumentReference userDoc,
      {bool updateIfExists = true}) async {
    var batch = _db.batch();
    for (var instrumentOrder in instrumentOrders) {
      var instrumentOrderDoc = userDoc
          .collection(instrumentOrderCollectionName)
          .doc(instrumentOrder.id);
      batch.set(instrumentOrderDoc, instrumentOrder.toJson());
    }
    batch.commit();
  }

  /// OptionOrder Methods

  // Future<DocumentReference<Map<String, dynamic>>> addOptionOrder(
  //     OptionOrder optionOrder, DocumentReference userDoc) {
  //   return userDoc
  //       .collection(optionOrderCollectionName)
  //       .add(optionOrder.toJson());
  // }

  // Future<void> updateOptionOrder(
  //     OptionOrder optionOrder, DocumentReference doc) async {
  //   // return doc.set(instrumentPosition, SetOptions(merge: true));
  //   return doc.update(optionOrder.toJson());
  // }

  // Future<void> deleteOptionOrder(String id, DocumentReference doc) {
  //   return doc.collection(optionOrderCollectionName).doc(id).delete();
  // }

  // Future<DocumentReference> upsertOptionOrder(
  //   OptionOrder optionOrder,
  //   DocumentReference userDoc,
  // ) async {
  //   var existingDocs = await userDoc
  //       .collection(optionOrderCollectionName)
  //       .where('id', isEqualTo: optionOrder.id)
  //       .get();
  //   if (existingDocs.docs.isNotEmpty) {
  //     var doc = existingDocs.docs.first.reference;
  //     Timestamp updatedAt = existingDocs.docs.first.get('updated_at');
  //     if (updatedAt.toDate().isBefore(optionOrder.updatedAt!)) {
  //       await updateOptionOrder(optionOrder, doc);
  //     }
  //     return doc;
  //   } else {
  //     return addOptionOrder(optionOrder, userDoc);
  //   }
  // }

  // Future<void> upsertOptionOrders(
  //   List<OptionOrder> optionOrders,
  //   DocumentReference userDoc,
  // ) async {
  //   var batch = _db.batch();
  //   var existingDocs = await userDoc
  //       .collection(optionOrderCollectionName)
  //       .where('id', whereIn: optionOrders.map((e) => e.id))
  //       .get();
  //   var foundIds = [];
  //   for (var existingDoc in existingDocs.docs) {
  //     var doc = existingDoc.reference;
  //     Timestamp updatedAt = existingDoc.get('updated_at');
  //     final id = existingDoc.get('id');
  //     foundIds.add(id);
  //     OptionOrder optionOrder = optionOrders.firstWhere((e) => e.id == id);
  //     if (updatedAt.toDate().isBefore(optionOrder.updatedAt!)) {
  //       batch.update(doc, optionOrder.toJson());
  //     }
  //   }
  //   await batch.commit();
  //   for (var optionOrder
  //       in optionOrders.where((e) => !foundIds.contains(e.id))) {
  //     await addOptionOrder(optionOrder, userDoc);
  //   }
  // }

  Future<void> upsertOptionOrders(
      List<OptionOrder> optionOrders, DocumentReference userDoc,
      {bool updateIfExists = true}) async {
    var batch = _db.batch();
    for (var optionOrder in optionOrders) {
      var optionOrderDoc =
          userDoc.collection(optionOrderCollectionName).doc(optionOrder.id);
      batch.set(optionOrderDoc, optionOrder.toJson());
    }
    batch.commit();
  }

  /// OptionEvent Methods

  // Future<DocumentReference<Map<String, dynamic>>> addOptionEvent(
  //     OptionEvent optionEvent, DocumentReference userDoc) {
  //   return userDoc
  //       .collection(optionEventCollectionName)
  //       .add(optionEvent.toJson());
  // }

  // Future<void> updateOptionEvent(
  //     OptionEvent optionEvent, DocumentReference doc) async {
  //   // return doc.set(instrumentPosition, SetOptions(merge: true));
  //   return doc.update(optionEvent.toJson());
  // }

  // Future<void> deleteOptionEvent(String id, DocumentReference doc) {
  //   return doc.collection(optionEventCollectionName).doc(id).delete();
  // }

  // Future<DocumentReference> upsertOptionEvent(
  //   OptionEvent optionEvent,
  //   DocumentReference userDoc,
  // ) async {
  //   var existingDocs = await userDoc
  //       .collection(optionEventCollectionName)
  //       .where('id', isEqualTo: optionEvent.id)
  //       .get();
  //   if (existingDocs.docs.isNotEmpty) {
  //     var doc = existingDocs.docs.first.reference;
  //     Timestamp updatedAt = existingDocs.docs.first.get('updated_at');
  //     if (updatedAt.toDate().isBefore(optionEvent.updatedAt!)) {
  //       await updateOptionEvent(optionEvent, doc);
  //     }
  //     return doc;
  //   } else {
  //     return addOptionEvent(optionEvent, userDoc);
  //   }
  // }

  // Future<void> upsertOptionEvents(
  //   List<OptionEvent> optionEvents,
  //   DocumentReference userDoc,
  // ) async {
  //   var batch = _db.batch();
  //   var existingDocs = await userDoc
  //       .collection(optionEventCollectionName)
  //       .where('id', whereIn: optionEvents.map((e) => e.id))
  //       .get();
  //   var foundIds = [];
  //   for (var existingDoc in existingDocs.docs) {
  //     var doc = existingDoc.reference;
  //     Timestamp updatedAt = existingDoc.get('updated_at');
  //     final id = existingDoc.get('id');
  //     foundIds.add(id);
  //     OptionEvent optionEvent = optionEvents.firstWhere((e) => e.id == id);
  //     if (updatedAt.toDate().isBefore(optionEvent.updatedAt!)) {
  //       batch.update(doc, optionEvent.toJson());
  //     }
  //   }
  //   await batch.commit();
  //   for (var optionEvent
  //       in optionEvents.where((e) => !foundIds.contains(e.id))) {
  //     await addOptionEvent(optionEvent, userDoc);
  //   }
  // }

  Future<void> upsertOptionEvents(
      List<OptionEvent> optionEvents, DocumentReference userDoc,
      {bool updateIfExists = true}) async {
    var batch = _db.batch();
    for (var optionEvent in optionEvents) {
      var optionEventDoc =
          userDoc.collection(optionEventCollectionName).doc(optionEvent.id);
      batch.set(optionEventDoc, optionEvent.toJson());
    }
    batch.commit();
  }

  /// Dividend Methods

  // Future<DocumentReference<Map<String, dynamic>>> addDividend(
  //     dynamic obj, DocumentReference userDoc) {
  //   return userDoc.collection(dividendCollectionName).add(obj);
  // }

  // Future<void> updateDividend(dynamic obj, DocumentReference doc) async {
  //   // return doc.set(instrumentPosition, SetOptions(merge: true));
  //   return doc.update(obj);
  // }

  // Future<void> deleteDividend(String id, DocumentReference doc) {
  //   return doc.collection(dividendCollectionName).doc(id).delete();
  // }

  // Future<DocumentReference> upsertDividend(
  //     dynamic obj, DocumentReference userDoc,
  //     {bool updateIfExists = true}) async {
  //   var existingDocs = await userDoc
  //       .collection(dividendCollectionName)
  //       .where('id', isEqualTo: obj['id'])
  //       .get();
  //   if (existingDocs.docs.isNotEmpty) {
  //     var doc = existingDocs.docs.first.reference;
  //     if (updateIfExists) {
  //       await updateDividend(obj, doc);
  //     }
  //     return doc;
  //   } else {
  //     return addDividend(obj, userDoc);
  //   }
  // }

  Future<void> upsertDividends(
      List<dynamic> dividends, DocumentReference userDoc,
      {bool updateIfExists = true}) async {
    var batch = _db.batch();
    for (var dividend in dividends) {
      var dividendDoc =
          userDoc.collection(dividendCollectionName).doc(dividend['id']);
      batch.set(dividendDoc, dividend);
    }
    batch.commit();
  }

  /// Interest Methods

  // Future<DocumentReference<Map<String, dynamic>>> addInterest(
  //     dynamic obj, DocumentReference userDoc) {
  //   return userDoc.collection(interestCollectionName).add(obj);
  // }

  // Future<void> updateInterest(dynamic obj, DocumentReference doc) async {
  //   // return doc.set(instrumentPosition, SetOptions(merge: true));
  //   return doc.update(obj);
  // }

  // Future<void> deleteInterest(String id, DocumentReference doc) {
  //   return doc.collection(interestCollectionName).doc(id).delete();
  // }

  // Future<DocumentReference> upsertInterest(
  //     dynamic obj, DocumentReference userDoc,
  //     {bool updateIfExists = true}) async {
  //   var existingDocs = await userDoc
  //       .collection(interestCollectionName)
  //       .where('id', isEqualTo: obj['id'])
  //       .get();
  //   if (existingDocs.docs.isNotEmpty) {
  //     var doc = existingDocs.docs.first.reference;
  //     if (updateIfExists) {
  //       await updateInterest(obj, doc);
  //     }
  //     return doc;
  //   } else {
  //     return addInterest(obj, userDoc);
  //   }
  // }

  // Future<void> upsertInterests(
  //   List<dynamic> interests,
  //   DocumentReference userDoc,
  // ) async {
  //   var batch = _db.batch();
  //   var existingDocs = await userDoc
  //       .collection(interestCollectionName)
  //       .where('id', whereIn: interests.map((e) => e.id))
  //       .get();
  //   var foundIds = [];
  //   for (var existingDoc in existingDocs.docs) {
  //     var doc = existingDoc.reference;
  //     Timestamp updatedAt = existingDoc.get('updated_at');
  //     final id = existingDoc.get('id');
  //     foundIds.add(id);
  //     dynamic dividend = interests.firstWhere((e) => e.id == id);
  //     if (updatedAt.toDate().isBefore(dividend.updatedAt!)) {
  //       batch.update(doc, dividend.toJson());
  //     }
  //   }
  //   batch.commit();
  //   for (var dividend in interests.where((e) => !foundIds.contains(e.id))) {
  //     await addInterest(dividend, userDoc);
  //   }
  // }

  Future<void> upsertInterests(
      List<dynamic> interests, DocumentReference userDoc,
      {bool updateIfExists = true}) async {
    var batch = _db.batch();
    for (var interest in interests) {
      var interestDoc =
          userDoc.collection(interestCollectionName).doc(interest['id']);
      batch.set(interestDoc, interest);
    }
    batch.commit();
  }

  /// Investor Group Methods

  /// Create a new investor group
  Future<DocumentReference<InvestorGroup>> createInvestorGroup(
      InvestorGroup group) async {
    try {
      final docRef = await investorGroupCollection.add(group);
      // Update the group with its own ID
      group.id = docRef.id;
      await docRef.update({'id': docRef.id});
      debugPrint(
          "Investor group created with ID: ${docRef.id} - ${group.name}");
      return docRef;
    } on FirebaseException catch (e) {
      debugPrint('Failed to create investor group: ${e.message}');
      rethrow;
    }
  }

  /// Get a specific investor group
  Future<InvestorGroup?> getInvestorGroup(String groupId) async {
    try {
      final doc = await investorGroupCollection.doc(groupId).get();
      return doc.data();
    } on FirebaseException catch (e) {
      debugPrint('Failed to get investor group: ${e.message}');
      return null;
    }
  }

  /// Get all investor groups where user is a member
  Stream<QuerySnapshot<InvestorGroup>> getUserInvestorGroups(String userId) {
    return investorGroupCollection
        .where('members', arrayContains: userId)
        .orderBy('dateCreated', descending: true)
        .snapshots();
  }

  /// Get all public investor groups
  Stream<QuerySnapshot<InvestorGroup>> getPublicInvestorGroups() {
    return investorGroupCollection
        .where('isPrivate', isEqualTo: false)
        .orderBy('dateCreated', descending: true)
        .snapshots();
  }

  /// Search investor groups by name
  Stream<QuerySnapshot<InvestorGroup>> searchInvestorGroups(
      {String? searchTerm}) {
    Query<InvestorGroup> query = investorGroupCollection;
    if (searchTerm != null && searchTerm.isNotEmpty) {
      String searchTermLower = searchTerm.toLowerCase();
      // Note: This is a basic implementation. For better search, consider using
      // a dedicated search service like Algolia or Elasticsearch
      query = query
          .orderBy('name')
          .startAt([searchTermLower]).endAt(['$searchTermLower\uf8ff']);
    }
    return query.orderBy('dateCreated', descending: true).snapshots();
  }

  /// Update an investor group
  Future<void> updateInvestorGroup(InvestorGroup group) async {
    group.dateUpdated = DateTime.now();
    try {
      await investorGroupCollection.doc(group.id).update(group.toJson());
      debugPrint("Investor group updated: ${group.id}");
    } on FirebaseException catch (e) {
      debugPrint('Failed to update investor group: ${e.message}');
      rethrow;
    }
  }

  /// Delete an investor group
  Future<void> deleteInvestorGroup(String groupId) async {
    try {
      await investorGroupCollection.doc(groupId).delete();
      debugPrint("Investor group deleted: $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to delete investor group: ${e.message}');
      rethrow;
    }
  }

  /// Add a user to an investor group
  Future<void> joinInvestorGroup(String groupId, String userId) async {
    try {
      await investorGroupCollection.doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
        'dateUpdated': DateTime.now(),
      });

      debugPrint("User $userId joined group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to join investor group: ${e.message}');
      rethrow;
    }
  }

  /// Remove a user from an investor group
  Future<void> leaveInvestorGroup(String groupId, String userId) async {
    try {
      await investorGroupCollection.doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
        'dateUpdated': DateTime.now(),
      });

      debugPrint("User $userId left group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to leave investor group: ${e.message}');
      rethrow;
    }
  }

  /// Add an admin to an investor group
  Future<void> addGroupAdmin(String groupId, String userId) async {
    try {
      await investorGroupCollection.doc(groupId).update({
        'admins': FieldValue.arrayUnion([userId]),
        'dateUpdated': DateTime.now(),
      });
      debugPrint("User $userId added as admin to group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to add group admin: ${e.message}');
      rethrow;
    }
  }

  /// Remove an admin from an investor group
  Future<void> removeGroupAdmin(String groupId, String userId) async {
    try {
      await investorGroupCollection.doc(groupId).update({
        'admins': FieldValue.arrayRemove([userId]),
        'dateUpdated': DateTime.now(),
      });
      debugPrint("User $userId removed as admin from group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to remove group admin: ${e.message}');
      rethrow;
    }
  }

  /// Send an invitation to a user to join an investor group
  Future<void> inviteUserToGroup(String groupId, String userId) async {
    try {
      await investorGroupCollection.doc(groupId).update({
        'pendingInvitations': FieldValue.arrayUnion([userId]),
        'dateUpdated': DateTime.now(),
      });
      debugPrint("Invitation sent to user $userId for group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to invite user to group: ${e.message}');
      rethrow;
    }
  }

  /// Accept an invitation to join an investor group
  Future<void> acceptGroupInvitation(String groupId, String userId) async {
    try {
      // Remove from pending invitations and add to members
      await investorGroupCollection.doc(groupId).update({
        'pendingInvitations': FieldValue.arrayRemove([userId]),
        'members': FieldValue.arrayUnion([userId]),
        'dateUpdated': DateTime.now(),
      });

      debugPrint("User $userId accepted invitation to group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to accept group invitation: ${e.message}');
      rethrow;
    }
  }

  /// Decline an invitation to join an investor group
  Future<void> declineGroupInvitation(String groupId, String userId) async {
    try {
      await investorGroupCollection.doc(groupId).update({
        'pendingInvitations': FieldValue.arrayRemove([userId]),
        'dateUpdated': DateTime.now(),
      });
      debugPrint("User $userId declined invitation to group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to decline group invitation: ${e.message}');
      rethrow;
    }
  }

  /// Remove a member from an investor group (admin action)
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    try {
      await investorGroupCollection.doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
        'admins': FieldValue.arrayRemove(
            [userId]), // Also remove from admins if present
        'dateUpdated': DateTime.now(),
      });

      debugPrint("User $userId removed from group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to remove member from group: ${e.message}');
      rethrow;
    }
  }

  /// Get all groups where user has a pending invitation
  Stream<QuerySnapshot<InvestorGroup>> getUserPendingInvitations(
      String userId) {
    return investorGroupCollection
        .where('pendingInvitations', arrayContains: userId)
        .orderBy('dateCreated', descending: true)
        .snapshots();
  }

  /// Group Chat Methods

  /// Get messages for a group
  Stream<QuerySnapshot<GroupMessage>> getGroupMessages(String groupId) {
    return investorGroupCollection
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .withConverter<GroupMessage>(
          fromFirestore: (snapshots, _) => GroupMessage.fromDocument(snapshots),
          toFirestore: (obj, _) => obj.toJson(),
        )
        .snapshots();
  }

  /// Mark a message as read
  Future<void> markGroupMessageAsRead(
      String groupId, String messageId, String userId) async {
    try {
      await investorGroupCollection
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy.$userId': Timestamp.now(),
      });
      // debugPrint("Message $messageId marked as read by $userId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to mark message as read: ${e.message}');
      // Don't rethrow for read receipt failure, just log it
    }
  }

  /// Send a message to a group
  Future<void> sendGroupMessage(String groupId, GroupMessage message) async {
    try {
      await investorGroupCollection
          .doc(groupId)
          .collection('messages')
          .add(message.toJson());
      debugPrint("Message sent to group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to send message: ${e.message}');
      rethrow;
    }
  }

  /// Update a group message
  Future<void> updateGroupMessage(String groupId, GroupMessage message) async {
    try {
      await investorGroupCollection
          .doc(groupId)
          .collection('messages')
          .doc(message.id)
          .update(message.toJson());
      debugPrint("Message updated in group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to update message: ${e.message}');
      rethrow;
    }
  }

  /// Delete a group message
  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    try {
      await investorGroupCollection
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .delete();
      debugPrint("Message deleted from group $groupId");
    } on FirebaseException catch (e) {
      debugPrint('Failed to delete message: ${e.message}');
      rethrow;
    }
  }

  /// Instrument Notes Methods

  CollectionReference<InstrumentNote> getNotesCollection(String userId) {
    return userCollection
        .doc(userId)
        .collection('notes')
        .withConverter<InstrumentNote>(
          fromFirestore: (snapshots, _) =>
              InstrumentNote.fromJson(snapshots.data()!),
          toFirestore: (obj, _) => obj.toJson(),
        );
  }

  Stream<DocumentSnapshot<InstrumentNote>> getInstrumentNoteStream(
      String userId, String symbol) {
    return getNotesCollection(userId).doc(symbol).snapshots();
  }

  Future<void> saveInstrumentNote(String userId, InstrumentNote note) async {
    try {
      await getNotesCollection(userId).doc(note.symbol).set(note);
      debugPrint("Note saved for ${note.symbol}");
    } on FirebaseException catch (e) {
      debugPrint('Failed to save note: ${e.message}');
      rethrow;
    }
  }

  Future<void> deleteInstrumentNote(String userId, String symbol) async {
    try {
      await getNotesCollection(userId).doc(symbol).delete();
      debugPrint("Note deleted for $symbol");
    } on FirebaseException catch (e) {
      debugPrint('Failed to delete note: ${e.message}');
      rethrow;
    }
  }
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
