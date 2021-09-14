import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'direct_message_page.dart';
import 'join_group_page.dart';
import 'main.dart';
import 'menu_drawer.dart';
import 'signin_page.dart';
import 'services/auth_services.dart';
import 'providers/messaging_providers.dart';
import 'providers/auth_providers.dart';
import 'services/database_services.dart';
import 'models/direct_message_models.dart';
import 'models/user_model.dart';

class InboxPage extends ConsumerWidget {
  @override
  build(BuildContext context, ScopedReader watch) {
    AppUser? currentUser = watch(appUserProvider).data?.value;
    List<Conversation>? conversations = watch(inboxProvider).data?.value;
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF262626),
        leading: DrawerButton(currentUser),
        title: const Text('Inbox', style: TextStyle(color: Colors.white)),
      ),
      drawer: MenuDrawer('inbox-page'),
      body: conversations == null || conversations.isEmpty ? const Center(child: Text('You don\'t have any direct message conversations yet!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)))
        : ListView(
        children: conversations.map((convo) {
          String? otherUid = convo.members?.firstWhere((element) => element != currentUser?.id, orElse: null);
          int unread = convo.memberMap?.firstWhere((element) => element.userId == currentUser?.id, orElse: null)?.unreadMessages ?? 0;
          return otherUid == null ? Container() : FutureBuilder(
              future: DatabaseServices().getAppUser(otherUid),
              builder: (context, AsyncSnapshot<AppUser> userSnap) {
                return InkWell(
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                      elevation: 5.0,
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(userSnap.data?.name ?? 'Unknown User',
                                style: const TextStyle(fontSize: 18)),
                            unread > 0 ? Container(
                                height: 20,
                                width: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                                child: Center(
                                  child: Text('$unread', style: const TextStyle(color: Colors.white)),
                                )
                            ) : Container()
                          ],
                        )
                      ),
                    ),
                    onTap: () {
                      FirebaseAnalytics().logEvent(name: 'view_conversation', parameters: {
                        'event_date': DateTime.now().millisecondsSinceEpoch
                      });
                      //mark messages as read
                      DatabaseServices().markDirectMessagesRead(convo, currentUser);
                      Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (context) =>
                          DirectMessagePage(userSnap.data!,)));
                    }
                );
              }
          );
        }).toList(),
      ),
    );
  }
}
