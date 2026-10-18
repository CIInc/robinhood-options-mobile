import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:robinhood_options_mobile/model/user.dart';

enum RestoreStatus { restored, nothingToRestore, signedOut, failed }

class RestoreResult {
  const RestoreResult(this.status, this.message);
  final RestoreStatus status;
  final String message;
}

class SubscriptionService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<RestoreResult>? _restoreInProgress;

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
    var verified = 0;
    String? lastError;
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
          lastError = 'The App Store reported an error. Please try again.';
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('Purchase success/restored, starting verification...');
          final error = await _verifyAndDeliverProduct(purchaseDetails);
          if (error == null) {
            verified++;
          } else {
            lastError = error;
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          debugPrint('Completing purchase for ${purchaseDetails.productID}');
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
    final restore = _restoreInProgress;
    if (restore != null && !restore.isCompleted) {
      restore.complete(restoreResultFor(verified: verified, error: lastError));
    }
  }

  /// Returns null once the receipt is verified, otherwise a message for the user.
  Future<String?> _verifyAndDeliverProduct(
      PurchaseDetails purchaseDetails) async {
    debugPrint('_verifyAndDeliverProduct for ${purchaseDetails.productID}');

    // Get current user UID
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('Purchase success but no user logged in. Cannot deliver.');
      return 'Sign in to restore your subscription.';
    }
    debugPrint('Current User UID: ${currentUser.uid}');

    try {
      final source = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'unsupported';
      await FirebaseFunctions.instance
          .httpsCallable('verifySubscription')
          .call({
        'productId': purchaseDetails.productID,
        'source': source,
        'verificationData':
            purchaseDetails.verificationData.serverVerificationData,
      });
      debugPrint('Subscription receipt submitted for verification.');
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Subscription verification failed: ${e.code} ${e.message}');
      return switch (e.code) {
        'permission-denied' =>
          'This Apple ID has no active subscription to restore.',
        'unauthenticated' => 'Sign in to restore your subscription.',
        'failed-precondition' =>
          'Restoring is unavailable right now. Please try again later.',
        _ => 'Could not verify your purchase. Please try again.',
      };
    } catch (e) {
      debugPrint('Subscription verification failed: $e');
      return 'Could not verify your purchase. Please try again.';
    }
  }

  /// Summarizes a restore batch: [verified] receipts accepted, last [error] seen.
  static RestoreResult restoreResultFor(
      {required int verified, String? error}) {
    if (verified > 0) {
      return const RestoreResult(
          RestoreStatus.restored, 'Subscription restored.');
    }
    if (error != null) return RestoreResult(RestoreStatus.failed, error);
    return const RestoreResult(RestoreStatus.nothingToRestore,
        'No purchases found to restore for this Apple ID.');
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

  /// Asks the store to restore purchases and waits for the receipt check.
  Future<RestoreResult> restorePurchases(
      {Duration timeout = const Duration(seconds: 20)}) async {
    if (auth.FirebaseAuth.instance.currentUser == null) {
      return const RestoreResult(
          RestoreStatus.signedOut, 'Sign in to restore your subscription.');
    }
    final completer = Completer<RestoreResult>();
    _restoreInProgress = completer;
    try {
      await _iap.restorePurchases();
      // Nothing arrives on the stream when the Apple ID has no purchases.
      return await completer.future
          .timeout(timeout, onTimeout: () => restoreResultFor(verified: 0));
    } catch (e) {
      debugPrint('SubscriptionService: restorePurchases failed: $e');
      return const RestoreResult(RestoreStatus.failed,
          'Could not reach the App Store. Please try again.');
    } finally {
      _restoreInProgress = null;
    }
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
