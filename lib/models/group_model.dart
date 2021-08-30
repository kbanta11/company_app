import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_services.dart';

class Group {
  String? id;
  int? numMembers;
  String? topic;
  List<String>? members;
  String? code;

  Group({
    this.id,
    this.numMembers,
    this.topic,
    this.members,
    this.code
  });

  factory Group.fromFirestore(DocumentSnapshot snap) {
    Map<String,dynamic> data = snap.data() as Map<String,dynamic>;
    return Group(
      id: data['id'],
      numMembers: data['num_members'],
      topic: data['topic'],
      members: List.castFrom(data['members'] as List),
      code: data['code']
    );
  }

  Stream<List<Message>> getMessages() {
    return DatabaseServices().getMessagesForGroup(groupId: id);
  }
}

class Message {
  String? id;
  String? groupId;
  String? senderId;
  String? senderName;
  String? messageText;
  DateTime? dateSent;
  String? imageUrl;
  bool hasImage;

  Message({
    this.id,
    this.groupId,
    this.senderId,
    this.senderName,
    this.messageText,
    this.dateSent,
    this.imageUrl,
    this.hasImage = false
  });

  factory Message.fromFirestore(DocumentSnapshot snap) {
    Map<String,dynamic> data = snap.data() as Map<String,dynamic>;
    Message msg = Message(
        id: snap.id,
        groupId: data['group_id'],
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