import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:nanoid/nanoid.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/direct_message_models.dart';
import 'dart:math';

class DatabaseServices {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  /*
  Future<void> seedGroupData() async {
    WriteBatch batch = db.batch();

    await db.collection('groups').get().then((qs) async {
      for(var doc in qs.docs) {
        Group group = Group.fromFirestore(doc);
        //update group last message date
        //get all messages for group, then check most recent date or set to 1/1/2000 otherwise
        List<Message> messages = await group.getMessages().first;
        Map<String, dynamic> memberMap = Map<String, dynamic>();
        for(var member in group.members ?? []) {
          memberMap[member] = {
            'unread': 1,
            'last_seen': DateTime(2000, 1, 1),
          };
        }
        batch.update(doc.reference, {
          'last_message_date': messages.isNotEmpty ? messages.first.dateSent : DateTime(2000, 1, 1),
          'member_map': memberMap
        });
      }
    });
    await batch.commit();
    print('Updated group documents');
  }
   */

  //User Functions
  Future<AppUser> getAppUser(String userId) async {
    return db.collection('users').doc(userId).get().then((snap) => AppUser.fromFirestore(snap));
  }

  Future<void> createUser({String? id, String? name, String? email, TopicModel? firstTopic, String? code}) async {
    DocumentReference docRef = db.collection('users').doc(id);
    await db.runTransaction((transaction) {
      transaction.set(docRef, {
        'id': id,
        'name': name,
        'email': email,
        'groups': []
      });
      return Future.value();
    });
    if(code != null) {
      await joinGroupWithCode(code: code, userId: id);
      return;
    }
    await joinGroup(topic: firstTopic, userId: id, userName: name);
    return;
  }

  Future<void> updateUserTokens(String? token, AppUser? user) async {
    DocumentReference userDoc = db.collection('users').doc(user?.id);
    await db.runTransaction((transaction) {
      transaction.update(userDoc, {
        'tokens': FieldValue.arrayUnion([token])
      });
      return Future.value();
    });
  }

  Future<void> updateNotificationSettings(AppUser? currentUser, {bool? allNotifications, bool? directMessages, bool? groupMessages, bool? other}) async {
    DocumentReference userDoc = db.collection('users').doc(currentUser?.id);
    await db.runTransaction((transaction) async {
      transaction.update(userDoc, {
        'all_notifications': allNotifications ?? await userDoc.get().then((snap) {
          Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
          return data['all_notifications'];
        }),
        'direct_message_notifications': directMessages ?? await userDoc.get().then((snap) {
          Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
          return data['direct_message_notifications'];
        }),
        'group_message_notifications': groupMessages ?? await userDoc.get().then((snap) {
          Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
          return data['group_message_notifications'];
        }),
        'other_notifications': other ?? await userDoc.get().then((snap) {
          Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
          return data['other_notifications'];
        }),
      });
      return Future.value();
    });
    return;
  }

  Stream<AppUser> streamUserData(String uid) {
    DocumentReference docRef = db.collection('users').doc(uid);
    return docRef.snapshots().map((DocumentSnapshot snap) => AppUser.fromFirestore(snap));
  }

  //Group Functions
  Future<void> leaveGroup({Group? group, AppUser? user}) async {
    DocumentReference groupRef = db.collection('groups').doc(group!.id);
    DocumentReference userRef = db.collection('users').doc(user!.id);

    WriteBatch batch = db.batch();
    //remove user id from list of members and decrement number of members for group
    group.members?.removeWhere((element) => element == user.id);
    if(user.id != null && (group.memberMap?.containsKey(user.id) ?? false)) {
      group.memberMap?.remove(user.id);
    }
    batch.update(groupRef, {
      'members': group.members,
      'num_members': group.numMembers! - 1,
      'member_map': group.memberMap
    });
    //remove group id from users list of groups
    user.groups?.removeWhere((element) => element == group.id);
    batch.update(userRef, {
      'groups': user.groups
    });
    await batch.commit();
  }

  Future<TopicModel?> createTopic({String? topic, List<String>? subTopics}) async {
    DocumentReference newTopicRef = db.collection('topics').doc();
    await db.runTransaction((transaction) {
      transaction.set(newTopicRef, {
        'id': newTopicRef.id,
        'topic': topic,
        'sub-topics': subTopics,
        'created_date': DateTime.now(),
      });
      return Future.value();
    });
    return await newTopicRef.get().then((snap) => TopicModel.fromFirestore(snap));
  }

