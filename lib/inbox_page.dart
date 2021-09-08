import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'direct_message_page.dart';
import 'join_group_page.dart';
import 'main.dart';
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
        title: const Text('Inbox', style: TextStyle(color: Colors.white)),
      ),
      drawer: Drawer(
          child: ListView(
              children: [
                ListTile(
                    title: const Text('Home'),
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyHomePage()));
                    }
                ),
                ListTile(
                    title: const Text('Join Another Group'),
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => JoinGroupPage()));
                    }
                ),
                ListTile(
                    title: const Text('Messages'),
                    onTap: () {

                    }
                ),
                ListTile(
                    title: const Text('Logout'),
                    onTap: () async {
                      await AuthService().logout();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignInPage()));
                    }
                ),
              ]
          )
      ),
      body: conversations == null || conversations.isEmpty ? const Center(child: Text('You don\'t have any direct message conversations yet!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)))
        : ListView(
        children: conversations.map((convo) {
          String? otherUid = convo.members?.firstWhere((element) => element != currentUser?.id, orElse: null);
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
                          child: Text(userSnap.data?.name ?? 'Unknown User',
                              style: const TextStyle(fontSize: 18))
                      ),
                    ),
                    onTap: () {
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
