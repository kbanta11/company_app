import 'package:company_app/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'signup_page.dart';
import 'signin_page.dart';
import 'group_page.dart';
import 'join_group_page.dart';
import 'providers/auth_providers.dart';
import 'providers/user_groups_provider.dart';
import 'services/auth_services.dart';
import 'models/group_model.dart';
import 'models/user_model.dart';

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
    return MaterialApp(
      navigatorObservers: [observer],
      title: 'The Company App',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
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
                        return MyHomePage();
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


class MyHomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, ScopedReader watch) {
    List<Group>? myGroups = watch(userGroupsProvider).data?.value;
    AppUser? currentUser = watch(appUserProvider).data?.value;
    FirebaseAnalytics().setCurrentScreen(screenName: 'home_page');
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Company'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Home'),
              onTap: () {

              }
            ),
            ListTile(
              title: const Text('Join Another Group'),
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => JoinGroupPage()));
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
                return InkWell(
                  child: Card(
                    elevation: 5.0,
                    child: Container(
                        padding: const EdgeInsets.all(15),
                        child: Text(group.topic ?? 'Error loading group!', style: const TextStyle(fontSize: 18))
                    ),
                  ),
                  onTap: () {
                    FirebaseAnalytics().logEvent(name: 'view_group_page', parameters: {
                      'group_id': group.id,
                      'group_topic': group.topic,
                      'user_id': currentUser?.id,
                      'event_date': DateTime.now().millisecondsSinceEpoch,
                    });
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GroupPage(group: group)));
                  }
                );
              }).toList()
        ),
      ),
    );
  }
}
