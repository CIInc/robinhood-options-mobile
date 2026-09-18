import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_message.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('GroupMessage Model Tests', () {
    test('GroupMessage serializes and deserializes correctly', () {
      final now = DateTime(2026, 9, 16, 11, 0);
      final message = GroupMessage(
        id: 'msg-1',
        senderId: 'user-sender',
        senderName: 'Alice',
        senderPhotoUrl: 'https://example.com/avatar.png',
        text: 'SPY calls printing today!',
        timestamp: now,
        type: MessageType.text,
        readBy: {'user-reader': now},
      );

      final json = message.toJson();
      expect(json['senderId'], equals('user-sender'));
      expect(json['senderName'], equals('Alice'));
      expect(json['text'], equals('SPY calls printing today!'));
      expect(json['type'], equals('text'));
      expect(json['readBy'], contains('user-reader'));
    });
  });

  group('FirestoreService Group Chat Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService service;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      service = FirestoreService(firestore: fakeDb);
    });

    test(
        'sendGroupMessage, getGroupMessages, markGroupMessageAsRead and delete',
        () async {
      const groupId = 'group-chat-test';

      // Seed investor group doc
      final group = InvestorGroup(
        id: groupId,
        name: 'Options Alpha',
        createdBy: 'user-admin',
        members: ['user-admin', 'user-member'],
        dateCreated: DateTime.now(),
      );
      await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .set(group.toJson());

      final msg = GroupMessage(
        id: 'msg-123',
        senderId: 'user-admin',
        senderName: 'Admin',
        text: 'Welcome to the options trading room!',
        timestamp: DateTime.now(),
      );

      await service.sendGroupMessage(groupId, msg);

      // Verify stream
      final snapshot = await service.getGroupMessages(groupId).first;
      expect(snapshot.docs.length, equals(1));
      final received = snapshot.docs.first.data();
      expect(received.text, equals('Welcome to the options trading room!'));

      final docId = snapshot.docs.first.id;

      // Mark as read by member
      await service.markGroupMessageAsRead(groupId, docId, 'user-member');
      final updatedSnapshot = await service.getGroupMessages(groupId).first;
      final updatedMsg = updatedSnapshot.docs.first.data();
      expect(updatedMsg.readBy.containsKey('user-member'), isTrue);

      // Delete message
      await service.deleteGroupMessage(groupId, docId);
      final emptySnapshot = await service.getGroupMessages(groupId).first;
      expect(emptySnapshot.docs.isEmpty, isTrue);
    });
  });
}
