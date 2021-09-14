import 'package:intl/intl.dart';
import 'dart:io';
import 'direct_message_page.dart';
import 'menu_drawer.dart';
import 'signin_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'models/group_model.dart';
import 'services/auth_services.dart';
import 'services/database_services.dart';
import 'models/user_model.dart';
import 'providers/auth_providers.dart';
import 'providers/image_select_provider.dart';
import 'main.dart';
import 'join_group_page.dart';
import 'inbox_page.dart';

class GroupPage extends ConsumerWidget {
  Group? group;

  GroupPage({Key? key, @required this.group});

  @override
  build(BuildContext context, ScopedReader watch) {
    AppUser? currentUser = watch(appUserProvider).data?.value;
    FirebaseAnalytics().setCurrentScreen(screenName: 'group_page');
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF262626),
        leading: DrawerButton(currentUser),
        title: Text(group?.topic ?? 'Company', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_rounded),
            color: Colors.white,
            onPressed: () async {
              FirebaseAnalytics().logEvent(name: 'view_group_members', parameters: {
                'group_id': group?.id,
                'group_topic': group?.topic,
                'user_id': currentUser?.id,
                'event_at': DateTime.now().millisecondsSinceEpoch
              });
              await showDialog(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    title: const Center(child: Text('Members')),
                    children: [
                      Center(child: SelectableText('Group Code: ${group?.code}', style: const TextStyle(fontSize: 16, color: Colors.black54))),
                      Center(
                        child: TextButton(
                          child: const Text('Leave Group', style: TextStyle(color: Colors.black)),
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return SimpleDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  contentPadding: const EdgeInsets.all(10),
                                  title: const Center(child: Text('Are You Sure?')),
                                  children: [
                                    const Text('Are you sure you want to leave this group?', textAlign: TextAlign.center,),
                                    const SizedBox(height: 30),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                                          child: const Text('Leave Group', style: TextStyle(color: Colors.white)),
                                          onPressed: () async {
                                            await DatabaseServices().leaveGroup(group: group, user: currentUser);
                                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyHomePage()));
                                          },
                                        )
                                      ],
                                    )
                                  ]
                                );
                              }
                            );
                          },
                        ),
                      ),
                      Center(
                        child: TextButton(
                          child: const Text('Invite Friends', style: TextStyle(color: Colors.black)),
                          onPressed: () async {
                            Share.share('Hey! You should join me in this group about ${group?.topic} on The Company App! Go to joincompany.io to install the app, and use the following code to join my group: ${group?.code}', subject: 'Join My ${group?.topic} group on The Company App');
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: group!.members!.map((memberId) {
                              return FutureBuilder<AppUser>(
                                future: DatabaseServices().getAppUser(memberId),
                                builder: (context, AsyncSnapshot<AppUser> userSnap) {
                                  if(!userSnap.hasData) {
                                    return Container();
                                  }
                                  return ListTile(
                                    title: Text(userSnap.data!.name!),
                                    onTap: () async {
                                      //go to message page with this user
                                      if(userSnap.data!.id != currentUser?.id) {
                                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DirectMessagePage(userSnap.data!,)));
                                      }
                                    },
                                  );
                                },
                              );
                            }).toList()
                        ),
                      )
                    ]
                  );
                }
              );
            },
          )
        ],
      ),
      drawer: MenuDrawer(null),
      body: StreamBuilder<List<Message>>(
        stream: DatabaseServices().getMessagesForGroup(groupId: group?.id),
        builder: (context, AsyncSnapshot<List<Message>> snap) {
          if(snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if(!snap.hasData || (snap.data?.isEmpty ?? false)) {
            return Column(
              children: [
                const Expanded(child: Center(child: Text('Send the first message to your group!', style: TextStyle(color: Colors.white)))),
                EnterMessageWidget(group: group, appUser: currentUser,),
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
                    Message message = entry.value;
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
                                  print('URL: ${link.url} (${link.text})');
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
                            Text(message.senderName!, style: const TextStyle(fontSize: 18, color: Colors.white),),
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
                    lastSenderName = message.senderName;
                    return show;
                  }).toList() ?? [Container()],
                )
              ),
              const SizedBox(height: 5),
              EnterMessageWidget(group: group, appUser: currentUser,),
              Platform.isIOS ? const SizedBox(height: 15) : Container()
            ],
          );
        }
      ),
    );
  }
}

final _menuKey = GlobalKey<PopupMenuButtonState>();

class EnterMessageWidget extends ConsumerWidget {
  final Group? group;
  final AppUser? appUser;
  final TextEditingController _messageController = TextEditingController();

  EnterMessageWidget({
    Key? key,
    this.group,
    this.appUser
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
              SizedBox(
                height: 40,
                width: 40,
                child: Listener(
                  onPointerDown: (_) async {
                    if(FocusScope.of(context).hasFocus) {
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
                )
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
                  if(_messageController.value.text == '' && file == null) {
                    return;
                  }
                  //send message to database
                  FirebaseAnalytics().logEvent(name: 'send_message', parameters: {
                    'group_id': group?.id,
                    'group_topic': group?.topic,
                    'sender_id': appUser?.id,
                    'has_image': file == null ? false : true,
                    'event_date': DateTime.now().millisecondsSinceEpoch
                  });
                  await DatabaseServices().sendMessageToGroup(groupId: group?.id, senderId: appUser?.id, senderName: appUser?.name, message: _messageController.value.text, file: file);
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