import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'inbox_page.dart';
import 'models/user_model.dart';
import 'models/direct_message_models.dart';
import 'providers/auth_providers.dart';
import 'providers/image_select_provider.dart';
import 'services/auth_services.dart';
import 'services/database_services.dart';
import 'main.dart';
import 'join_group_page.dart';
import 'signin_page.dart';

final conversationProvider = StreamProvider.family<Conversation?, AppUser>((ref, target) {
  AppUser? currentUser = ref.watch(appUserProvider).data?.value;
  return DatabaseServices().streamConversationFromMembers([currentUser, target]);
});

class DirectMessagePage extends ConsumerWidget {
  AppUser targetUser;
  //Conversation? conversation;

  DirectMessagePage(this.targetUser);

  @override
  build(BuildContext context, ScopedReader watch) {
    AppUser? currentUser = watch(appUserProvider).data?.value;
    Conversation? conversation = watch(conversationProvider(targetUser)).data?.value;
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF262626),
        title: Text(targetUser.name!, style: const TextStyle(color: Colors.white)),
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
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => InboxPage()));
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
      body: conversation == null ? Column(
        children: [
          const Expanded(child: Center(child: Text('Start the conversation!', style: TextStyle(color: Colors.white)))),
          EnterDirectMessageWidget(currentUser: currentUser, targetUser: targetUser,),
          Platform.isIOS ? const SizedBox(height: 15) : Container()
        ],
      ) : StreamBuilder<List<DirectMessage>>(
          stream: DatabaseServices().streamDirectMessages(conversationId: conversation.id),
          builder: (context, AsyncSnapshot<List<DirectMessage>> snap) {
            if(snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if(!snap.hasData || (snap.data?.isEmpty ?? false)) {
              return Column(
                children: [
                  const Expanded(child: Center(child: Text('Start the conversation!', style: TextStyle(color: Colors.white)))),
                  EnterDirectMessageWidget(conversation: conversation, currentUser: currentUser, targetUser: targetUser,),
                  Platform.isIOS ? const SizedBox(height: 15) : Container()
                ],
              );
            }
            DateTime? lastMessageTime;
            String? lastSenderId;
            String? lastSenderName;
            return Column(
              children: [
                Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(10),
                      reverse: true,
                      children: snap.data?.asMap().entries.map((entry) {
                        int messageIndex = entry.key;
                        DirectMessage message = entry.value;
                        return FutureBuilder<AppUser?>(
                          future: DatabaseServices().getAppUser(message.senderId!),
                          builder: (context, AsyncSnapshot<AppUser?> userSnap) {
                            AppUser? sender = userSnap.data;
                            Widget messageCard = Card(
                              elevation: 10,
                              color: message.senderId == currentUser!.id ? Colors.cyan[200] : Colors.white,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
                              child: Padding(
                                padding:  const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    message.hasImage && message.imageUrl != null ? ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 450,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: message.imageUrl!,
                                        placeholder: (context, url) => const Center(child: SizedBox(child: CircularProgressIndicator(), height: 50, width: 50)),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ) : const SizedBox(width: 0, height: 0),
                                    SelectableLinkify(
                                        linkStyle: message.senderId == currentUser.id ? const TextStyle(color: Colors.deepOrange) : null,
                                        text: message.messageText ?? '',
                                        onOpen: (link) async {
                                          //print('URL: ${link.url} (${link.text})');
                                          if(await canLaunch(link.url)) {
                                            await launch(link.url);
                                          } else {
                                            await showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                    content: const Center(
                                                      child: Text('We\'re sorry! We were\'nt able to open this link!', textAlign: TextAlign.center,),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        child: const Text('Ok'),
                                                        onPressed: () {
                                                          Navigator.of(context).pop();
                                                        },
                                                      )
                                                    ],
                                                  );
                                                }
                                            );
                                          }
                                        }
                                    )
                                  ],
                                ),
                              ),
                            );
                            bool showName = false;
                            if((lastSenderId != null && lastSenderName != null && lastMessageTime != null) && (lastSenderId != message.senderId || (lastMessageTime?.difference(message.dateSent!).inMinutes ?? 3) >= 3)) {
                              showName = true;
                            }
                            //print('Time Diff: ${lastMessageTime?.difference(message.dateSent!).inMinutes} / Show Name? $showName \n Message: ${message.messageText} \n Index: $messageIndex (${snap.data?.length})');
                            Widget show = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                messageIndex == snap.data!.length - 1 ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(sender?.name! ?? 'No Name', style: const TextStyle(fontSize: 18, color: Colors.white),),
                                    const SizedBox(width: 10),
                                    Text(DateFormat('MMMM d, yyyy h:mm').format(message.dateSent!), style: const TextStyle(color: Colors.grey))
                                  ],
                                ) : Container(),
                                messageCard,
                                showName ? Padding(
                                  padding: const EdgeInsets.fromLTRB(5, 10, 0, 5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(lastSenderName!, style: const TextStyle(fontSize: 18, color: Colors.white),),
                                      const SizedBox(width: 10),
                                      Text(DateFormat('MMMM d, yyyy h:mm a').format(lastMessageTime!), style: const TextStyle(color: Colors.grey))
                                    ],
                                  ),
                                ) : Container(),
                              ],
                            );
                            lastSenderId = message.senderId;
                            lastMessageTime = message.dateSent;
                            lastSenderName = sender?.name;
                            return show;
                          }
                        );
                      }).toList() ?? [Container()],
                    )
                ),
                const SizedBox(height: 5),
                EnterDirectMessageWidget(conversation: conversation, currentUser: currentUser, targetUser: targetUser,),
                Platform.isIOS ? const SizedBox(height: 15) : Container()
              ],
            );
          }
      ),
    );
  }
}

