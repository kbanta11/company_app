import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  String? id;
  String? name;
  String? email;
  List<String>? groups;
  int unreadDirectMessages;

  AppUser({
    this.id,
    this.name,
    this.email,
    this.groups,
    this.unreadDirectMessages = 0
  });

  factory AppUser.fromFirestore(DocumentSnapshot snap) {
    Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
    return AppUser(
      id: snap.id,
      name: data['name'],
      email: data['email'],
      groups: List.castFrom(data['groups'] as List),
      unreadDirectMessages: data['unread_direct_messages'] ?? 0
    );
  }
}