  Future<Group> joinGroup({TopicModel? topic, String? userId, String? userName}) async {
    Group group;
    //get all groups for this topic that have less than 8 members
    List<Group> availableGroups = await db.collection('groups').where('topic_id', isEqualTo: topic?.id).where('num_members', isLessThan: 8).get().then((QuerySnapshot qs) {
      return qs.docs.map((docSnap) => Group.fromFirestore(docSnap)).toList();
    });
    availableGroups.removeWhere((element) => element.members!.contains(userId));
    //print('Available Groups: $availableGroups');
    //if there is a group with less than 3 members, join this group
    if(availableGroups.where((group) => group.numMembers! < 3).isNotEmpty) {
      group = availableGroups.where((group) => group.numMembers! < 3).first;
      //print('Group to join: ${group.id}');
      WriteBatch batch = db.batch();
      //update group to add member
      DocumentReference groupRef = db.collection('groups').doc(group.id);
      group.numMembers = group.numMembers! + 1;
      group.members!.add(userId!);
      group.memberMap?[userId] = {
        'unread': 1,
        'last_seen': DateTime.now(),
      };
      batch.update(groupRef, {
        'num_members': group.numMembers,
        'members': group.members,
        'member_map': group.memberMap
      });
      //update user doc to add group id to list
      DocumentReference userRef = db.collection('users').doc(userId);
      AppUser userData = await userRef.get().then((snap) => AppUser.fromFirestore(snap));
      userData.groups!.add(group.id!);
      batch.update(userRef, {
        'groups': userData.groups
      });
      batch.commit();
      return group;
    }
    //if there are 2 or less groups, create new group
    if(availableGroups.length <= 2) {
      //get document reference for new group
      DocumentReference docRef = db.collection('groups').doc();
      WriteBatch batch = db.batch();
      //set data for new group document
      batch.set(docRef, {
        'id': docRef.id,
        'num_members': 1,
        'topic': topic?.topic,
        'topic_id': topic?.id,
        'members': [userId],
        'code': customAlphabet('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ', 8),
        'last_message_date': DateTime.now(),
        'member_map': {userId: {
          'last_seen': DateTime.now(),
          'unread': 0,
        }}
      });
      //update topic sheet to increment number in group
      DocumentReference topicRef = db.collection('topics').doc(topic?.id);
      int numGroups = await topicRef.get().then((snap) {
        TopicModel topic = TopicModel.fromFirestore(snap);
        if(topic.numGroups == null) {
          return 0;
        } else {
          return topic.numGroups!;
        }
      });
      batch.update(topicRef, {
        'num_groups': numGroups + 1
      });
      //update user doc to add group id to list
      DocumentReference userRef = db.collection('users').doc(userId);
      AppUser userData = await userRef.get().then((snap) => AppUser.fromFirestore(snap));
      List<String>? groups = userData.groups;
      groups?.add(docRef.id);
      batch.update(userRef, {
        'groups': groups
      });
      await batch.commit();
      group = Group(id: docRef.id, numMembers: 1, topic: topic?.topic, topicId: topic?.id, members: [userId!]);
    } else {
      //otherwise, select random group from available and add member
      int randIndex = Random().nextInt(availableGroups.length);
      group = availableGroups[randIndex];
      WriteBatch batch = db.batch();
      //update group to add member
      DocumentReference groupRef = db.collection('groups').doc(group.id);
      group.numMembers = group.numMembers! + 1;
      group.members!.add(userId!);
      group.memberMap?[userId] = {
        'unread': 1,
        'last_seen': DateTime.now(),
      };
      batch.update(groupRef, {
        'num_members': group.numMembers,
        'members': group.members,
        'member_map': group.memberMap,
      });
      //update user doc to add group id to list
      DocumentReference userRef = db.collection('users').doc(userId);
      AppUser userData = await userRef.get().then((snap) => AppUser.fromFirestore(snap));
      userData.groups!.add(group.id!);
      batch.update(userRef, {
        'groups': userData.groups
      });
      batch.commit();
    }
    return group;
  }

  Future<Group?> joinGroupWithCode({String? code, String? userId}) async {
    //get group with matching code
    Group? group = await db.collection('groups').where('code', isEqualTo: code).where('num_members', isLessThan: 8).snapshots().first.then((snap) {
      if(snap.docs.isEmpty) {
        return null;
      }
      return Group.fromFirestore(snap.docs.first)
    });
    if(group == null) {
      return null;
    }
    if(group.members!.contains(userId)) {
      return group;
    }
    WriteBatch batch = db.batch();
    //add user to group
    DocumentReference groupRef = db.collection('groups').doc(group.id);
    group.numMembers = group.numMembers! + 1;
    group.members!.add(userId!);
    group.memberMap?[userId] = {
      'unread': 1,
      'last_seen': DateTime.now(),
    };
    batch.update(groupRef, {
      'members': group.members,
      'num_members': group.numMembers,
      'member_map': group.memberMap
    });
    //add group to user
    DocumentReference userRef = db.collection('users').doc(userId);
    List<String>? groupList = await userRef.get().then((snap) => AppUser.fromFirestore(snap).groups);
    if(groupList == null) {
      groupList = [group.id!];
    } else {
      groupList.add(group.id!);
    }
    batch.update(userRef, {
      'groups': groupList
    });
    batch.commit();
    return group;
  }

