const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//
// exports.helloWorld = functions.https.onRequest((request, response) => {
//   functions.logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
exports.sendGroupNotification = functions.firestore.document("/groups/{groupId}/messages/{messageId}")
	.onCreate( async (snap, context) => {
		const messageData = snap.data();
		const senderId = messageData["sender_id"];
		const group = await db.collection("groups").doc(context.params.groupId).get();
		const groupMemberIds = group.data()["members"];
		console.log("Group Members: " + groupMemberIds);
		const tokens = [];

		for (const memberId of groupMemberIds) {
			console.log("Member: " + memberId + "/ Sender: " + senderId);
			if (memberId !== senderId) {
				const member = await db.collection("users").doc(memberId).get();
				const allNotifications = member.data()["all_notifications"];
				const groupNotifications = member.data()["group_message_notifications"];
				const memberTokens = member.data()["tokens"];
				// console.log("Member Tokens: " + memberTokens + "/ Total Tokens: " + tokens + "/ All Notifications: " + allNotifications + "/ Group Notifications: " + groupNotifications);
				if ((allNotifications !== null && allNotifications) || (groupNotifications !== null && groupNotifications)) {
					// console.log("Adding tokens");
					if (memberTokens !== null && memberTokens !== undefined && memberTokens.length > 0) {
						for (const tk of memberTokens) {
							if (tk !== null && tk !== undefined) {
								// console.log("adding token: " + tk);
								tokens.push(tk);
							}
						}
					}
				}
			}
		}

		if (tokens.length > 0) {
			const response = await admin.messaging().sendToDevice(
				tokens,
				{
					notification: {
						title: "New message from " + messageData["sender_name"] + " in group " + group.data()["topic"],
						body: messageData["message_text"],
					},
					data: {
						group_id: messageData["group_id"],
					},
				},
			);
			console.log("Group Notification Response: " + response);
			console.log("Sent to Tokens: " + tokens);
			return;
		}
		console.log("No tokens to send notification");
		return;
	});

exports.sendDirectMessageNotification = functions.firestore.document("/direct-messages/{dmId}/messages/{messageId}")
	.onCreate( async (snap, context) => {
		const messageData = snap.data();
		const senderId = messageData["sender_id"];
		const convo = await db.collection("direct-messages").doc(context.params.dmId).get();
		const memberIds = convo.data()["members"];
		console.log("Members: " + memberIds);
		const tokens = [];

		for (const memberId of memberIds) {
			console.log("Member: " + memberId + "/ Sender: " + senderId);
			if (memberId !== senderId) {
				const member = await db.collection("users").doc(memberId).get();
				const allNotifications = member.data()["all_notifications"];
				const dmNotifications = member.data()["direct_message_notifications"];
				const memberTokens = member.data()["tokens"];
				// console.log("Member Tokens: " + memberTokens + "/ Total Tokens: " + tokens + "/ All Notifications: " + allNotifications + "/ Group Notifications: " + groupNotifications);
				if ((allNotifications !== null && allNotifications) || (dmNotifications !== null && dmNotifications)) {
					// console.log("Adding tokens");
					if (memberTokens !== null && memberTokens !== undefined && memberTokens.length > 0) {
						for (const tk of memberTokens) {
							if (tk !== null && tk !== undefined) {
								// console.log("adding token: " + tk);
								tokens.push(tk);
							}
						}
					}
				}
			}
		}

		if (tokens.length > 0) {
			const response = await admin.messaging().sendToDevice(
				tokens,
				{
					notification: {
						title: "New direct message from " + messageData["sender_name"],
						body: messageData["message_text"],
					},
					data: {
						dm_user_id: senderId,
					},
				},
			);
			console.log("DM Notification Response: " + response);
			console.log("Sent to Tokens: " + tokens);
			return;
		}
		console.log("No tokens to send notification");
		return;
	});
