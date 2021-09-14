import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationMember {
  String? userId;
  String? name;
  int? unreadMessages;

  ConversationMember({this.userId, this.name, this.unreadMessages});

  toMap() {
    return {
      'name': name,
      'unread_messages': unreadMessages,
      'user_id': userId,
    };
  }

  factory ConversationMember.fromMap(Map data) {
    return ConversationMember(
      userId: data['user_id'],
      unreadMessages: data['unread_messages'],
      name: data['name']
    );
  }
}

class Conversation {
  String? id;
  List<String>? members;
  List<ConversationMember>? memberMap;
  DateTime? lastPostDate;

  Conversation({
    this.id,
    this.members,
    this.memberMap,
    this.lastPostDate,
  });

  factory Conversation.fromFirestore(DocumentSnapshot snap) {
    Map<String,dynamic> data = snap.data() as Map<String,dynamic>;
    return Conversation(
      id: data['id'],
      members: List.castFrom(data['members'] as List),
      memberMap: List.castFrom(data['member_map'] as List).map((element) => ConversationMember.fromMap(element)).toList(),
      lastPostDate: DateTime.fromMillisecondsSinceEpoch(data['last_post_date'].millisecondsSinceEpoch),
    );
  }
}

class DirectMessage {
  String? id;
  String? senderId;
  String? senderName;
  String? messageText;
  DateTime? dateSent;
  String? imageUrl;
  bool hasImage;

  DirectMessage({
    this.id,
    this.senderId,
    this.senderName,
    this.messageText,
    this.dateSent,
    this.imageUrl,
    this.hasImage = false
  });

  factory DirectMessage.fromFirestore(DocumentSnapshot snap) {
    Map<String,dynamic> data = snap.data() as Map<String,dynamic>;
    DirectMessage msg = DirectMessage(
        id: snap.id,
        senderId: data['sender_id'],
        senderName: data['sender_name'],
        messageText: data['message_text'],
        dateSent: DateTime.fromMillisecondsSinceEpoch(data['date_sent'].millisecondsSinceEpoch),
        imageUrl: data['image_url'],
        hasImage: data['has_image'] ?? false
    );
    return msg;
  }
}