  Future<bool> checkGroupExistsByCode(String code) async {
    Group? group = await db.collection('groups').where('code', isEqualTo: code).snapshots().first.then((snap) {
      if(snap.docs.isEmpty) {
        return null;
      }
      return Group.fromFirestore(snap.docs.first)
    });
    return group == null ? false : true;
  }

  Future<Group> getGroup(String groupId) async {
    return db.collection('groups').doc(groupId).get().then((snap) => Group.fromFirestore(snap));
  }

  Stream<List<Group>> getAllGroups({String? userId}) {
    return db.collection('groups').where('members', arrayContains: userId).snapshots().map((event) {
      return event.docs.map((snap) {
        Group group = Group.fromFirestore(snap);
        return group;
      }).toList();
    });
  }

  Stream<List<Message>> getMessagesForGroup({String? groupId}) {
    return db.collection('groups').doc(groupId).collection('messages').orderBy('date_sent', descending: true).snapshots().map((event) {
      return event.docs.map((snap) {
        Message msg = Message.fromFirestore(snap);
        return msg;
      }).toList();
    });
  }

  Future<void> sendMessageToGroup({String? groupId, String? senderId, String? senderName, String? message, XFile? file}) async {
    WriteBatch batch = db.batch();
    DocumentReference groupRef = db.collection('groups').doc(groupId);
    DocumentReference newMessageRef = db.collection('groups').doc(groupId).collection('messages').doc();
    //if has a file, upload to firebase
    String? downloadUrl;
    if(file != null) {
      Reference storageRef = storage.ref('groups/$groupId/${file.name}');
      UploadTask uploadTask = storageRef.putFile(File(file.path));
      TaskSnapshot taskSnap = await uploadTask.whenComplete(() => null);
      taskSnap.ref.getDownloadURL();
      downloadUrl = await taskSnap.ref.getDownloadURL();
    }
    //update member map to increment other users unread
    //update group time last message sent and increment unread message count for all other users
    Group? group = await groupRef.get().then((snap) => Group.fromFirestore(snap));
    print('old member map: ${group?.memberMap}');
    if(group?.memberMap != null && (group?.memberMap?.isNotEmpty ?? false)) {
      List<String>? keyList = group?.memberMap?.keys.toList();
      for(var key in keyList ?? []) {
        if(key != senderId) {
          group?.memberMap?[key]?['unread'] = (group.memberMap?[key]?['unread'] ?? 0) + 1;
        }
      }
    }
    print('new member map: ${group?.memberMap}');
    batch.update(groupRef, {
      'last_message_date': DateTime.now(),
      'member_map': group?.memberMap
    });
    print('updated group data');
    //add new doc for message
    batch.set(newMessageRef, {
      'id': newMessageRef.id,
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name':  senderName,
      'message_text': message,
      'image_url': downloadUrl,
      'has_image': downloadUrl != null ? true : false,
      'date_sent': DateTime.now()
    });
    await batch.commit();
    return;
  }

  Future<void> markGroupMessagesRead(Group? group, AppUser? user) async {
    DocumentReference groupRef = db.collection('groups').doc(group?.id);
    group?.memberMap?[user?.id]?['unread'] = 0;
    group?.memberMap?[user?.id]?['last_seen'] = DateTime.now();
    await db.runTransaction((transaction) async {
      transaction.update(groupRef, {
        'member_map': group?.memberMap,
      });
    });
  }

  //Inbox/Messaging Functions
  Stream<List<Conversation>> streamUserInbox(String? uid) {
    return db.collection('direct-messages').where('members', arrayContains: uid).orderBy('last_post_date', descending: true).snapshots().map((event) {
      return event.docs.map((snap) {
        Conversation conversation = Conversation.fromFirestore(snap);
        return conversation;
      }).toList();
    });
  }

  Stream<List<DirectMessage>> streamDirectMessages({String? conversationId}) {
    return db.collection('direct-messages').doc(conversationId).collection('messages').orderBy('date_sent', descending: true).snapshots().map((event) {
      return event.docs.map((snap) {
        DirectMessage message = DirectMessage.fromFirestore(snap);
        return message;
      }).toList();
    });
  }

