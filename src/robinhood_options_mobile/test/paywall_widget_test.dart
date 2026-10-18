import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/paywall_widget.dart';

void main() {
  testWidgets('dismisses after subscription becomes active in Firestore',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final userDocRef =
        firestore.collection('user').doc('test-user').withConverter<User>(
              fromFirestore: (snapshot, _) =>
                  User.fromJson(snapshot.data() ?? <String, Object?>{}),
              toFirestore: (user, _) => user.toJson(),
            );
    final user = User(
      name: 'Test User',
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
      subscriptionStatus: 'none',
    );
    await userDocRef.set(user);

    var successCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: PaywallWidget(
        user: user,
        userDocRef: userDocRef,
        onSuccess: () => successCount++,
      ),
    ));
    await tester.pump();

    await userDocRef.update({
      'subscriptionStatus': 'active',
      'subscriptionExpiryDate': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
    await tester.pump();

    expect(successCount, 1);
  });
}
