import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'direct_message_page.dart';
import 'providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'signup_page.dart';
import 'signin_page.dart';
import 'group_page.dart';
import 'join_group_page.dart';
import 'inbox_page.dart';
import 'providers/auth_providers.dart';
import 'services/database_services.dart';
import 'providers/user_groups_provider.dart';
import 'services/auth_services.dart';
import 'models/group_model.dart';
import 'models/user_model.dart';
import 'menu_drawer.dart';

void main() {
  runApp(const ProviderScope(
    child: MainApp()
  ));
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  static FirebaseAnalytics analytics = FirebaseAnalytics();
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
    ));
    return MaterialApp(
      navigatorObservers: [observer],
      title: 'The Company App',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: FutureBuilder(
          future: Firebase.initializeApp(),
          builder: (context, snapshot) {
            if(snapshot.connectionState == ConnectionState.done) {
              analytics.logAppOpen();
              return Consumer(
                builder: (context, ScopedReader watch, child) {
                  final _authState = watch(authStateProvider);
                  return _authState.when(
                    data: (value) {
                      if(value != null) {
                        analytics.logLogin();
                        analytics.setUserId(value.uid);
                        return HomePageWrapper();
                      }
                      return SignUpPage();
                    },
                    loading: () {
                      return const SizedBox(
                        child: CircularProgressIndicator(),
                        height: 50,
                        width: 50,
                      );
                    },
                    error: (_, __) {
                      return const SizedBox(
                        child: CircularProgressIndicator(),
                        height: 50,
                        width: 50,
                      );
                    }
                  );
                },
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
      )
    );
  }
}

class HomePageWrapper extends StatefulWidget {
  @override
  _HomePageWrapperState createState() => _HomePageWrapperState();
}

class _HomePageWrapperState extends State<HomePageWrapper> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> registerNotifications(Future<AppUser?> userFuture) async {
    AppUser? currentUser = await userFuture;
    //setup firebase cloud messaging, request permissions for iOS
    NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: true
    );

    //check if authorized or not to set user settings in firestore
    if(settings.authorizationStatus == AuthorizationStatus.authorized) {
      await DatabaseServices().updateNotificationSettings(currentUser, allNotifications: true);
    }

    //get token to save in firestore
    String? token = await  _messaging.getToken();
    await DatabaseServices().updateUserTokens(token, currentUser);
    //print('token saved: $token');
    _messaging.onTokenRefresh.listen((token) => DatabaseServices().updateUserTokens(token, currentUser));

    //handle receiving notifications and messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      //print('Received a message: ${message.notification?.title} / ${message.data} (toast)');
      Fluttertoast.showToast(
        msg: message.notification?.title ?? 'You have a new message',
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
        textColor: Colors.white,
      );
    });

    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      //print('opened message from notification, ${message.notification?.title} / ${message.data}');
      String? groupId = message.data['group_id'];
      String? dmId = message.data['dm_user_id'];
      //print('group id: $groupId, dmId: $dmId');
      if(groupId != null) {
        //get group data to pass to page
        //print('getting group');
        Group group = await DatabaseServices().getGroup(groupId);
        //print('group: $group');
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => GroupPage(group: group)));
        return;
      }
      if(dmId != null) {
        //get user data and object to send to
        AppUser user = await DatabaseServices().getAppUser(dmId);
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => DirectMessagePage(user)));
        return;
      }
    });

    _messaging.getInitialMessage().then((message) async {
      if(message != null) {
        //print('get initial message, ${message.notification?.title} / ${message.data}');
        String? groupId = message.data['group_id'];
        String? dmId = message.data['dm_user_id'];
        //print('group id: $groupId, dmId: $dmId');
        if(groupId != null) {
          //get group data to pass to page
          //print('getting group');
          Group group = await DatabaseServices().getGroup(groupId);
          //print('group: $group');
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => GroupPage(group: group)));
          return;
        }
        if(dmId != null) {
          //get user data and object to send to
          AppUser user = await DatabaseServices().getAppUser(dmId);
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => DirectMessagePage(user)));
          return;
        }
      }
    });
  }

  @override
  initState() {
    super.initState();
    Future<AppUser?> currentUser = context.read(appUserProvider.last).then((user) => user);
    registerNotifications(currentUser);
  }

  @override
  build(BuildContext context) {
    return MyHomePage();
  }
}

class MyHomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, ScopedReader watch) {
    List<Group>? myGroups = watch(userGroupsProvider).data?.value;
    myGroups?.sort((a, b) => b.lastMessageDate?.compareTo(a.lastMessageDate ?? DateTime(2000, 1, 1)) ?? 0);
    AppUser? currentUser = watch(appUserProvider).data?.value;
    FirebaseAnalytics().setCurrentScreen(screenName: 'home_page');
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF262626),
        leading: DrawerButton(currentUser),
        title: const Text('My Company', style: TextStyle(color: Colors.white),),
      ),
      drawer: MenuDrawer('home-page'),
      body: Center(
        child: ListView(
          children: myGroups == null ? [Center(
            child: Container(
              padding: const EdgeInsets.only(top: 15),
              width: 50,
              child: const CircularProgressIndicator(),
            )
          )] :
              myGroups.isEmpty ? [TextButton(
                child: const Text('Join A Group!'),
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => JoinGroupPage()));
                },
              )] : myGroups.map((Group group) {
                int? userUnread = group.memberMap?[currentUser?.id]?['unread'];
                return InkWell(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 5.0,
                    child: Container(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(group.topic ?? 'Error loading group!', style: const TextStyle(fontSize: 18)),
                            userUnread != null && userUnread > 0 ? Container(
                              height: 20,
                              width: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                              child: Center(
                                child: Text('$userUnread', style: const TextStyle(color: Colors.white)),
                              )
                            ) : Container(),
                          ]
                        )
                    ),
                  ),
                  onTap: () {
                    FirebaseAnalytics().logEvent(name: 'view_group_page', parameters: {
                      'group_id': group.id,
                      'group_topic': group.topic,
                      'user_id': currentUser?.id,
                      'event_date': DateTime.now().millisecondsSinceEpoch,
                    });
                    DatabaseServices().markGroupMessagesRead(group, currentUser);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GroupPage(group: group)));
                  }
                );
              }).toList()
        ),
      ),
    );
  }
}

Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  //print('received background notifcation: ${message.notification} / ${message.data}');
}