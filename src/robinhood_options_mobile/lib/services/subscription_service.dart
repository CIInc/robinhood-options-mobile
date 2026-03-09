import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:robinhood_options_mobile/model/user.dart';

class SubscriptionService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Products IDs - these should be configured in App Connect / Play Console
  static const String monthlySubscriptionId = 'trade_signals_monthly';
  static const Set<String> _kIds = <String>{monthlySubscriptionId};

  // Singleton pattern
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() {
    return _instance;
  }

  SubscriptionService._internal();

  void initialize() {
    debugPrint('SubscriptionService: Initializing...');
    
    // Check if IAP is available
    _iap.isAvailable().then((available) {
      debugPrint('SubscriptionService: IAP available: $available');
    });

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      debugPrint(
          'SubscriptionService: IAP Stream Event: ${purchaseDetailsList.length} items received');
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      debugPrint('SubscriptionService: IAP Stream Done');
      _subscription?.cancel();
    }, onError: (error) {
      debugPrint('SubscriptionService: IAP Stream Error: $error');
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    debugPrint('_listenToPurchaseUpdated: $purchaseDetailsList');
    for (var purchaseDetails in purchaseDetailsList) {
      debugPrint('Processing purchase: ${purchaseDetails.productID} '
          'status: ${purchaseDetails.status} '
          'error: ${purchaseDetails.error}');
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
        debugPrint('Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('Purchase success/restored, starting verification...');
          await _verifyAndDeliverProduct(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          debugPrint('Completing purchase for ${purchaseDetails.productID}');
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    // In a real app, verify receipt with server.
    // Here we update Firestore directly for now.
    debugPrint('_verifyAndDeliverProduct for ${purchaseDetails.productID}');

    // Get current user UID
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('Purchase success but no user logged in. Cannot deliver.');
      return;
    }
    debugPrint('Current User UID: ${currentUser.uid}');

    // Update Firestore
    // Note: For subscriptions, ideally we validate receipt with Apple/Google servers
    // to get the actual expiry date. Here we assume 1 month from now for fresh purchases
    // or rely on server-side logic if implemented.
    // For this client-side implementation:
    try {
      final expiry = DateTime.now().add(const Duration(days: 30));
      await _db.collection('user').doc(currentUser.uid).update({
        'subscriptionStatus': 'active',
        'subscriptionExpiryDate': Timestamp.fromDate(expiry),
        'subscriptionProductId': purchaseDetails.productID,
        'subscriptionPurchaseDate': FieldValue.serverTimestamp(),
        'dateUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint(
          'Purchase successful and delivered: ${purchaseDetails.productID}');
    } catch (e) {
      debugPrint('Error delivering purchase: $e');
    }
  }

  Future<void> buySubscription(ProductDetails product) async {
    debugPrint('SubscriptionService: buySubscription for ${product.id}');
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      if (kIsWeb) {
        // IAP not supported on web
        throw Exception('In-app purchases are not supported on web.');
      }
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('SubscriptionService: buyNonConsumable call successful');
    } catch (e) {
      debugPrint('SubscriptionService: Error in buySubscription: $e');
      rethrow;
    }
  }

  Future<List<ProductDetails>> loadProducts() async {
    if (!(await _iap.isAvailable())) {
      return [];
    }
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }
    return response.productDetails;
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  // Trial Logic

  Future<void> startTrial(User user, DocumentReference<User> userDocRef) async {
    if (isTrialEligible(user)) {
      final trialStart = DateTime.now();
      final expiryDate = trialStart.add(const Duration(days: 14));

      await userDocRef.update({
        'subscriptionStatus': 'trial',
        'trialStartDate': Timestamp.fromDate(trialStart),
        'subscriptionExpiryDate': Timestamp.fromDate(expiryDate),
        'dateUpdated': FieldValue.serverTimestamp(),
      });

      // Update local state is handled by the stream in the app usually, but we can do it here too just in case
      user.subscriptionStatus = 'trial';
      user.trialStartDate = trialStart;
      user.subscriptionExpiryDate = expiryDate;
    }
  }

  bool isSubscriptionActive(User user) {
    if (user.subscriptionStatus == 'active') {
      // Check expiry if needed (if auto-renew logic writes expiry)
      // Usually for 'active' subscription managed by store, we might rely on 'active' status + date.
      if (user.subscriptionExpiryDate != null) {
        return user.subscriptionExpiryDate!.isAfter(DateTime.now());
      }
      // If no date but status is active (e.g. lifetime), return true.
      // But here we assume monthly.
      return true;
    }
    if (user.subscriptionStatus == 'trial') {
      if (user.subscriptionExpiryDate != null &&
          user.subscriptionExpiryDate!.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  bool isTrialEligible(User user) {
    return user.trialStartDate == null;
  }
}
