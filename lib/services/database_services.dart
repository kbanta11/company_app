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

  //User Functions
  Future<AppUser> getAppUser(String userId) async {
    return db.collection('users').doc(userId).get().then((snap) => AppUser.fromFirestore(snap));
  }

  Future<void> createUser({String? id, String? name, String? email, String? firstTopic, String? code}) async {
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
    batch.update(groupRef, {
      'members': group.members,
      'num_members': group.numMembers! - 1,
    });
    //remove group id from users list of groups
    user.groups?.removeWhere((element) => element == group.id);
    batch.update(userRef, {
      'groups': user.groups
    });
    await batch.commit();
  }

  Future<Group> joinGroup({String? topic, String? userId, String? userName}) async {
    Group group;
    //get all groups for this topic that have less than 8 members
    List<Group> availableGroups = await db.collection('groups').where('topic', isEqualTo: topic).where('num_members', isLessThan: 8).get().then((QuerySnapshot qs) {
      return qs.docs.map((docSnap) => Group.fromFirestore(docSnap)).toList();
    });
    availableGroups.removeWhere((element) => element.members!.contains(userId));
    print('Available Groups: $availableGroups');
    //if there is a group with less than 3 members, join this group
    if(availableGroups.where((group) => group.numMembers! < 3).isNotEmpty) {
      group = availableGroups.where((group) => group.numMembers! < 3).first;
      print('Group to join: ${group.id}');
      WriteBatch batch = db.batch();
      //update group to add member
      DocumentReference groupRef = db.collection('groups').doc(group.id);
      group.numMembers = group.numMembers! + 1;
      group.members!.add(userId!);
      batch.update(groupRef, {
        'num_members': group.numMembers,
        'members': group.members,
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
        'topic': topic,
        'members': [userId],
        'code': customAlphabet('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ', 8)
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
      group = Group(id: docRef.id, numMembers: 1, topic: topic, members: [userId!]);
    } else {
      //otherwise, select random group from available and add member
      int randIndex = Random().nextInt(availableGroups.length);
      group = availableGroups[randIndex];
      WriteBatch batch = db.batch();
      //update group to add member
      DocumentReference groupRef = db.collection('groups').doc(group.id);
      group.numMembers = group.numMembers! + 1;
      group.members!.add(userId!);
      batch.update(groupRef, {
        'num_members': group.numMembers,
        'members': group.members,
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
    batch.update(groupRef, {
      'members': group.members,
      'num_members': group.numMembers
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
    await db.runTransaction((transaction) {
      transaction.set(newMessageRef, {
        'id': newMessageRef.id,
        'group_id': groupId,
        'sender_id': senderId,
        'sender_name':  senderName,
        'message_text': message,
        'image_url': downloadUrl,
        'has_image': downloadUrl != null ? true : false,
        'date_sent': DateTime.now()
      });
      return Future.value();
    });
    return;
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
    Query query = db.collection('direct-messages');
    for(AppUser? member in members) {
      query = query.where('members', arrayContains: member?.id);
    }
    return query.get().then((event) {
      return event.docs.isNotEmpty ? event.docs.map((qs) => Conversation.fromFirestore(qs)).first : null;
    });
  }

  Stream<Conversation?> streamConversationFromMembers(List<AppUser?> members) {
    Query query = db.collection('direct-messages');
    for(AppUser? member in members) {
      query = query.where('members', arrayContains: member?.id);
    }
    print('query: ${query.toString()}');
    return query.snapshots().map((event) {
      print('event: ${event.docs}');
      return event.docs.isNotEmpty ? event.docs.map((snap) => Conversation.fromFirestore(snap)).first : null;
    });
  }

  Future<Conversation> createConversation(List<AppUser?> members) async {
    DocumentReference newDocRef = db.collection('direct-messages').doc();
    Map<String, dynamic> data = {
      'id': newDocRef.id,
      'members': members.map((user) => user?.id).toList(),
      'member_map': members.map((user) => {'user_id': user?.id, 'unread_messages': 0, 'name': user?.name,}).toList(),
      'last_post_date': DateTime.now(),
    };
    await db.runTransaction((transaction) async {
      transaction.set(newDocRef, data);
    });
    return await newDocRef.get().then((snap) => Conversation.fromFirestore(snap));
  }

  Future<void> sendDirectMessage({Conversation? conversation, String? senderId, String? senderName, String? message, XFile? file}) async {
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
    await db.runTransaction((transaction) {
      transaction.set(newMessageRef, {
        'id': newMessageRef.id,
        'conversation_id': conversation?.id,
        'sender_id': senderId,
        'sender_name':  senderName,
        'message_text': message,
        'image_url': downloadUrl,
        'has_image': downloadUrl != null ? true : false,
        'date_sent': DateTime.now()
      });
      return Future.value();
    });
    return;
  }
}