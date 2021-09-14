import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_services.dart';

class TopicModel {
  String? id;
  String? topic;
  List<String>? subTopics;
  DateTime? createDate;
  int? numGroups;

  TopicModel({
    this.id,
    this.topic,
    this.subTopics,
    this.createDate,
    this.numGroups
  });

  factory TopicModel.fromFirestore(DocumentSnapshot snap) {
    Map<String,dynamic> data = snap.data() as Map<String,dynamic>;
    return TopicModel(
      id:snap.id,
      topic: data['topic'],
      subTopics: List.castFrom(data['sub-topics'] as List),
      createDate: DateTime.fromMillisecondsSinceEpoch(data['created_date'].millisecondsSinceEpoch),
      numGroups: data['num_groups']
    );
  }
}

class Group {
  String? id;
  int? numMembers;
  String? topic;
  List<String>? members;
  String? code;
  String? topicId;
  DateTime? lastMessageDate;
  Map<String, dynamic>? memberMap;

  Group({
    this.id,
    this.numMembers,
    this.topic,
    this.members,
    this.code,
    this.topicId,
    this.lastMessageDate,
    this.memberMap
  });

  factory Group.fromFirestore(DocumentSnapshot snap) {
    Map<String,dynamic> data = snap.data() as Map<String,dynamic>;
    return Group(
      id: data['id'],
      numMembers: data['num_members'],
      topic: data['topic'],
      topicId: data['topic_id'],
      members: List.castFrom(data['members'] as List),
      code: data['code'],
      lastMessageDate: data['last_message_date'] == null ? null : DateTime.fromMillisecondsSinceEpoch(data['last_message_date'].millisecondsSinceEpoch),
      memberMap: data['member_map'] == null ? null :data['member_map'] as Map<String, dynamic>,
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