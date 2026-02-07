import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

/**
 * Triggered when a new message is added to an investor group.
 * Sends a push notification to all other members of the group.
 */
export const onGroupMessageCreated = onDocumentCreated(
  "investor_groups/{groupId}/messages/{messageId}",
  async (event) => {
    const groupId = event.params.groupId;
    const loggingPrefix = `[onGroupMessageCreated][${groupId}]`;

    if (!event.data) {
      console.log(`${loggingPrefix} No data associated with the event`);
      return;
    }

    const message = event.data.data();
    if (!message) {
      console.log(`${loggingPrefix} Message data is empty`);
      return;
    }

    const senderId = message.senderId;
    const senderName = message.senderName;
    const text = message.text;

    // Get group details
    const groupDoc = await admin.firestore()
      .collection("investor_groups")
      .doc(groupId)
      .get();
    if (!groupDoc.exists) {
      console.log(`${loggingPrefix} Group does not exist.`);
      return;
    }
    const group = groupDoc.data();
    const groupName = group?.name || "Investor Group";
    const members = group?.members || [];

    // Filter out sender
    const recipients = members.filter((uid: string) => uid !== senderId);

    if (recipients.length === 0) {
      console.log(`${loggingPrefix} No recipients for message.`);
      return;
    }

    // Get tokens for recipients
    // We need to fetch each user's document to get their devices/FCM tokens
    // Firestore limited to 10 'in' queries, so efficient batching is ideal,
    // but for now we'll do promise.all for simplicity assuming small groups.
    // If groups are large, we should duplicate tokens into a subcollection
    // or array in the group (with maintenance cost).

    const tokens: string[] = [];

    // Batched fetching is better
    const chunkSize = 10;
    for (let i = 0; i < recipients.length; i += chunkSize) {
      const chunk = recipients.slice(i, i + chunkSize);
      if (chunk.length === 0) continue;

      const userSnapshots = await admin.firestore()
        .collection("user")
        .where(admin.firestore.FieldPath.documentId(), "in", chunk)
        .get();

      userSnapshots.forEach((userDoc) => {
        const userData = userDoc.data();
        if (userData && userData.devices && Array.isArray(userData.devices)) {
          userData.devices.forEach((device: any) => {
            if (device.fcmToken) {
              tokens.push(device.fcmToken);
            }
          });
        }
      });
    }

    if (tokens.length === 0) {
      console.log(`${loggingPrefix} No tokens found for recipients.`);
      return;
    }

    // Deduplicate tokens
    const uniqueTokens = [...new Set(tokens)];

    // Send notification
    // FCM Multicast allows up to 500 tokens

    const payload: admin.messaging.MulticastMessage = {
      tokens: uniqueTokens,
      notification: {
        title: `💬 ${groupName}`,
        body: `${senderName}: ${text}`,
      },
      data: {
        type: "group_message",
        groupId: groupId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        notification: {
          sound: "default",
          tag: groupId, // Group by group ID
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            threadId: groupId, // Group by group ID on iOS
          },
        },
      },
    };

    if (uniqueTokens.length > 500) {
      // Simple chunking for > 500
      const tokenChunks = [];
      for (let i = 0; i < uniqueTokens.length; i += 500) {
        tokenChunks.push(uniqueTokens.slice(i, i + 500));
      }

      for (const chunk of tokenChunks) {
        const chunkPayload = { ...payload, tokens: chunk };
        try {
          const response = await admin.messaging()
            .sendEachForMulticast(chunkPayload);
          console.log(
            `${loggingPrefix} Sent chunk: ${response.successCount} success, ` +
            `${response.failureCount} failed.`
          );
        } catch (e) {
          console.error(`${loggingPrefix} Error sending multicast chunk:`, e);
        }
      }
    } else {
      try {
        const response = await admin.messaging().sendEachForMulticast(payload);
        console.log(
          `${loggingPrefix} Sent ${response.successCount} messages, ` +
          `failed ${response.failureCount}`
        );
      } catch (e) {
        console.error(`${loggingPrefix} Error sending multicast:`, e);
      }
    }
  }
);