final _menuKey = GlobalKey<PopupMenuButtonState>();

class EnterDirectMessageWidget extends ConsumerWidget {
  Conversation? conversation;
  final AppUser? currentUser;
  final AppUser? targetUser;
  final TextEditingController _messageController = TextEditingController();

  EnterDirectMessageWidget({
    Key? key,
    this.conversation,
    this.targetUser,
    this.currentUser
  });

  @override
  build(BuildContext context, ScopedReader watch) {
    XFile? file = watch(fileProvider);
    final notifier = watch(fileProvider.notifier);
    return Container(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(
        children: [
          file != null ? Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
            child: Container(
                height: 250,
                child: Stack(
                    children: [
                      Center(child: Image.file(File(file.path), fit: BoxFit.fitHeight,)),
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white,),
                          onPressed: () {
                            notifier.updateFile(null);
                          },
                        ),
                      )
                    ]
                )
            ),
          ) : const SizedBox(height: 0, width: 0),
          Row(
            children: [
              Listener(
                onPointerDown: (_) async {
                  if (FocusScope.of(context).hasFocus) {
                    FocusScope.of(context).unfocus();
                    await Future.delayed(const Duration(milliseconds: 400));
                  }
                  _menuKey.currentState?.showButtonMenu();
                },
                child: PopupMenuButton(
                  key: _menuKey,
                  enabled: false,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  offset: const Offset(0, -115),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  onSelected: (value) async {
                    if(value == 'gallery') {
                      XFile? selectedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                      notifier.updateFile(selectedFile);
                    } else {
                      XFile? selectedFile = await ImagePicker().pickImage(source: ImageSource.camera);
                      notifier.updateFile(selectedFile);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: 'gallery',
                        child: Row(
                            children: const <Widget>[
                              Icon(Icons.image),
                              SizedBox(width: 5),
                              Text('Gallery')
                            ]
                        )
                    ),
                    PopupMenuItem(
                        value: 'camera',
                        child: Row(
                            children: const <Widget>[
                              Icon(Icons.camera_alt_rounded),
                              SizedBox(width: 5),
                              Text('Camera')
                            ]
                        )
                    ),
                  ],
                ),
              ),
              /*
              IconButton(
                icon: const Icon(Icons.image, color: Colors.white),
                onPressed: () async {
                  XFile? selectedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                  notifier.updateFile(selectedFile);
                },
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                onPressed: () async {
                  XFile? selectedFile = await ImagePicker().pickImage(source: ImageSource.camera);
                  notifier.updateFile(selectedFile);
                },
              ),
              */
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 5, 0),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: Colors.white
                      ),
                      child: TextField(
                        maxLines: 6,
                        minLines: 1,
                        decoration: const InputDecoration(hintText: 'Enter your message', border: InputBorder.none, focusedBorder: InputBorder.none),
                        controller: _messageController,
                      )
                  )
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: () async {
                  bool createdConversation = false;
                  if(_messageController.value.text == '' && file == null) {
                    return;
                  }
                  //if doesn't have conversation, create conversation
                  if(conversation == null) {
                    print('creating new conversation');
                    conversation = await DatabaseServices().createConversation([currentUser, targetUser]);
                    createdConversation = true;
                    FirebaseAnalytics().logEvent(name: 'create_conversation', parameters: {
                      'conversation_id': conversation?.id,
                      'event_date': DateTime.now().millisecondsSinceEpoch
                    });
                  }
                  //send direct message
                  print('sending direct message');
                  await DatabaseServices().sendDirectMessage(conversation: conversation, senderId: currentUser?.id, senderName: currentUser?.name, message: _messageController.value.text, file: file);
                  //log direct message sent even
                  FirebaseAnalytics().logEvent(name: 'send_direct_message', parameters: {
                    'conversation_id': conversation?.id,
                    'sender_id': currentUser?.id,
                    'has_image': file == null ? false : true,
                    'event_date': DateTime.now().millisecondsSinceEpoch
                  });
                  notifier.updateFile(null);
                },
              )
            ],
          )
        ],
      ),
    );
  }
}