  Future<Conversation?> getConversationFromMembers(List<AppUser?> members) {
    List<String?> memberIds = members.map((m) => m?.id).toList();
    memberIds.sort();
    Query query = db.collection('direct-messages').where('members', isEqualTo: memberIds);
    return query.get().then((event) {
      return event.docs.isNotEmpty ? event.docs.map((qs) => Conversation.fromFirestore(qs)).first : null;
    });
  }

  Stream<Conversation?> streamConversationFromMembers(List<AppUser?> members) {
    List<String?> memberIds = members.map((m) => m?.id).toList();
    memberIds.sort();
    print('sorted ids: $memberIds');
    Query query = db.collection('direct-messages').where('members', isEqualTo: memberIds);
    return query.snapshots().map((event) {
      return event.docs.isNotEmpty ? event.docs.map((snap) => Conversation.fromFirestore(snap)).first : null;
    });
  }

  Future<Conversation> createConversation(List<AppUser?> members) async {
    DocumentReference newDocRef = db.collection('direct-messages').doc();
    List<String?> memberIds = members.map((user) => user?.id).toList();
    memberIds.sort();
    Map<String, dynamic> data = {
      'id': newDocRef.id,
      'members': memberIds,
      'member_map': members.map((user) => {'user_id': user?.id, 'unread_messages': 0, 'name': user?.name,}).toList(),
      'last_post_date': DateTime.now(),
    };
    await db.runTransaction((transaction) async {
      transaction.set(newDocRef, data);
    });
    return await newDocRef.get().then((snap) => Conversation.fromFirestore(snap));
  }

  Future<void> sendDirectMessage({Conversation? conversation, String? senderId, String? senderName, String? message, XFile? file}) async {
    WriteBatch batch = db.batch();
    DocumentReference newMessageRef = db.collection('direct-messages').doc(conversation?.id).collection('messages').doc();
    //if has a file, upload to firebase
    String? downloadUrl;
    if(file != null) {
      Reference storageRef = storage.ref('direct-messages/${conversation?.id}/${file.name}');
      UploadTask uploadTask = storageRef.putFile(File(file.path));
      TaskSnapshot taskSnap = await uploadTask.whenComplete(() => null);
      taskSnap.ref.getDownloadURL();
      downloadUrl = await taskSnap.ref.getDownloadURL();
    }
    batch.set(newMessageRef, {
      'id': newMessageRef.id,
      'conversation_id': conversation?.id,
      'sender_id': senderId,
      'sender_name':  senderName,
      'message_text': message,
      'image_url': downloadUrl,
      'has_image': downloadUrl != null ? true : false,
      'date_sent': DateTime.now()
    });
    //increment unread messages for each user in conversation and on user doc
    List<ConversationMember> members = [];
    for(ConversationMember member in conversation!.memberMap ?? []) {
      if(member.userId != senderId) {
        //increment unread_messages in convo member map
        member.unreadMessages = (member.unreadMessages ?? 0) + 1;
        //get user data and increment unread direct messages
        AppUser user = await getAppUser(member.userId!);
        DocumentReference userRef = db.collection('users').doc(member.userId);
        batch.update(userRef, {
          'unread_direct_messages': user.unreadDirectMessages + 1
        });
      }
      members.add(member);
    }
    //update direct message doc
    DocumentReference convoRef = db.collection('direct-messages').doc(conversation.id);
    batch.update(convoRef, {
      'last_post_date': DateTime.now(),
      'member_map': members.map((member) => member.toMap()).toList()
    });
    await batch.commit();
    return;
  }

  Future<void> markDirectMessagesRead(Conversation? conversation, AppUser? user) async  {
    WriteBatch batch = db.batch();
    ConversationMember? member = conversation?.memberMap?.firstWhere((element) => element.userId == user?.id, orElse: null);
    int memberUnread = member?.unreadMessages ?? 0;
    //Mark conversation unread to 0
    DocumentReference convoRef = db.collection('direct-messages').doc(conversation?.id);
    batch.update(convoRef, {
      'member_map': conversation?.memberMap?.map((member) {
        if(member.userId == user?.id) {
          member.unreadMessages = 0;
        }
        return member.toMap();
      }).toList()
    });
    //decrement user total unread
    DocumentReference userRef = db.collection('users').doc(user?.id);
    //print('user unread: ${user?.unreadDirectMessages}, member unread: $memberUnread');
    batch.update(userRef, {
      'unread_direct_messages': max((user?.unreadDirectMessages ?? 0) - memberUnread, 0)
    });
    await batch.commit();
  }
}